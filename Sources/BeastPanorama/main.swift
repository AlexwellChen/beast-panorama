import AppKit
import UniformTypeIdentifiers
import Metal
import Darwin

final class App: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var view: PanoramaView!
    let sdk = GlassesSDK()
    let header = PlayerPanel(), controls = PlayerPanel(), welcome = PlayerPanel()
    let titleLabel = label("Beast Panorama", size: 17, weight: .semibold)
    let subtitle = label("360° 全景播放器", size: 12, secondary: true)
    let connection = label("鼠标环视", size: 12, weight: .medium)
    let elapsed = label("0:00", size: 12), remaining = label("−0:00", size: 12)
    let hint = label("空格 播放 / 暂停    R 居中    ← → 跳转 5 秒    F 全屏", size: 11, secondary: true)
    let timeline = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    let volume = NSSlider(value: 0.7, minValue: 0, maxValue: 1, target: nil, action: nil)
    let fieldOfView = NSSlider(value: 60, minValue: 30, maxValue: 90, target: nil, action: nil)
    let fovLabel = label("视场 60°", size: 12)
    var playButton: NSButton!, connectButton: NSButton!, muteButton: NSButton!
    var tickTimer: Timer?, inputMonitor: Any?
    var lastInteraction = ProcessInfo.processInfo.systemUptime
    var chromeVisible = true, mediaLoaded = false, connecting = false
    var connectDeadline = 0.0
    var noticeUntil = 0.0
    var refreshPicker: NSPopUpButton?
    var dutyPicker: NSPopUpButton?
    var settingsPanel: NSPanel?
    var brightnessSlider: NSSlider?, tintSlider: NSSlider?
    var brightnessText: NSTextField?, tintText: NSTextField?, hardwareStatus: NSTextField?
    var pendingFile: URL?
    var currentURL: URL?
    var savedVolume: Float = 0.7

    func button(_ text: String, symbol: String, action: Selector, help: String) -> NSButton {
        let b = NSButton(title: text, target: self, action: action)
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: text)
        b.imagePosition = text.isEmpty ? .imageOnly : .imageLeading
        b.bezelStyle = .texturedRounded; b.controlSize = .large
        b.font = .systemFont(ofSize: 13, weight: .medium)
        b.contentTintColor = .labelColor
        b.toolTip = help; b.setAccessibilityLabel(text.isEmpty ? help : text)
        b.heightAnchor.constraint(equalToConstant: 40).isActive = true
        b.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return b
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        do { view = try PanoramaView(validating: true) } catch { showError(error); NSApp.terminate(nil); return }
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        buildMenu()
        window = NSWindow(contentRect: NSRect(x:0,y:0,width:1180,height:760), styleMask:[.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView], backing:.buffered, defer:false)
        window.title = "Beast Panorama"; window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true; window.backgroundColor = .black
        window.delegate = self; window.minSize = NSSize(width:940,height:560)
        window.acceptsMouseMovedEvents = true
        let root = PlayerCanvas(renderer:view,header:header,controls:controls,welcome:welcome); window.contentView = root
        buildHeader(root); buildControls(root); buildWelcome(root)
        fieldOfView.doubleValue = UserDefaults.standard.object(forKey:"fov") as? Double ?? 60
        view.fov = Float(fieldOfView.doubleValue)
        volume.doubleValue = UserDefaults.standard.object(forKey:"volume") as? Double ?? 0.7
        view.onFileDrop = { [weak self] url in self?.open(url) }
        view.onInteraction = { [weak self] in self?.interact() }
        view.onStatus = { s in if CommandLine.arguments.contains("--diagnostics") { print(s); fflush(stdout) } }
        inputMonitor = NSEvent.addLocalMonitorForEvents(matching:[.keyDown,.mouseMoved,.leftMouseDown,.scrollWheel]) { [weak self] event in
            guard let self, event.window == self.window else { return event }
            self.interact()
            guard event.type == .keyDown, !event.modifierFlags.contains(.command), !event.modifierFlags.contains(.control), !(self.window.firstResponder is NSTextView) else { return event }
            switch event.keyCode {
            case 49: self.togglePlayback()
            case 15: self.recenter()
            case 3: self.fullscreen()
            case 46: self.toggleMute()
            case 123: self.seekBy(-5)
            case 124: self.seekBy(5)
            case 53:
                if self.window.styleMask.contains(.fullScreen) { self.fullscreen() }
                else { self.showChrome(true) }
            default: return event
            }
            return nil
        }
        tickTimer = Timer.scheduledTimer(withTimeInterval:0.2, repeats:true) { [weak self] _ in self?.refresh() }
        window.center(); window.makeKeyAndOrderFront(nil); window.makeFirstResponder(view)
        NSApp.activate(ignoringOtherApps:true)
        if let path = argument("--video") { open(URL(fileURLWithPath:path)); if CommandLine.arguments.contains("--paused") { view.video?.player.pause() } }
        if let path = argument("--sdk") {
            UserDefaults.standard.set(path,forKey:"sdkPath"); connectSDK(URL(fileURLWithPath:path))
        } else if let url = sdkURL() {
            connectSDK(url, quiet: true)
        }
        if let url=pendingFile { pendingFile=nil; open(url) }
    }
    func sdkURL() -> URL? {
        if let url=Bundle.main.privateFrameworksURL?.appendingPathComponent("VITURE/libglasses.dylib"),FileManager.default.fileExists(atPath:url.path) { return url }
        if let path=UserDefaults.standard.string(forKey:"sdkPath"),FileManager.default.fileExists(atPath:path) { return URL(fileURLWithPath:path) }
        return nil
    }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        if let path=filenames.first { let url=URL(fileURLWithPath:path); if view == nil { pendingFile=url } else { open(url) } }
        sender.reply(toOpenOrPrint:.success)
    }
    func argument(_ name:String) -> String? {
        guard let i=CommandLine.arguments.firstIndex(of:name), i+1<CommandLine.arguments.count else { return nil }; return CommandLine.arguments[i+1]
    }
    func buildHeader(_ root: NSView) {
        let titles = NSStackView(views:[titleLabel,subtitle]); titles.orientation = .vertical; titles.alignment = .leading; titles.spacing = 3
        connectButton = button("连接眼镜",symbol:"eyeglasses",action:#selector(connect),help:"连接眼镜并启用头追")
        let content = row([titles, spacer(), connection, connectButton, button("打开",symbol:"folder",action:#selector(openFile),help:"打开全景图片或视频 · ⌘O"),button("",symbol:"slider.horizontal.3",action:#selector(displaySettings),help:"眼镜显示设置")])
        pin(content,to:header,inset:14)

    }
    func buildControls(_ root: NSView) {
        timeline.target=self; timeline.action=#selector(scrub); timeline.isContinuous=true
        timeline.setAccessibilityLabel("播放进度")
        timeline.toolTip="拖动跳转；左右方向键前后 5 秒"
        elapsed.font = .monospacedDigitSystemFont(ofSize:12,weight:.regular)
        remaining.font = elapsed.font
        let progress = row([elapsed,timeline,remaining])
        playButton=button("",symbol:"play.fill",action:#selector(togglePlayback),help:"播放 / 暂停 · 空格")
        muteButton=button("",symbol:"speaker.wave.2",action:#selector(toggleMute),help:"静音 / 取消静音 · M")
        volume.target=self; volume.action=#selector(changeVolume); volume.setAccessibilityLabel("音量")
        volume.widthAnchor.constraint(equalToConstant:90).isActive=true
        fieldOfView.target=self; fieldOfView.action=#selector(changeFOV); fieldOfView.setAccessibilityLabel("垂直视场角")
        fieldOfView.widthAnchor.constraint(equalToConstant:110).isActive=true
        fieldOfView.toolTip="较小视场更近，较大视场更宽；按舒适程度调整"
        let actions=row([playButton,button("",symbol:"gobackward.5",action:#selector(back),help:"后退 5 秒 · ←"),button("",symbol:"goforward.5",action:#selector(forward),help:"前进 5 秒 · →"),muteButton,volume,spacer(),fovLabel,fieldOfView,button("居中",symbol:"scope",action:#selector(recenter),help:"面朝前方后按 R 居中"),button("",symbol:"arrow.up.left.and.arrow.down.right",action:#selector(fullscreen),help:"全屏 / 退出全屏 · F")],spacing:8)
        let content=NSStackView(views:[progress,actions,hint]); content.orientation = .vertical; content.alignment = .leading; content.spacing=10
        progress.widthAnchor.constraint(equalTo:content.widthAnchor).isActive=true
        actions.widthAnchor.constraint(equalTo:content.widthAnchor).isActive=true
        pin(content,to:controls,inset:18)

    }
    func buildWelcome(_ root:NSView) {
        let content=NSStackView(views:[label("把视线交给世界",size:28,weight:.semibold),label("拖入 360° 视频或全景图片，转头探索每个方向。",size:14,secondary:true),button("打开全景文件",symbol:"folder",action:#selector(openFile),help:"打开 2:1 全景图片或视频")]); content.orientation = .vertical; content.spacing=18
        pin(content,to:welcome,inset:32)

    }
    func buildMenu() {
        let menu=NSMenu(); NSApp.mainMenu=menu
        func group(_ name:String, _ entries:[(String,Selector,String)]) {
            let parent=NSMenuItem(); parent.title=name; let sub=NSMenu(title:name)
            for (title,action,key) in entries { let i=NSMenuItem(title:title,action:action,keyEquivalent:key); i.target=self; sub.addItem(i) }
            parent.submenu=sub; menu.addItem(parent)
        }
        group("Beast Panorama",[("关于 Beast Panorama",#selector(about),""),("退出 Beast Panorama",#selector(quit),"q")])
        group("文件",[("打开全景…",#selector(openFile),"o"),("重新打开上次文件",#selector(openLast),""),("显示校准图",#selector(calibration),"")])
        group("观看",[("播放 / 暂停",#selector(togglePlayback),""),("居中视线",#selector(recenter),""),("移到眼镜屏幕",#selector(moveDisplay),""),("全屏",#selector(fullscreen),"")])
        group("眼镜",[("显示设置…",#selector(displaySettings),","),("连接 / 断开",#selector(connect),""),("选择 SDK…",#selector(selectSDK),"")])
    }
    func interact() { lastInteraction=ProcessInfo.processInfo.systemUptime; showChrome(true) }
    func showChrome(_ visible:Bool) {
        guard chromeVisible != visible else { return }; chromeVisible=visible
        // Immediate visibility avoids motion in the user's peripheral view.
        header.isHidden = !visible; controls.isHidden = !visible
    }
    func refresh() {
        let now=ProcessInfo.processInfo.systemUptime
        let (_,time,count)=PoseStore.shared.read()
        if connecting {
            if count>0 && now-time<0.5 {
                connecting=false
                do { try sdk.enableBypass(); view.tracking=true; view.recenter(); connectButton.title="断开眼镜"; moveDisplay(); notice("头追已就绪 · 面朝前方，按 R 居中") }
                catch { view.tracking=false; sdk.disconnect(); showError(error) }
            } else if now>connectDeadline { connecting=false; sdk.disconnect(); showError(SDKError(message:"未收到眼镜姿态。请检查 USB-C 连接，并关闭其他占用眼镜的应用后重新连接。")) }
        }
        connection.stringValue = connecting ? "正在连接…" : view.tracking ? (count>0 && now-time<0.5 ? "● 头追已开启" : "头追中断 · 检查连接") : "鼠标拖动环视"
        connection.textColor = view.tracking && now-time<0.5 ? NSColor.systemMint : NSColor.secondaryLabelColor
        let trackingLost = view.tracking && (count == 0 || now-time >= 0.5)
        if trackingLost { showChrome(true) }
        connectButton.setAccessibilityLabel(sdk.connected ? "断开眼镜" : "连接眼镜")
        connectButton.toolTip = sdk.connected ? "断开并恢复眼镜原来的显示设置" : "连接眼镜并启用头追"
        connectButton.isEnabled = !connecting
        if !sdk.connected && !connecting { connectButton.title="连接眼镜" }
        let video=view.video
        playButton.isEnabled=video != nil; timeline.isEnabled=(video?.duration ?? 0)>0
        playButton.image=NSImage(systemSymbolName: video?.isPlaying == true ? "pause.fill" : "play.fill",accessibilityDescription:video?.isPlaying == true ? "暂停" : "播放")
        playButton.setAccessibilityLabel(video?.isPlaying == true ? "暂停" : "播放")
        if let video {
            elapsed.stringValue=timeText(video.position); remaining.stringValue="−"+timeText(video.duration-video.position)
            timeline.maxValue=max(1,video.duration); timeline.doubleValue=video.position
            if let error=video.errorMessage { hint.stringValue="播放失败："+error; showChrome(true); return }
        } else { elapsed.stringValue="0:00"; remaining.stringValue="−0:00"; timeline.doubleValue=0 }
        fovLabel.stringValue="视场 \(Int(view.fov))°"; fieldOfView.doubleValue=Double(view.fov)
        if now>noticeUntil { hint.stringValue="空格 播放 / 暂停    R 居中    ← → 跳转 5 秒    F 全屏    M 静音" }
        let pointer=window.mouseLocationOutsideOfEventStream
        let hovering=NSPointInRect(pointer,controls.frame) || NSPointInRect(pointer,header.frame)
        if video?.isPlaying == true && now-lastInteraction>3.5 && now>noticeUntil && !hovering && !trackingLost && window.attachedSheet == nil { showChrome(false) }
        if video?.isPlaying != true { showChrome(true) }
    }
    func notice(_ message:String) { hint.stringValue=message; noticeUntil=ProcessInfo.processInfo.systemUptime+4; interact() }
    func showError(_ error:Error) {
        interact(); let a=NSAlert(); a.messageText="暂时无法完成"; a.informativeText=error.localizedDescription; a.addButton(withTitle:"知道了")
        if let window { a.beginSheetModal(for:window) } else { a.runModal() }
    }
    @objc func openFile() {
        interact(); let p=NSOpenPanel(); p.allowedContentTypes=[.image,.movie]; p.canChooseDirectories=false
        p.message="选择 2:1 等距柱状全景视频或图片"; p.beginSheetModal(for:window) { [weak self] result in if result == .OK,let url=p.url { self?.open(url) } }
    }
    func open(_ url:URL) {
        do {
            if let type=UTType(filenameExtension:url.pathExtension),type.conforms(to:.movie) { try view.loadVideo(url); view.video?.player.volume=Float(volume.doubleValue) }
            else { try view.load(url) }
            currentURL=url; mediaLoaded=true; welcome.isHidden=true
            titleLabel.stringValue=url.deletingPathExtension().lastPathComponent
            subtitle.stringValue=view.video == nil ? "360° 全景图片" : "360° 全景视频 · 循环播放"
            window.title=url.lastPathComponent+" — Beast Panorama"
            UserDefaults.standard.set(url.path,forKey:"lastMedia")
            notice("已打开 · 移开指针后，控制栏会自动收起")
            window.makeFirstResponder(view)
        } catch { showError(error) }
    }
    @objc func openLast() {
        guard let path=UserDefaults.standard.string(forKey:"lastMedia") else { openFile(); return }; open(URL(fileURLWithPath:path))
    }
    @objc func togglePlayback() { view.togglePlayback(); interact(); window.makeFirstResponder(view) }
    @objc func scrub() { view.video?.seek(to:timeline.doubleValue); interact() }
    func seekBy(_ seconds:Double) { if let v=view.video { v.seek(to:v.position+seconds) }; interact() }
    @objc func back() { seekBy(-5) }
    @objc func forward() { seekBy(5) }
    @objc func changeVolume() {
        view.video?.player.volume=Float(volume.doubleValue)
        UserDefaults.standard.set(volume.doubleValue,forKey:"volume")
        muteButton.image=NSImage(systemSymbolName:volume.doubleValue==0 ? "speaker.slash" : "speaker.wave.2",accessibilityDescription:"音量")
        interact()
    }
    @objc func toggleMute() {
        if volume.doubleValue>0 { savedVolume=Float(volume.doubleValue); volume.doubleValue=0 } else { volume.doubleValue=Double(max(0.1,savedVolume)) }; changeVolume()
    }
    @objc func changeFOV() { view.fov=Float(fieldOfView.doubleValue); UserDefaults.standard.set(fieldOfView.doubleValue,forKey:"fov"); interact() }
    @objc func recenter() { view.recenter(); notice("视线已居中"); window.makeFirstResponder(view) }
    @objc func fullscreen() { window.toggleFullScreen(nil); interact() }
    @objc func calibration() {
        do { try view.calibration(); welcome.isHidden=true; titleLabel.stringValue="方向校准"; subtitle.stringValue="左转看 LEFT，抬头看 UP · R 居中"; interact() } catch { showError(error) }
    }
    @objc func connect() {
        if sdk.connected { view.tracking=false; connecting=false; let result=sdk.disconnect(); notice(result.isEmpty ? "眼镜已断开" : result); return }
        if let url=sdkURL() { connectSDK(url) } else { selectSDK() }
    }
    @objc func selectSDK() {
        let panel=NSOpenPanel(); panel.message="首次设置：选择 macOS arm64 SDK 的 libglasses.dylib。之后会记住此位置。"
        panel.beginSheetModal(for:window) { [weak self] result in
            if result == .OK,let url=panel.url { UserDefaults.standard.set(url.path,forKey:"sdkPath"); self?.connectSDK(url) }
        }
    }
    func connectSDK(_ url:URL, quiet:Bool = false) {
        do { view.tracking=false; try sdk.connect(url:url); connecting=true; connectDeadline=ProcessInfo.processInfo.systemUptime+5; interact() }
        catch { connecting=false; if quiet { notice("连接 Beast 后，点击「连接眼镜」开启头追") } else { showError(error) } }
    }
    @objc func moveDisplay() {
        guard let screen=NSScreen.screens.first(where: { $0.localizedName.lowercased().contains("viture") || $0.localizedName.lowercased().contains("beast") }) else { notice("未找到眼镜显示器 · 可继续在电脑观看"); return }
        if !window.styleMask.contains(.fullScreen) { window.setFrame(screen.visibleFrame.insetBy(dx:12,dy:12),display:true) }
    }
    @objc func displaySettings() {
        interact()
        let settings=sdk.displaySettings()
        print("DISPLAY SETTINGS brightness=\(String(describing:settings.brightness)) duty=\(String(describing:settings.duty)) tint=\(String(describing:settings.tint)) mode=\(String(describing:settings.mode))")
        let panel=NSPanel(contentRect:NSRect(x:0,y:0,width:550,height:510),styleMask:[.titled],backing:.buffered,defer:false)
        panel.title="眼镜显示设置"; settingsPanel=panel
        let b=NSSlider(value:Double(settings.brightness ?? 0),minValue:0,maxValue:8,target:self,action:#selector(adjustBrightness))
        b.numberOfTickMarks=9; b.allowsTickMarkValuesOnly=true; b.isContinuous=false
        b.isEnabled=settings.brightness != nil; b.setAccessibilityLabel("眼镜亮度")
        brightnessSlider=b; brightnessText=label(settings.brightness.map { "亮度  \($0) / 8" } ?? "亮度暂不可读取",size:14)
        let t=NSSlider(value:Double(settings.tint ?? 0)*8,minValue:0,maxValue:8,target:self,action:#selector(adjustTint))
        t.numberOfTickMarks=9; t.allowsTickMarkValuesOnly=true; t.isContinuous=false
        t.isEnabled=settings.tint != nil; t.setAccessibilityLabel("镜片遮光")
        tintSlider=t; tintText=label(settings.tint.map { "镜片遮光  \(Int(($0*8).rounded())) / 8" } ?? "镜片遮光暂不可读取",size:14)
        let duty=NSPopUpButton(frame:.zero,pullsDown:false)
        for value in [30,42,50,98] { duty.addItem(withTitle:value == 98 ? "98% · 高亮" : "\(value)%"); duty.lastItem?.tag=value }
        if let value=settings.duty {
            if duty.menu?.item(withTag:Int(value)) == nil { duty.addItem(withTitle:"\(value)% · 当前"); duty.lastItem?.tag=Int(value) }
            duty.selectItem(withTag:Int(value))
        }
        duty.isEnabled=settings.duty != nil; duty.target=self; duty.action=#selector(adjustDuty)
        duty.setAccessibilityLabel("屏幕发光占空比"); dutyPicker=duty
        let refresh=NSPopUpButton(frame:.zero,pullsDown:false)
        refresh.addItem(withTitle:"60Hz · 已验证"); refresh.lastItem?.tag=60
        refresh.addItem(withTitle:"尝试 120Hz · 自动校验"); refresh.lastItem?.tag=120
        refresh.selectItem(withTag:sdk.refreshRate); refresh.isEnabled=sdk.connected
        refresh.target=self; refresh.action=#selector(adjustRefresh); refresh.setAccessibilityLabel("显示刷新率"); refreshPicker=refresh
        hardwareStatus=label("调整会应用到眼镜，并保留硬件设置。",size:12,secondary:true)
        let note=NSTextField(wrappingLabelWithString:"120Hz 需眼镜与 macOS 同时支持，切换失败会退回 60Hz。\n画面占满：按 F 全屏。景物放大：调小主界面的视场角。\n原生屏幕尺寸与距离调节不适用于当前头追模式。")
        note.font = .systemFont(ofSize:13); note.textColor = .secondaryLabelColor
        let content=NSStackView(views:[label("眼镜与画面",size:21,weight:.semibold),brightnessText!,b,tintText!,t,row([label("屏幕发光占空比",size:14),duty]),row([label("显示刷新率",size:14),refresh]),note,hardwareStatus!,button("完成",symbol:"checkmark",action:#selector(closeSettings),help:"关闭显示设置")])
        content.orientation = .vertical; content.alignment = .leading; content.spacing=14
        b.widthAnchor.constraint(equalToConstant:490).isActive=true
        t.widthAnchor.constraint(equalTo:b.widthAnchor).isActive=true
        note.widthAnchor.constraint(equalTo:b.widthAnchor).isActive=true
        pin(content,to:panel.contentView!,inset:26)
        window.beginSheet(panel)
    }
    @objc func adjustBrightness() {
        guard let slider=brightnessSlider else { return }
        do { let level=Int32(slider.intValue); try sdk.setBrightness(level); brightnessText?.stringValue="亮度  \(level) / 8"; hardwareStatus?.stringValue="亮度已应用" }
        catch { hardwareStatus?.stringValue=error.localizedDescription }
    }
    @objc func adjustRefresh() {
        guard let hz=refreshPicker?.selectedItem?.tag else { return }
        do {
            try sdk.setRefreshRate(hz)
            // Verify the host's actual timing as well as the device's register.
            guard let screen=NSScreen.screens.first(where:{$0.localizedName.lowercased().contains("viture") || $0.localizedName.lowercased().contains("beast")}),
                  let id=screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let mode=CGDisplayCopyDisplayMode(id.uint32Value), abs(mode.refreshRate-Double(hz))<1 else {
                throw SDKError(message:"macOS 未输出所选刷新率")
            }
            view.preferredFramesPerSecond=hz; view.recenter()
            hardwareStatus?.stringValue="已确认显示与姿态采样均为 \(hz)Hz"
        } catch {
            let failure=error.localizedDescription
            do { try sdk.setRefreshRate(60); view.preferredFramesPerSecond=60; hardwareStatus?.stringValue="\(failure) 已恢复 60Hz。" }
            catch { hardwareStatus?.stringValue="\(failure)；恢复失败，请断开眼镜后重新连接。" }
        }
        refreshPicker?.selectItem(withTag:sdk.refreshRate)
    }
    @objc func adjustDuty() {
        guard let value=dutyPicker?.selectedItem?.tag else { return }
        do { try sdk.setDuty(Int32(value)); hardwareStatus?.stringValue="发光占空比已应用并读回确认" }
        catch { hardwareStatus?.stringValue=error.localizedDescription }
    }
    @objc func adjustTint() {
        guard let slider=tintSlider else { return }
        do { let level=Int(slider.intValue); try sdk.setTint(level); tintText?.stringValue="镜片遮光  \(level) / 8"; hardwareStatus?.stringValue="镜片遮光已应用" }
        catch { hardwareStatus?.stringValue=error.localizedDescription }
    }
    @objc func closeSettings() { if let panel=settingsPanel { window.endSheet(panel); settingsPanel=nil }; interact() }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"Beast Panorama",.applicationVersion:"0.2.0",.credits:NSAttributedString(string:"本地 360° 全景播放器\n支持 Beast 3DoF 头追 · 当前为 SDR 输出")]) }
    @objc func quit() { NSApp.terminate(nil) }
    func windowDidResize(_ notification: Notification) {
        window.contentView?.needsLayout=true
        if CommandLine.arguments.contains("--diagnostics") { print("CANVAS window=\(window.frame) view=\(view.frame) drawable=\(view.drawableSize)"); fflush(stdout) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { true }
    func applicationWillTerminate(_ notification:Notification) {
        tickTimer?.invalidate(); if let inputMonitor { NSEvent.removeMonitor(inputMonitor) }
        UserDefaults.standard.set(Double(view.fov),forKey:"fov")
        let result=sdk.disconnect(); if result.contains("失败") { let a=NSAlert(); a.messageText=result; a.runModal() }
    }
}
if CommandLine.arguments.contains("--self-check") {
    if let url=Bundle.main.privateFrameworksURL?.appendingPathComponent("VITURE/libglasses.dylib"), FileManager.default.fileExists(atPath:url.path) {
        guard let library=dlopen(url.path,RTLD_NOW | RTLD_LOCAL),
              dlsym(library,"xr_device_provider_create") != nil,
              dlsym(library,"xr_device_provider_register_imu_pose_callback") != nil else {
            fputs("FAIL: bundled SDK cannot load or lacks required symbols\n",stderr); exit(1)
        }
        print("PASS: bundled SDK and required symbols; no hardware opened")
    } else {
        if CommandLine.arguments.contains("--require-sdk") { fputs("FAIL: no bundled SDK\n",stderr); exit(1) }
        print("PASS: SDK-free build; an external SDK can be selected in the app")
    }
    let metalAvailable=MTLCreateSystemDefaultDevice() != nil
    if CommandLine.arguments.contains("--require-metal") && !metalAvailable { fputs("FAIL: Metal unavailable\n",stderr); exit(1) }
    print("Metal available: \(metalAvailable). GUI and hardware behavior not tested by this check.")
    exit(0)
}
let application=NSApplication.shared
let app=App()
application.delegate=app
application.run()
