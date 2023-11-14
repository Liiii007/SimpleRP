#ifndef CUSTOM_DEFERRED_POST_INCLUDED
#define CUSTOM_DEFERRED_POST_INCLUDED

#include "../../ShaderLibrary/Common.hlsl"
#include "../../ShaderLibrary/Surface.hlsl"
#include "../../ShaderLibrary/Lighting.hlsl"

float4 _ProjectionParams;
float4x4 _InverseVPMatrix;

TEXTURE2D(_GBuffer0);
TEXTURE2D(_GBuffer1);
TEXTURE2D(_GBufferDepth);
SAMPLER(sampler_point_clamp);

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 screenUV : VAR_SCREEN_UV;
};

struct Attributes
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : VAR_WORLD_POSITION;
    float3 normalWS : VAR_NORMAL;
    float2 uv : VAR_BASE_UV;
};

Varyings DeferredPassVertex(uint vertexID : SV_VertexID)
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

half4 DeferredPassFragment(Varyings input) : SV_TARGET
{
    half4 gbuffer0 = SAMPLE_TEXTURE2D_LOD(_GBuffer0, sampler_point_clamp, input.screenUV, 0);
    half4 gbuffer1 = SAMPLE_TEXTURE2D_LOD(_GBuffer1, sampler_point_clamp, input.screenUV, 0);
    float depth = SAMPLE_TEXTURE2D(_GBufferDepth, sampler_point_clamp, input.screenUV).r;
    float4 worldPos = mul(_InverseVPMatrix, float4(input.screenUV * 2.0 - 1.0, depth, 1.0));
    worldPos /= worldPos.w;

    Surface surface;
    surface.position = worldPos;
    surface.viewDir = normalize(_WorldSpaceCameraPos - worldPos);
    surface.albedo = gbuffer0.rgb;
    surface.metallic = gbuffer0.a;
    surface.normal = normalize(gbuffer1.rgb);
    surface.roughness = gbuffer1.a;
    surface.ao = 1;

    return half4(GetLighting(surface), 1);
}

#endif
