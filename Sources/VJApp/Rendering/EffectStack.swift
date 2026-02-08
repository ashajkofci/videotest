import Metal

struct EffectPass {
    let functionName: String
    var enabled: Bool
}

final class EffectStack {
    private let device: MTLDevice
    private let library: MTLLibrary
    private let pipelineCache = PipelineCache()

    init(device: MTLDevice, library: MTLLibrary) {
        self.device = device
        self.library = library
    }

    func buildPipeline(for functionName: String) throws -> MTLRenderPipelineState {
        if let cached = pipelineCache[functionName] {
            return cached
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertex_passthrough")
        descriptor.fragmentFunction = library.makeFunction(name: functionName)
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        pipelineCache[functionName] = pipeline
        return pipeline
    }
}

final class PipelineCache {
    private var cache: [String: MTLRenderPipelineState] = [:]

    subscript(key: String) -> MTLRenderPipelineState? {
        get { cache[key] }
        set { cache[key] = newValue }
    }
}
