#ifndef CUSTOM_SURFACE_INCLUDED
#define CUSTOM_SURFACE_INCLUDED

struct Surface
{
    float3 position;
    float3 viewDir;
    float3 normal;
    half3 albedo;
    half metallic;
    half roughness;
    half ao;
};

#endif
