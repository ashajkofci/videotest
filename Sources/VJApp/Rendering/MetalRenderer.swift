import AVFoundation
import Metal
import MetalKit

final class MetalRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let textureCache: CVMetalTextureCache
    private let library: MTLLibrary
    private let effectStack: EffectStack

    var activeScene: Scene?
    var transitionScene: Scene?
    var transitionProgress: Float = 0.0
    var targetFPS: Int = 60

    private var lastFrameTime: CFTimeInterval = 0
    private(set) var droppedFrames: Int = 0
    private(set) var fps: Double = 0

    init?(mtkView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.commandQueue = queue
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        guard let createdCache = cache else { return nil }
        self.textureCache = createdCache
        self.library = device.makeDefaultLibrary() ?? device.makeDefaultLibrary(bundle: .main)!
        self.effectStack = EffectStack(device: device, library: library)
        super.init()
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.delegate = self
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else { return }

        let now = CACurrentMediaTime()
        if lastFrameTime > 0 {
            let delta = now - lastFrameTime
            fps = 1.0 / max(delta, 0.0001)
        }
        lastFrameTime = now

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    func texture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        var cvTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, .bgra8Unorm, width, height, 0, &cvTexture)
        guard let cvTexture else { return nil }
        return CVMetalTextureGetTexture(cvTexture)
    }
}
