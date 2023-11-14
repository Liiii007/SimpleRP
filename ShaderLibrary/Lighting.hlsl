#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

#include "BRDF.hlsl"

struct Light
{
    half3 color;
    half3 direction;
};

Light GetDirectionalLight()
{
    Light light;

    light.color = half3(1, 1, 1) * 10;
    light.direction = normalize(half3(-1, -1, 1));
    return light;
}

inline half3 IncomingLight(Surface surface, Light light)
{
    float3 halfwayDir = normalize(-light.direction + surface.viewDir);

    //Cook-Torrance
    half NdotH = saturate(dot(surface.normal, halfwayDir));
    half NdotV = saturate(dot(surface.normal, surface.viewDir));
    half NdotL = saturate(dot(surface.normal, -light.direction));

    half D = D_GGX_TR(surface.roughness, NdotH);
    half G = G_Smith_GGX(surface.roughness, NdotV, NdotL);

    half3 F0 = half3(0.04, 0.04, 0.04);
    F0 = lerp(F0, surface.albedo, surface.metallic);

    half3 F = F_Schlick(F0, saturate(dot(halfwayDir, surface.viewDir)));
    half3 kS = F;
    half3 kD = 1 - kS;
    kD *= 1 - surface.metallic;

    half3 lambert = kD * surface.albedo * INV_PI + D * G * F / (4 * NdotV * NdotL + 0.0001);
    half3 ambient = 0.03 * surface.albedo * surface.ao;
    half3 result = (lambert) * light.color * NdotL + ambient;
    return result;
}

inline half3 GetLighting(Surface surface, Light light)
{
    half3 color = IncomingLight(surface, light);
    return color;
}

inline half3 GetLighting(Surface surface)
{
    return GetLighting(surface, GetDirectionalLight());
}

#endif
