import Foundation
import IOKit
import Darwin

typealias Handle = UnsafeMutableRawPointer
typealias PoseCallback = @convention(c) (UnsafeMutablePointer<Float>?, UInt64) -> Void
private let callback: PoseCallback = { data, _ in PoseStore.shared.put(data) }
struct SDKError: LocalizedError { let message: String; var errorDescription: String? { message } }

final class GlassesSDK {
    private var library: Handle?
    private var handle: Handle?
    private var started = false
    private var initialized = false
    private var imu = false
    private var productID: Int32 = 0
    private(set) var refreshRate = 60
    private var originalMode: Int32?
    private var originalDisplay: Int32?
    private var originalDOF: Int32?
    private var changedMode = false
    var connected: Bool { handle != nil && imu }
    private func fn<T>(_ name: String, _: T.Type) throws -> T {
        guard let lib = library, let p = dlsym(lib, name) else { throw SDKError(message: "SDK 缺少接口：\(name)") }
        return unsafeBitCast(p, to: T.self)
    }
    private typealias Unary = @convention(c) (Handle?) -> Int32
    private typealias Setter = @convention(c) (Handle?, Int32) -> Int32
    private func get(_ name: String) throws -> Int32 { try fn(name, Unary.self)(handle) }
    private func set(_ name: String, _ value: Int32) throws { try check(fn(name, Setter.self)(handle, value), name) }
    private func check(_ result: Int32, _ step: String) throws {
        if result < 0 { throw SDKError(message: "\(step)：SDK 错误 \(result)") }
    }
    func connect(url: URL) throws {
        _ = disconnect()
        PoseStore.shared.reset()
        guard let lib = dlopen(url.path, RTLD_NOW | RTLD_LOCAL) else {
            throw SDKError(message: String(cString: dlerror()))
        }
        library = lib
        do {
            // Resolve cleanup functions before opening hardware.
            _ = try fn("xr_device_provider_destroy", (@convention(c) (Handle?) -> Void).self)
            for n in ["stop", "shutdown"] { _ = try fn("xr_device_provider_" + n, Unary.self) }
            let nameFn = try fn("xr_device_provider_get_market_name", (@convention(c) (Int32, UnsafeMutablePointer<CChar>?, UnsafeMutablePointer<Int32>?) -> Int32).self)
            var iterator: io_iterator_t = 0
            guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &iterator) == KERN_SUCCESS else { throw SDKError(message: "无法枚举 USB") }
            defer { IOObjectRelease(iterator) }
            var pid: Int32?
            while case let item = IOIteratorNext(iterator), item != 0 {
                defer { IOObjectRelease(item) }
                let vendor = IORegistryEntryCreateCFProperty(item, "idVendor" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber
                let product = IORegistryEntryCreateCFProperty(item, "idProduct" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber
                guard vendor?.intValue == 0x35ca, let product else { continue }
                var buffer = [CChar](repeating: 0, count: 128); var length: Int32 = 128
                if nameFn(product.int32Value, &buffer, &length) == 0, String(cString: buffer).lowercased().contains("beast") { pid = product.int32Value; break }
            }
            guard let pid else { throw SDKError(message: "未发现 Beast。请直连 USB-C，并退出 SpaceWalker / Immersive 3D。") }
            productID = pid
            let create = try fn("xr_device_provider_create", (@convention(c) (Int32) -> Handle?).self)
            guard let h = create(pid) else { throw SDKError(message: "SDK 无法打开 Beast") }
            handle = h
            let initialize = try fn("xr_device_provider_initialize", (@convention(c) (Handle?, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Int32).self)
            try check(initialize(h, nil, nil), "initialize"); initialized = true
            try check(get("xr_device_provider_start"), "start"); started = true
            let register = try fn("xr_device_provider_register_imu_pose_callback", (@convention(c) (Handle?, PoseCallback?) -> Int32).self)
            try check(register(h, callback), "register pose")
            let open = try fn("xr_device_provider_open_imu", (@convention(c) (Handle?, UInt8, UInt8) -> Int32).self)
            // 60 Hz first; a successful command still requires actual callbacks.
            try check(open(h, 1, 0), "open IMU"); imu = true
        } catch { _ = disconnect(); throw error }
    }
    func enableBypass() throws {
        guard connected else { throw SDKError(message: "请先连接 SDK") }
        guard !changedMode else { return }
        let mode = try get("xr_device_provider_native_get_mode")
        try check(mode, "read native mode")
        let display = try get(mode == 1 ? "xr_device_provider_native_get_display_mode" : "xr_device_provider_get_display_mode")
        try check(display, "read display mode")
        originalMode = mode; originalDisplay = display; changedMode = true
        do {
            // Beast's pose stream may inherit Smooth Follow even in bypass.
            // Save the native tracking preference and use anchored 3DoF for panorama.
            if mode == 0 { try set("xr_device_provider_native_set_mode", 1) }
            let dof = try get("xr_device_provider_native_get_dof")
            try check(dof, "read native DOF")
            originalDOF = dof
            try set("xr_device_provider_native_set_dof", 1)
            let activeDOF = try get("xr_device_provider_native_get_dof")
            print("[MODE-PROBE] originalDOF=\(dof) activeDOF=\(activeDOF)")
            guard activeDOF == 1 else { throw SDKError(message: "固定 3DoF 模式读回不一致") }
            try set("xr_device_provider_native_set_mode", 0)
            try set("xr_device_provider_set_display_mode", 0x31) // 1080p60
            let actualMode = try get("xr_device_provider_native_get_mode")
            let actualDisplay = try get("xr_device_provider_get_display_mode")
            print("[MODE-PROBE] native=\(actualMode) display=\(actualDisplay)")
            guard actualMode == 0, actualDisplay == 0x31 else { throw SDKError(message: "Bypass 模式读回不一致") }
        } catch { let restore = restoreMode(); throw SDKError(message: "\(error.localizedDescription)\n\(restore)") }
    }
    func setRefreshRate(_ hz: Int) throws {
        guard connected, hz == 60 || hz == 120 else { throw SDKError(message:"请选择 60Hz 或 120Hz") }
        try enableBypass() // Capture the original device state once.
        do {
            if hz == 120 {
                try set("xr_device_provider_native_set_mode", 1)
                // Disable on-device screen movement: the panorama camera owns tracking.
                try set("xr_device_provider_native_set_dof", 0)
                try set("xr_device_provider_native_set_display_mode", 0x33)
                Thread.sleep(forTimeInterval:1)
                let m=try get("xr_device_provider_native_get_mode")
                let d=try get("xr_device_provider_native_get_dof")
                let display=try get("xr_device_provider_native_get_display_mode")
                print("[DISPLAY-PROBE] native=\(m) dof=\(d) display=\(display)"); fflush(stdout)
                guard m == 1, d == 0, display == 0x33 else { throw SDKError(message:"120Hz 模式读回不一致") }
            } else { try standardMode() }
            let frequency: UInt8 = hz == 120 ? 2 : 0
            let supported = try fn("xr_device_provider_is_product_support_imu_frequency", (@convention(c) (Int32,Int32,Int32)->Int32).self)
            guard supported(productID,1,Int32(frequency)) == 1 else { throw SDKError(message:"眼镜不支持对应的姿态采样率") }
            let open = try fn("xr_device_provider_open_imu", (@convention(c) (Handle?,UInt8,UInt8)->Int32).self)
            try check(open(handle,1,frequency),"切换姿态采样率")
            refreshRate=hz
            print("[DISPLAY] verified refresh=\(hz) IMU=\(hz)"); fflush(stdout)
        } catch {
            let failure=error.localizedDescription
            do { try standardMode(); refreshRate=60 } catch { throw SDKError(message:"\(failure)；回退失败：\(error.localizedDescription)") }
            throw SDKError(message:"\(failure)。已回退到 60Hz。")
        }
    }
    private func standardMode() throws {
        try set("xr_device_provider_native_set_mode",1)
        try set("xr_device_provider_native_set_dof",1)
        try set("xr_device_provider_native_set_mode",0)
        try set("xr_device_provider_set_display_mode",0x31)
        let open=try fn("xr_device_provider_open_imu",(@convention(c) (Handle?,UInt8,UInt8)->Int32).self)
        try check(open(handle,1,0),"恢复姿态采样率")
        guard try get("xr_device_provider_native_get_mode") == 0, try get("xr_device_provider_get_display_mode") == 0x31 else { throw SDKError(message:"60Hz 模式读回失败") }
    }
    struct DisplaySettings {
        let brightness: Int32?
        let duty: Int32?
        let tint: Float?
        let mode: Int32?
    }
    func displaySettings() -> DisplaySettings {
        func value(_ name: String, range: ClosedRange<Int32>) -> Int32? {
            guard connected, let v = try? get(name), range.contains(v) else { return nil }; return v
        }
        var tint: Float = .nan
        if connected, let f = try? fn("xr_device_provider_get_film_mode", (@convention(c) (Handle?, UnsafeMutablePointer<Float>?) -> Int32).self) {
            if f(handle, &tint) < 0 { tint = .nan }
        }
        return DisplaySettings(brightness: value("xr_device_provider_get_brightness_level", range: 0...8), duty: value("xr_device_provider_get_duty_cycle", range: 0...100), tint: tint.isFinite && (0...1).contains(tint) ? tint : nil, mode: value("xr_device_provider_get_display_mode", range: 0...255))
    }
    func setBrightness(_ level: Int32) throws {
        guard connected, (0...8).contains(level) else { throw SDKError(message:"请先连接眼镜") }
        try set("xr_device_provider_set_brightness_level", level)
        guard try get("xr_device_provider_get_brightness_level") == level else { throw SDKError(message:"亮度读回不一致，请重试") }
    }
    func setDuty(_ value: Int32) throws {
        guard connected, [30,42,50,98].contains(value) else { throw SDKError(message:"无效的发光档位") }
        try set("xr_device_provider_set_duty_cycle", value)
        guard try get("xr_device_provider_get_duty_cycle") == value else { throw SDKError(message:"发光档位读回不一致，请重试") }
    }
    func setTint(_ level: Int) throws {
        guard connected, (0...8).contains(level) else { throw SDKError(message:"请先连接眼镜") }
        let f = try fn("xr_device_provider_set_film_mode", (@convention(c) (Handle?, Float) -> Int32).self)
        try check(f(handle, Float(level)/8), "设置镜片遮光")
    }
    private func restoreMode() -> String {
        guard changedMode, let mode = originalMode, let display = originalDisplay else { return "" }
        do {
            if let dof = originalDOF {
                try set("xr_device_provider_native_set_mode", 1)
                try set("xr_device_provider_native_set_dof", dof)
            }
            try set("xr_device_provider_native_set_mode", mode)
            try set(mode == 1 ? "xr_device_provider_native_set_display_mode" : "xr_device_provider_set_display_mode", display)
            changedMode = false
            return "已恢复显示模式"
        } catch { return "恢复失败：\(error.localizedDescription)。请用眼镜菜单恢复或重新插拔。" }
    }
    @discardableResult func disconnect() -> String {
        let message = restoreMode()
        if let h = handle {
            if imu, let close = try? fn("xr_device_provider_close_imu", (@convention(c) (Handle?, UInt8) -> Int32).self) { _ = close(h, 1) }
            if started { _ = try? get("xr_device_provider_stop") }
            if initialized { _ = try? get("xr_device_provider_shutdown") }
            if let destroy = try? fn("xr_device_provider_destroy", (@convention(c) (Handle?) -> Void).self) { destroy(h) }
        }
        originalDOF = nil
        refreshRate = 60
        handle = nil; started = false; initialized = false; imu = false; changedMode = false
        // Keep the library loaded: vendor background teardown must not race dlclose.
        return message
    }
}
