#ifndef CUSTOM_DEFERRED_INCLUDED
#define CUSTOM_DEFERRED_INCLUDED

#include "../../ShaderLibrary/Common.hlsl"

CBUFFER_START(UnityPerMaterial)
    float3 _Albedo;
    float _Metallic;
    float _Roughness;
    float _AO;
CBUFFER_END

struct Varying
{
    float3 position : POSITION;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
};

struct Attributes
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : VAR_WORLD_POSITION;
    float3 normalWS : VAR_NORMAL;
    float2 uv : VAR_BASE_UV;
};

Attributes DeferredPassVertex(Varying input)
{
    Attributes output;
    output.positionWS = TransformObjectToWorld(input.position);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.normalWS = TransformObjectToWorldNormal(input.normal);
    output.uv = input.uv;
    return output;
}

void DeferredPassFragment(Attributes input,
                          out half4 outGBuffer0 : SV_Target0,
                          out float4 outGBuffer1 : SV_Target1)
{
    outGBuffer0 = half4(_Albedo.xyz, _Metallic);
    outGBuffer1 = half4(input.normalWS.xyz, _Roughness);
}

#endif
