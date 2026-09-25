import AVFoundation
import Metal
import CoreVideo

/// AVFoundation decodes and schedules frames; Metal samples the latest frame at display rate.
final class PanoramaVideo {
    let player: AVPlayer
    private let item: AVPlayerItem
    private let output: AVPlayerItemVideoOutput
    private var cache: CVMetalTextureCache!
    private var loopObserver: NSObjectProtocol?
    private(set) var frame: CVMetalTexture?
    private(set) var decodedFrames = 0
    let name: String

    init(url: URL, device: MTLDevice) throws {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else { throw SDKError(message: "视频没有可读取的画面轨道") }
        let size = track.naturalSize.applying(track.preferredTransform)
        guard abs(abs(size.width / size.height) - 2) < 0.05 else { throw SDKError(message: "请选择 2:1 等距柱状全景视频") }
        name = url.deletingPathExtension().lastPathComponent
        output = AVPlayerItemVideoOutput(outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            AVVideoAllowWideColorKey: false
        ])
        item = AVPlayerItem(asset: asset)
        item.add(output)
        player = AVPlayer(playerItem: item)
        guard CVMetalTextureCacheCreate(nil, nil, device, nil, &cache) == kCVReturnSuccess else { throw SDKError(message: "无法创建视频纹理缓存") }
        loopObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                if finished { self?.player.play() }
            }
        }
    }
    deinit {
        player.pause()
        if let loopObserver { NotificationCenter.default.removeObserver(loopObserver) }
    }
    var duration: Double { let s = item.duration.seconds; return s.isFinite ? max(0,s) : 0 }
    var position: Double { let s = player.currentTime().seconds; return s.isFinite ? max(0,s) : 0 }
    var isPlaying: Bool { player.rate != 0 }
    var errorMessage: String? { item.error?.localizedDescription }
    func seek(to seconds: Double) {
        guard duration > 0 else { return }
        player.seek(to: CMTime(seconds: min(duration, max(0,seconds)), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
    func toggle() { if player.rate == 0 { player.play() } else { player.pause() } }
    func update() -> MTLTexture? {
        let time = output.itemTime(forHostTime: ProcessInfo.processInfo.systemUptime)
        if output.hasNewPixelBuffer(forItemTime: time), let pixels = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) {
            var next: CVMetalTexture?
            let result = CVMetalTextureCacheCreateTextureFromImage(nil, cache, pixels, nil, .bgra8Unorm, CVPixelBufferGetWidth(pixels), CVPixelBufferGetHeight(pixels), 0, &next)
            if result == kCVReturnSuccess, let next { frame = next; decodedFrames += 1 }
        }
        return frame.flatMap { CVMetalTextureGetTexture($0) }
    }
    var status: String {
        if let error = item.error { return "视频错误：\(error.localizedDescription)" }
        let seconds = player.currentTime().seconds
        let duration = item.duration.seconds
        return String(format: "%@ · %@ %.1f / %.1f 秒 · 帧 %d", name, player.rate == 0 ? "暂停" : "播放", seconds.isFinite ? seconds : 0, duration.isFinite ? duration : 0, decodedFrames)
    }
}
