import AVFoundation
import Metal
import MetalKit

final class MetalRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let textureCache: CVMetalTextureCache
    private let library: MTLLibrary
    private let effectStack: EffectStack
    private let basePipeline: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private let vertexDescriptor: MTLVertexDescriptor

    var activeScene: VJScene?
    var transitionScene: VJScene?
    var transitionProgress: Float = 0.0
    var targetFPS: Int = 60

    /// Externally provided textures keyed by media ID, set by SceneEngine each frame.
    var layerTextures: [String: MTLTexture] = [:]

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
        guard let lib = device.makeDefaultLibrary() ?? (try? device.makeDefaultLibrary(bundle: .main)) else { return nil }
        self.library = lib
        self.effectStack = EffectStack(device: device, library: lib)

        // Build base render pipeline using vertex_passthrough + fragment_base
        let vDesc = MTLVertexDescriptor()
        vDesc.attributes[0].format = .float2
        vDesc.attributes[0].offset = 0
        vDesc.attributes[0].bufferIndex = 0
        vDesc.attributes[1].format = .float2
        vDesc.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        vDesc.attributes[1].bufferIndex = 0
        vDesc.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride * 2
        self.vertexDescriptor = vDesc

        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = lib.makeFunction(name: "vertex_passthrough")
        pipelineDesc.fragmentFunction = lib.makeFunction(name: "fragment_base")
        pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDesc.colorAttachments[0].isBlendingEnabled = true
        pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipelineDesc.vertexDescriptor = vDesc

        guard let pipeline = try? device.makeRenderPipelineState(descriptor: pipelineDesc) else { return nil }
        self.basePipeline = pipeline

        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        samplerDesc.sAddressMode = .clampToEdge
        samplerDesc.tAddressMode = .clampToEdge
        guard let sampler = device.makeSamplerState(descriptor: samplerDesc) else { return nil }
        self.samplerState = sampler

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

        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        descriptor.colorAttachments[0].loadAction = .clear

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        // Render layers from the active scene
        if let scene = activeScene {
            renderLayers(scene.layers, encoder: encoder, opacity: 1.0 - transitionProgress)
        }

        // Render layers from the transition scene (crossfade)
        if let tScene = transitionScene, transitionProgress > 0 {
            renderLayers(tScene.layers, encoder: encoder, opacity: transitionProgress)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func renderLayers(_ layers: [LayerInstance], encoder: MTLRenderCommandEncoder, opacity: Float) {
        guard opacity > 0 else { return }
        let sortedLayers = layers.sorted { $0.order < $1.order }
        for layer in sortedLayers {
            guard layer.opacity * opacity > 0, let texture = layerTextures[layer.mediaId] else { continue }

            let vertices = MeshBuilder.buildVertices(mapping: layer.mesh, transform: layer.transform)
            guard !vertices.isEmpty else { continue }

            // Convert Vertex array to raw bytes for the GPU
            let vertexData = vertices.flatMap { v -> [Float] in
                [v.position.x * 2.0 - 1.0, 1.0 - v.position.y * 2.0, v.texCoord.x, v.texCoord.y]
            }

            encoder.setRenderPipelineState(basePipeline)
            encoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.size, index: 0)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.setFragmentSamplerState(samplerState, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        }
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
