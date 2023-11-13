#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED

#include "../ShaderLibrary/Common.hlsl"
#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"

CBUFFER_START(UnityPerMaterial)
    float3 _Albedo;
    float _Metallic;
    float _Roughness;
    float _AO;
CBUFFER_END

struct Attributes
{
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 baseUV : TEXCOORD0;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : VAR_POSITION;
    float3 normalCS : VAR_NORMAL;
    float2 baseUV : VAR_BASE_UV;
};

Varyings LitPassVertex(Attributes input)
{
    Varyings output;
    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.normalCS = TransformObjectToWorldNormal(input.normalOS);
    output.baseUV = input.baseUV;
    return output;
}

float4 LitPassFragment(Varyings input) : SV_TARGET
{
    //Fill fragment's surface data
    Surface surface;
    surface.position = input.positionWS;
    surface.viewDir = normalize(_WorldSpaceCameraPos - input.positionWS);
    surface.albedo = _Albedo;
    surface.normal = normalize(input.normalCS);
    surface.metallic = _Metallic;
    surface.roughness = _Roughness;
    surface.ao = _AO;

    //Calculate lighting
    return float4(GetLighting(surface), 1.0);
}

#endif
