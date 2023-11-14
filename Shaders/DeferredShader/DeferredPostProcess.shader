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
            #pragma vertex DeferredPassVertex
            #pragma fragment DeferredPassFragment
            ENDHLSL
        }
    }
}
