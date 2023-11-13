Shader "Custom RP/Lit"
{

    Properties
    {
        _Albedo("Albedo", Color) = (1.0, 1.0, 1.0, 1.0)
        _Metallic("Metallic", Float) = 1.0
        _Roughness("Roughness", Float) = 1.0
        _AO("AO", Float) = 1.0
    }

    SubShader
    {
        Pass
        {
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma enable_d3d11_debug_symbols
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            #include "LitPass.hlsl"
            ENDHLSL
        }
    }
}