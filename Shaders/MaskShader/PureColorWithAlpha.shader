Shader "Simple/PureColorWithAlpha"
{
    Properties
    {
        _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
    }

    HLSLINCLUDE
    #include "../../ShaderLibrary/Common.hlsl"
    #include "../../ShaderLibrary/SDF.hlsl"
    ENDHLSL

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
        }

        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex UnlitVertex
            #pragma fragment UnlitFragment

            struct Attributes
            {
                float3 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                TEXTURE2D(_MainTex);
                SAMPLER(sampler_MainTex);
                float4 _Color;
            CBUFFER_END

            Varyings UnlitVertex(Attributes v)
            {
                Varyings o = (Varyings)0;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                o.uv = v.uv;
                return o;
            }

            half4 UnlitFragment(Varyings i) : SV_Target
            {
                float4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float4 color = _Color;
                color.a = mainTex.a;
                return color;
            }
            ENDHLSL
        }
    }
}