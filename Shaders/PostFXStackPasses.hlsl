#ifndef CUSTOM_POST_FX_PASSES_INCLUDED
#define CUSTOM_POST_FX_PASSES_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

float4 _ProjectionParams;
float4 _ZBufferParams;
float4x4 _InverseVPMatrix;
float4 _PostFXSource_TexelSize;
float4 _Params; // x: scatter, y: clamp, z: threshold (linear), w: threshold knee

#define Scatter             _Params.x
#define ClampMax            _Params.y
#define Threshold           _Params.z
#define ThresholdKnee       _Params.w
float _BloomIntensity;

TEXTURE2D(_PostFXSource);
TEXTURE2D(_PostFXSource2);
TEXTURE2D(_CameraDepthBuffer);
SAMPLER(sampler_linear_clamp);
SAMPLER(sampler_point_clamp);

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 screenUV : VAR_SCREEN_UV;
};

float4 GetSource(float2 screenUV)
{
    return SAMPLE_TEXTURE2D_LOD(_PostFXSource, sampler_linear_clamp, screenUV, 0);
}

float4 GetSourceBicubic(float2 screenUV)
{
    return SampleTexture2DBicubic(
        TEXTURE2D_ARGS(_PostFXSource, sampler_linear_clamp), screenUV,
        _PostFXSource_TexelSize.zwxy, 1.0, 0.0
    );
}

float GetLinearDepth01(float2 screenUV)
{
    //TODO:GetDepth
    float depth = SAMPLE_TEXTURE2D(_CameraDepthBuffer, sampler_point_clamp, screenUV).r;
    depth = Linear01Depth(depth, _ZBufferParams);
    return depth;
};

float4 GetSource2(float2 screenUV)
{
    return SAMPLE_TEXTURE2D_LOD(_PostFXSource2, sampler_linear_clamp, screenUV, 0);
}

float4 GetSourceTexelSize()
{
    return _PostFXSource_TexelSize;
}

//Generate triangle which cover whole screen
Varyings DefaultPassVertex(uint vertexID : SV_VertexID)
{
    Varyings output;
    output.positionCS = float4(
        vertexID <= 1 ? -1.0 : 3.0,
        vertexID == 1 ? 3.0 : -1.0,
        0.0, 1.0
    );
    output.screenUV = float2(
        vertexID <= 1 ? 0.0 : 2.0,
        vertexID == 1 ? 2.0 : 0.0
    );

    //Fix flip of scene view
    if (_ProjectionParams.x < 0.0)
    {
        output.screenUV.y = 1.0 - output.screenUV.y;
    }
    return output;
}

float4 CopyPassFragment(Varyings input) : SV_TARGET
{
    float4 screen = GetSource(input.screenUV);
    return screen;
}

half4 BloomHorizontalPassFragment(Varyings input) : SV_TARGET
{
    float texelSize = _PostFXSource_TexelSize.x * 2.0;
    float2 uv = input.screenUV;

    // 9-tap gaussian blur on the downsampled source
    half3 c0 = GetSource(uv - float2(texelSize * 4.0, 0.0));
    half3 c1 = GetSource(uv - float2(texelSize * 3.0, 0.0));
    half3 c2 = GetSource(uv - float2(texelSize * 2.0, 0.0));
    half3 c3 = GetSource(uv - float2(texelSize * 1.0, 0.0));
    half3 c4 = GetSource(uv);
    half3 c5 = GetSource(uv + float2(texelSize * 1.0, 0.0));
    half3 c6 = GetSource(uv + float2(texelSize * 2.0, 0.0));
    half3 c7 = GetSource(uv + float2(texelSize * 3.0, 0.0));
    half3 c8 = GetSource(uv + float2(texelSize * 4.0, 0.0));

    half3 color = c0 * 0.01621622 + c1 * 0.05405405 + c2 * 0.12162162 + c3 * 0.19459459
        + c4 * 0.22702703
        + c5 * 0.19459459 + c6 * 0.12162162 + c7 * 0.05405405 + c8 * 0.01621622;

    return half4(color, 1.0);
}

half4 BloomVerticalPassFragment(Varyings input) : SV_TARGET
{
    float texelSize = _PostFXSource_TexelSize.y;
    float2 uv = input.screenUV;

    // Optimized bilinear 5-tap gaussian on the same-sized source (9-tap equivalent)
    half3 c0 = GetSource(uv - float2(0.0, texelSize * 3.23076923));
    half3 c1 = GetSource(uv - float2(0.0, texelSize * 1.38461538));
    half3 c2 = GetSource(uv);
    half3 c3 = GetSource(uv + float2(0.0, texelSize * 1.38461538));
    half3 c4 = GetSource(uv + float2(0.0, texelSize * 3.23076923));

    half3 color = c0 * 0.07027027 + c1 * 0.31621622
        + c2 * 0.22702703
        + c3 * 0.31621622 + c4 * 0.07027027;

    return half4(color, 1);
}

half4 BloomCombinePassFragment(Varyings input) : SV_TARGET
{
    float3 lowRes = GetSource2(input.screenUV).rgb;
    float3 highRes = GetSource(input.screenUV).rgb;
    return half4(lerp(highRes, lowRes, 0.7), 1);
}

half4 BloomPrefilterPassFragment(Varyings input) : SV_TARGET
{
    half3 color = GetSource(input.screenUV).rgb;

    // User controlled clamp to limit crazy high broken spec
    color = min(ClampMax, color);

    // Thresholding
    half brightness = Max3(color.r, color.g, color.b);
    half softness = clamp(brightness - Threshold + ThresholdKnee, 0.0, 2.0 * ThresholdKnee);
    softness = (softness * softness) / (4.0 * ThresholdKnee + 1e-4);
    half multiplier = max(brightness - Threshold, softness) / max(brightness, 1e-4);
    color *= multiplier;

    // Clamp colors to positive once in prefilter. Encode can have a sqrt, and sqrt(-x) == NaN. Up/Downsample passes would then spread the NaN.
    color = max(color, 0);
    return half4(color, 1.0);
}

half4 ToneMappingACESPassFragment(Varyings input) : SV_TARGET
{
    half4 color = GetSource(input.screenUV);
    color += GetSource2(input.screenUV) * _BloomIntensity;

    color.a = 1;

    color.rgb = min(color.rgb, 60.0);
    color.rgb = AcesTonemap(unity_to_ACES(color.rgb));
    return color;
}

float _FogDensity;
float _FogStrength;
half4 _FogColor;

float4 FogPassFragment(Varyings input) : SV_TARGET
{
    float depth = GetLinearDepth01(input.screenUV);
    float4 worldPos = mul(_InverseVPMatrix, float4(input.screenUV * 2.0 - 1.0, depth, 1.0));
    worldPos /= worldPos.w;
    float z = worldPos.z - _WorldSpaceCameraPos.z;
    float factor = exp(-(1 -_FogDensity) * z);
    float4 color = GetSource(input.screenUV);
    float4 result = lerp(color, _FogColor, factor * _FogStrength);
    result.a = color.a;
    return result;
}

#endif
