Shader "Vulpine/DepthOnly_AlphaCut"
{
    Properties
    {
        _MOARMap ("MOAR (RGBA)", 2D) = "black" {}
        _Cutoff ("Alpha cutoff", Range(0,1)) = 0
        [Toggle] _PARALLAX_MAP ("Use Parallax In Depth Prepass", Float) = 0
        _ParallaxMap ("Parallax", 2D) = "white" {}
        _ParallaxStrength ("Parallax Strength", Range(0,10)) = 0
        _MainTex_ST ("MainTex ST (for parity)", Vector) = (1,1,0,0) // kept for UV parity if you need it
    }
    SubShader
    {
        Tags { "Queue"="AlphaTest" "RenderType"="TransparentCutout" }
        ZWrite On
        ColorMask 0
        Cull Back

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile_instancing
            #pragma multi_compile __ _PARALLAX_MAP

            #include "UnityCG.cginc"

            sampler2D _MOARMap;
            float4 _MOARMap_ST;
            float _Cutoff;

            sampler2D _ParallaxMap;
            float4 _ParallaxMap_ST;
            float _ParallaxStrength;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv     : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv  : TEXCOORD0;
                float3 tView : TEXCOORD1;
                float3 tX : TEXCOORD2;
                float3 tY : TEXCOORD3;
                float3 tZ : TEXCOORD4;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv  = TRANSFORM_TEX(v.uv, _MOARMap);

                // build TBN for optional parallax parity (cheap)
                float3 n = normalize(UnityObjectToWorldNormal(v.normal));
                float3 t = normalize(UnityObjectToWorldDir(v.tangent.xyz));
                float3 b = normalize(cross(n, t) * v.tangent.w);
                float3 viewDirWS = _WorldSpaceCameraPos - mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 viewDirTS = float3(dot(viewDirWS, t), dot(viewDirWS, b), dot(viewDirWS, n));
                o.tView = viewDirTS;
                o.tX = t; o.tY = b; o.tZ = n;
                return o;
            }

            float2 ApplyParallax(float2 uv, float3 tView)
            {
                // very light-weight parity so clip edges match when main pass uses parallax
                float3 v = normalize(tView);
                v.xy /= (v.z + 0.42);
                float h = tex2D(_ParallaxMap, uv).r;
                return uv + v.xy * (_ParallaxStrength * h);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float2 uv = i.uv;

                #if _PARALLAX_MAP
                    uv = ApplyParallax(uv, i.tView);
                #endif

                // use MOAR.b (your alpha) for cutout parity
                float alpha = tex2D(_MOARMap, uv).b;
                clip(alpha - _Cutoff);

                // depth only
                return 0;
            }
            ENDCG
        }
    }
}
