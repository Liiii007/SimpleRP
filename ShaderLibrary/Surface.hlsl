#ifndef CUSTOM_SURFACE_INCLUDED
#define CUSTOM_SURFACE_INCLUDED

struct Surface
{
    float3 position;
    float3 viewDir;
    float3 normal;
    float3 albedo;
    float metallic;
    float roughness;
    float ao;
};

#endif
