import AppKit
import MetalKit
import simd

final class PanoramaView: MTKView, MTKViewDelegate {
    private(set) var video: PanoramaVideo?
    var onFileDrop: ((URL) -> Void)?
    var onInteraction: (() -> Void)?
    var yaw: Float = 0
    var pitch: Float = 0
    var fov: Float = 60
    var screenScale: Float = 1
    var tracking = false
    var origin: simd_quatf?
    var onStatus: ((String) -> Void)?
    private var pipeline: MTLRenderPipelineState!
    private var queue: MTLCommandQueue!
    private var panorama: MTLTexture!
    private var tick = 0
    private var lastPointer: NSPoint?
    override var acceptsFirstResponder: Bool { true }
    init(validating: Bool) throws {
        guard let gpu = MTLCreateSystemDefaultDevice() else { throw SDKError(message: "Metal 不可用") }
        super.init(frame: .zero, device: gpu)
        colorPixelFormat = .bgra8Unorm
        preferredFramesPerSecond = 60
        registerForDraggedTypes([.fileURL])
        queue = gpu.makeCommandQueue()
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        struct V { float4 p [[position]]; float2 uv; };
        struct U { float4x4 rotation; float4 lens; };
        vertex V vertexMain(uint id [[vertex_id]]) {
            float2 p[3] = {float2(-1,-1),float2(3,-1),float2(-1,3)};
            V o; o.p=float4(p[id],0,1); o.uv=p[id]; return o;
        }
        fragment float4 fragmentMain(V in [[stage_in]], constant U& u [[buffer(0)]], texture2d<float> tex [[texture(0)]]) {
            float2 screen = in.uv / clamp(u.lens.z, 0.4f, 2.0f);
            if (abs(screen.x) > 1 || abs(screen.y) > 1) return float4(0,0,0,1);
            float3 ray=normalize(float3(screen.x*u.lens.x*u.lens.y,screen.y*u.lens.y,-1));
            ray=(u.rotation*float4(ray,0)).xyz;
            float2 uv=float2(atan2(ray.x,-ray.z)/(2*M_PI_F)+0.5,0.5-asin(clamp(ray.y,-1.0,1.0))/M_PI_F);
            constexpr sampler s(s_address::repeat,t_address::clamp_to_edge,filter::linear);
            return float4(tex.sample(s,uv).rgb,1);
        }
        """
        let lib = try gpu.makeLibrary(source: source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = lib.makeFunction(name: "vertexMain")
        descriptor.fragmentFunction = lib.makeFunction(name: "fragmentMain")
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        pipeline = try gpu.makeRenderPipelineState(descriptor: descriptor)
        delegate = self
        try calibration()
    }
    required init(coder: NSCoder) { fatalError() }
    func calibration() throws {
        video = nil
        let image = NSImage(size: NSSize(width: 2048, height: 1024))
        image.lockFocus()
        NSColor(calibratedRed: 0.035, green: 0.09, blue: 0.13, alpha: 1).setFill()
        NSRect(x: 0,y: 0,width: 2048,height: 1024).fill()
        for x in stride(from: 0, through: 2048, by: 128) {
            NSColor(calibratedWhite: 0.3, alpha: 1).setStroke()
            let p=NSBezierPath(); p.move(to:NSPoint(x:x,y:0)); p.line(to:NSPoint(x:x,y:1024)); p.stroke()
        }
        for y in stride(from: 0, through: 1024, by: 128) {
            NSColor(calibratedWhite: 0.3, alpha: 1).setStroke()
            let p=NSBezierPath(); p.move(to:NSPoint(x:0,y:y)); p.line(to:NSPoint(x:2048,y:y)); p.stroke()
        }
        for (x,label) in [(0,"BACK"),(512,"LEFT"),(1024,"FRONT"),(1536,"RIGHT")] {
            (label as NSString).draw(at: NSPoint(x:x+12,y:520), withAttributes:[.font:NSFont.monospacedSystemFont(ofSize:42,weight:.medium),.foregroundColor:NSColor.cyan])
        }
        ("UP" as NSString).draw(at:NSPoint(x:1036,y:770),withAttributes:[.font:NSFont.systemFont(ofSize:36),.foregroundColor:NSColor.white])
        ("DOWN" as NSString).draw(at:NSPoint(x:1036,y:250),withAttributes:[.font:NSFont.systemFont(ofSize:36),.foregroundColor:NSColor.white])
        image.unlockFocus()
        guard let cg=image.cgImage(forProposedRect:nil, context:nil,hints:nil) else { throw SDKError(message:"校准图生成失败") }
        panorama = try texture(from: cg)
    }
    private func texture(from image: CGImage) throws -> MTLTexture {
        let w=image.width, h=image.height
        guard w <= 16384, h <= 16384 else { throw SDKError(message:"图片尺寸超出 16384 像素限制") }
        var bytes=[UInt8](repeating:0,count:w*h*4)
        let ok=bytes.withUnsafeMutableBytes { data -> Bool in
            guard let ctx=CGContext(data:data.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image,in:CGRect(x:0,y:0,width:w,height:h))
            return true
        }
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:w,height:h,mipmapped:false)
        descriptor.usage = .shaderRead
        guard ok, let texture=device!.makeTexture(descriptor:descriptor) else { throw SDKError(message:"无法创建全景纹理") }
        bytes.withUnsafeBytes { data in texture.replace(region:MTLRegionMake2D(0,0,w,h),mipmapLevel:0,withBytes:data.baseAddress!,bytesPerRow:w*4) }
        return texture
    }
    func load(_ url: URL) throws {
        guard let img=NSImage(contentsOf:url), let cg=img.cgImage(forProposedRect:nil,context:nil,hints:nil) else { throw SDKError(message:"无法读取图片") }
        guard abs(Double(cg.width)/Double(cg.height)-2) < 0.05 else { throw SDKError(message:"请选择 2:1 的完整等距柱状全景图") }
        let next = try texture(from: cg)
        video = nil
        panorama = next
    }
    func loadVideo(_ url: URL) throws {
        let next = try PanoramaVideo(url: url, device: device!)
        video = next
        next.player.play()
    }
    func togglePlayback() { video?.toggle() }
    func recenter() { origin = nil; yaw = 0; pitch = 0 }
    override func mouseDown(with event: NSEvent) { onInteraction?(); lastPointer = event.locationInWindow; window?.makeFirstResponder(self) }
    override func mouseDragged(with event: NSEvent) {
        onInteraction?()
        let current = event.locationInWindow
        let previous = lastPointer ?? current
        lastPointer = current
        yaw = (yaw + Float(current.x - previous.x)*0.005).remainder(dividingBy: 2 * .pi)
        pitch = min(1.5,max(-1.5,pitch - Float(current.y - previous.y)*0.005))
    }
    override func mouseUp(with event: NSEvent) { lastPointer = nil; onInteraction?() }
    override func scrollWheel(with event: NSEvent) { onInteraction?(); fov = min(90,max(20,fov+Float(event.scrollingDeltaY)*0.2)) }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], let url = urls.first else { return false }
        onFileDrop?(url); return true
    }
    override func keyDown(with event: NSEvent) { if event.charactersIgnoringModifiers == "r" { recenter() } else if event.characters == " " { togglePlayback() } else { super.keyDown(with:event) } }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in view: MTKView) {
        guard let drawable=currentDrawable, let pass=currentRenderPassDescriptor, let buffer=queue.makeCommandBuffer(), let encoder=buffer.makeRenderCommandEncoder(descriptor:pass) else { return }
        if let texture = video?.update() { panorama = texture }
        // Keep the CoreVideo backing alive until the GPU has finished this frame.
        let videoFrame = video?.frame
        buffer.addCompletedHandler { _ in withExtendedLifetime(videoFrame) {} }
        let (pose,time,count)=PoseStore.shared.read()
        let age=ProcessInfo.processInfo.systemUptime-time
        var head: simd_quatf?
        if tracking && count > 0 {
            if origin == nil { origin = pose }
            head = origin!.inverse * pose
        }
        let rotation = viewingRotation(yaw: yaw, pitch: pitch, head: head)
        struct Uniforms { var rotation: simd_float4x4; var lens: SIMD4<Float> }
        var uniforms=Uniforms(rotation:simd_float4x4(rotation),lens:SIMD4(Float(drawableSize.width/max(1,drawableSize.height)),tan(fov * .pi/360),screenScale,0))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms,length:MemoryLayout<Uniforms>.stride,index:0)
        encoder.setFragmentTexture(panorama,index:0)
        encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
        encoder.endEncoding(); buffer.present(drawable); buffer.commit()
        tick += 1
        if tick % 15 == 0 {
            let v=rotation.vector
            let state = tracking ? (count == 0 ? "等待姿态数据" : age > 0.5 ? "姿态数据中断 — 画面冻结" : "头追中") : "鼠标拖动环视"
            onStatus?(String(format:"%@  ·  FOV %.0f°  ·  q %.2f %.2f %.2f %.2f  ·  样本 %d",state,fov,v.x,v.y,v.z,v.w,count) + (video.map { " · " + $0.status } ?? ""))
        }
    }
}
