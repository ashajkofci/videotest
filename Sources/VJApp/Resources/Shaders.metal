#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float opacity;
    uint blendMode;
    float2 padding;
};

struct EffectUniforms {
    float3 tintColor;
    float tintAmount;
    float brightness;
    float contrast;
    float saturation;
    float hueShift;
};

vertex VertexOut vertex_passthrough(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 fragment_base(VertexOut in [[stage_in]],
                              texture2d<float> inputTexture [[texture(0)]],
                              sampler sam [[sampler(0)]]) {
    return inputTexture.sample(sam, in.texCoord);
}

fragment float4 fragment_tint(VertexOut in [[stage_in]],
                              texture2d<float> inputTexture [[texture(0)]],
                              sampler sam [[sampler(0)]],
                              constant EffectUniforms &fx [[buffer(0)]]) {
    float4 color = inputTexture.sample(sam, in.texCoord);
    float3 tinted = mix(color.rgb, fx.tintColor, fx.tintAmount);
    return float4(tinted, color.a);
}

fragment float4 fragment_bcs(VertexOut in [[stage_in]],
                             texture2d<float> inputTexture [[texture(0)]],
                             sampler sam [[sampler(0)]],
                             constant EffectUniforms &fx [[buffer(0)]]) {
    float4 color = inputTexture.sample(sam, in.texCoord);
    float3 result = color.rgb;
    result = (result - 0.5) * fx.contrast + 0.5;
    result += fx.brightness;
    float luma = dot(result, float3(0.2126, 0.7152, 0.0722));
    result = mix(float3(luma), result, fx.saturation);
    return float4(result, color.a);
}
