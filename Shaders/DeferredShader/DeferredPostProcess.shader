Shader "Hidden/Custom RP/Deferred Post Process"
{
    SubShader
    {
        Cull Off
        ZTest Always
        ZWrite Off

        HLSLINCLUDE
        #include "DeferredPostProcess.hlsl"
        ENDHLSL

        Pass
        {
            Name "Deferred Post Process"

            HLSLPROGRAM
            #pragma target 3.5
            #pragma enable_d3d11_debug_symbols
            #pragma vertex DeferredPassVertex
            #pragma fragment DeferredPassFragment
            ENDHLSL
        }
    }
}
