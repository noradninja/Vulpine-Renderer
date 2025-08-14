Shader "Custom/DeferredFinalPass" {
    Properties {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _ReflectTex ("Reflection (RGB)", 2D) = "white" {}
        _AmbientLightColor ("Ambient Light Color", Color) = (1, 1, 1, 1)
        _ReflectionIntensity ("Reflection Intensity", Range(0.0, 1.0)) = 0.5
    }
    SubShader {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGINCLUDE
        #include "UnityCG.cginc"

        struct appdata_t {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct v2f {
            float4 pos : SV_POSITION;
            float2 uv : TEXCOORD0;
        };

        sampler2D _MainTex;
        sampler2D _LightBuffer;
        sampler2D _ReflectTex;

        float3 _AmbientLightColor;
        float _ReflectionIntensity;

        // Vertex Shader Function
        v2f vert (appdata_t v) {
            v2f o;
            o.pos = UnityObjectToClipPos(v.vertex); // Transform vertex position to clip space
            o.uv = v.uv; // Pass texture coordinates to fragment shader
            return o;
        }

        half4 frag (v2f i) : SV_Target {
            // Fetch Albedo, Lighting, and Reflection
            float3 albedo = tex2D(_MainTex, i.uv).rgb;
            float3 lighting = tex2D(_LightBuffer, i.uv).rgb;
            float3 reflection = tex2D(_ReflectTex, i.uv).rgb;

            // Add Ambient Lighting
            float3 color = albedo * lighting + _AmbientLightColor;

            // Add Reflection
            color = lerp(color, reflection, _ReflectionIntensity); // Blend with reflection

            return half4(color, 1.0);
        }
        ENDCG

        Pass {
            Name "Final"
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            ENDCG
        }
    }
    FallBack "Diffuse"
}
