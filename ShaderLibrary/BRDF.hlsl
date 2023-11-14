#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED

inline half D_GGX_TR(half roughness, half NdotH)
{
    half a2 = Pow4(roughness);
    half NdotH2 = NdotH * NdotH;
    half nom = a2;
    half denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return nom / denom;
}

inline half G_Schlick_GGX(half roughness, half NdotV)
{
    half r = (roughness + 1.0);
    half k = (r * r) / 8.0;

    half nom = NdotV;
    half denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}

inline half G_Smith_GGX(half roughness, half NdotV, half NdotL)
{
    return G_Schlick_GGX(roughness, NdotV) * G_Schlick_GGX(roughness, NdotL);
}

inline half3 F_Schlick(half3 f0, half cosTheta)
{
    return f0 + (1.0 - f0) * pow(saturate(1.0 - cosTheta), 5);
}

#endif
