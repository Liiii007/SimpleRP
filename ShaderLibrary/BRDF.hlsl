#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED

float D_GGX_TR(float roughness, float NdotH)
{
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH2 = NdotH * NdotH;

    float nom = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return nom / denom;
}

float G_Schlick_GGX(float roughness, float NdotV)
{
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;

    float nom = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}

float G_Smith_GGX(float roughness, float NdotV, float NdotH)
{
    return G_Schlick_GGX(roughness, NdotV) * G_Schlick_GGX(roughness, NdotH);
}

float3 F_Schlick(float3 f0, float cosTheta)
{
    return f0 + (1.0 - f0) * pow(saturate(1.0 - cosTheta), 5.0);
}


#endif
