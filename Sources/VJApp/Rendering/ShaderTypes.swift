import simd

typealias float2 = SIMD2<Float>
typealias float3 = SIMD3<Float>
typealias float4 = SIMD4<Float>

struct Vertex {
    var position: float2
    var texCoord: float2
}

struct Uniforms {
    var opacity: Float
    var blendMode: UInt32
    var padding: float2
}

struct EffectUniforms {
    var tintColor: float3
    var tintAmount: Float
    var brightness: Float
    var contrast: Float
    var saturation: Float
    var hueShift: Float
}
