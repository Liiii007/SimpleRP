#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

#include "BRDF.hlsl"

struct Light
{
    float3 color;
    float3 direction;
};

Light GetDirectionalLight()
{
    Light light;

    light.color = float3(1, 1, 1);
    light.color *= 10;
    light.direction = float3(-1, -1, 1);
    light.direction = normalize(light.direction);
    return light;
}

float3 IncomingLight(Surface surface, Light light)
{
    float3 halfwayDir = normalize(-light.direction + surface.viewDir);

    //Cook-Torrance
    float NdotH = saturate(dot(surface.normal, halfwayDir));
    float NdotV = saturate(dot(surface.normal, surface.viewDir));
    float NdotL = saturate(dot(surface.normal, -light.direction));
    
    float D = D_GGX_TR(surface.roughness, NdotH);

    float G = G_Smith_GGX(surface.roughness, NdotV, NdotL);

    float3 F0 = float3(0.04, 0.04, 0.04);
    F0 = lerp(F0, surface.albedo, surface.metallic);

    float3 F = F_Schlick(F0, saturate(dot(halfwayDir, surface.viewDir)));
    float3 kS = F;
    float3 kD = 1 - kS;
    kD *= 1 - surface.metallic;

    float3 lambert = kD * surface.albedo / PI;

    float3 specular = D * G * F / (4 * NdotV * NdotL + 0.0001);

    float3 ambient = 0.03 * surface.albedo * surface.ao;
    float3 result = (lambert + specular) * light.color * NdotL + ambient;
    return result;
}

float3 GetLighting(Surface surface, Light light)
{
    float3 color = IncomingLight(surface, light);
    return color;
}

float3 GetLighting(Surface surface)
{
    return GetLighting(surface, GetDirectionalLight());
}

#endif
