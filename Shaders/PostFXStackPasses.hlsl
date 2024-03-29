﻿#ifndef CUSTOM_POST_FX_PASSES_INCLUDED
#define CUSTOM_POST_FX_PASSES_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "CustomACES.hlsl"

float4 _ProjectionParams;
float4 _PostFXSource_TexelSize;
float4 _Params; // x: scatter, y: clamp, z: threshold (linear), w: threshold knee

#define Scatter             _Params.x
#define ClampMax            _Params.y
#define Threshold           _Params.z
#define ThresholdKnee       _Params.w
float _BloomIntensity;

TEXTURE2D(_PostFXSource);
TEXTURE2D(_PostFXSource2);
SAMPLER(sampler_linear_clamp);

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);
float4 _MainTex_TexelSize;

struct Attributes
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : VAR_WORLD_POSITION;
    float3 normalWS : VAR_NORMAL;
    float2 uv : VAR_BASE_UV;
};

struct Varying
{
    float3 position : POSITION;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
};

float4 GetSource(float2 screenUV)
{
    return SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, screenUV, 0);
}

float4 GetSourceBicubic(float2 screenUV)
{
    return SampleTexture2DBicubic(
        TEXTURE2D_ARGS(_MainTex, sampler_MainTex), screenUV,
        _PostFXSource_TexelSize.zwxy, 1.0, 0.0
    );
}

float4 GetSource2(float2 screenUV)
{
    return SAMPLE_TEXTURE2D_LOD(_PostFXSource2, sampler_linear_clamp, screenUV, 0);
}

float4 GetSourceTexelSize()
{
    return _PostFXSource_TexelSize;
}

//Generate triangle which cover whole screen
Attributes DefaultPassVertex(Varying input)
{
    Attributes output;
    output.positionWS = TransformObjectToWorld(input.position);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.normalWS = TransformObjectToWorldNormal(input.normal);
    output.uv = input.uv;
    return output;
}

float4 CopyPassFragment(Attributes input) : SV_TARGET
{
    float4 screen = GetSource(input.uv);
    return screen;
}

float _BlurRandom;

half4 BloomHorizontalPassFragment(Attributes input) : SV_TARGET
{
    float texelSize = _MainTex_TexelSize.x;
    float2 uv = input.uv;

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

    float v = 1 / 9.0;

    color = c0 * v + c1 * v + c2 * v + c3 * v + c4 * v + c5 * v + c6 * v + c7 * v + c8 * v;

    return half4(color, 1.0);
}

half4 BloomVerticalPassFragment(Attributes input) : SV_TARGET
{
    float texelSize = _MainTex_TexelSize.y;
    float2 uv = input.uv;

    // Optimized bilinear 5-tap gaussian on the same-sized source (9-tap equivalent)
    half3 c0 = GetSource(uv - float2(0.0, texelSize * 3.23076923));
    half3 c1 = GetSource(uv - float2(0.0, texelSize * 1.38461538));
    half3 c2 = GetSource(uv);
    half3 c3 = GetSource(uv + float2(0.0, texelSize * 1.38461538));
    half3 c4 = GetSource(uv + float2(0.0, texelSize * 3.23076923));

    half3 color = c0 * 0.07027027 + c1 * 0.31621622
        + c2 * 0.22702703
        + c3 * 0.31621622 + c4 * 0.07027027;

    color = c0 * 0.2 + c1 * 0.2 + c2 * 0.2 + c3 * 0.2 + c4 * 0.2;

    return half4(color, 1);
}

half4 BloomCombinePassFragment(Attributes input) : SV_TARGET
{
    float3 lowRes = GetSource2(input.uv).rgb;
    float3 highRes = GetSource(input.uv).rgb;
    return half4(lerp(highRes, lowRes, 0.7), 1);
}

half4 BloomPrefilterPassFragment(Attributes input) : SV_TARGET
{
    half3 color = GetSource(input.uv).rgb;

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

half4 ToneMappingACESPassFragment(Attributes input) : SV_TARGET
{
    half4 color = GetSource(input.uv);
    color += GetSource2(input.uv) * _BloomIntensity;

    color.rgb = clamp(color.rgb, 0, 60);
    color.rgb = ACESFitted(color.rgb);
    color.a = 1;

    return color;
}

#endif
