// Upgrade NOTE: replaced 'unity_World2Shadow' with 'unity_WorldToShadow'
// Upgrade NOTE: replaced '_LightMatrix0' with 'unity_WorldToLight'

Shader "Vulpine Renderer/Lit"
{
    Properties
    {
        [Enum(Opaque,2,Cutout,0)] _BlendingMode ("Blending Mode", Float) = 0.0
        _MainTex ("Albedo (RGB)", 2D) = "black" { }
        _MOARMap ("MOAR (RGBA)", 2D) = "black" { }
        _ParallaxMap ("Parallax", 2D) = "white" {}
        _ParallaxStrength ("Parallax Strength", Range(0, 10)) = 0
        _cookieTexture ("LightCookie (RGBA)", 2D) = "black" { }
        _Cutoff ("Alpha cutoff", Range(0,1)) = 0
        _NormalMap ("Normal Map", 2D) = "bump" { }
        _NormalHeight ("Height", Range(-2,2)) = 1
        _Roughness ("Roughness", Range(0,1)) = 0.5
        _Metalness ("Metalness", Range(0, 1)) = 0.5
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0
        [ToggleOff] _SoftBody("Soft Body", float) = 0.0
    }

    SubShader
    {
        // Keep AlphaTest queue & Cutout render type; no blending needed because we clip
        Tags { "Queue"="Geometry" "IgnoreProjector"="True" "RenderType"="TransparentCutout" "LightMode"="ForwardBase" }        LOD 80
        ZWrite On
        Cull [_BlendingMode]
        Blend Off

        Pass
        {
            CGPROGRAM
            // Pragmas
            #pragma vertex   vert
            #pragma fragment frag
            #pragma target   3.0
            #pragma multi_compile _ SHADOWS_SCREEN
            #pragma multi_compile _ SHADOWS_DEPTH
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #pragma multi_compile __ POINT SPOT
            #pragma multi_compile __ AMBIENT_ON
            #pragma shader_feature _PARALLAX_MAP

            // Includes
            #include "UnityCG.cginc"
            #include "UnityPBSLighting.cginc"
            #include "AutoLight.cginc"
            #include "LightingFastest.cginc"

            // Counts
            float _NumDirectionalLights, _NumPointSpotLights;

            // Packed directional rows (max 4)
            float4 _DirL0[4]; // pos/range or dir (see usage in LightAccumulation)
            float4 _DirL1[4]; // color/intensity (a forced to 1)
            float4 _DirL2[4]; // rotation/axis
            float4 _DirL3[4]; // variables: x=spotAngle, y=intensity, z=type(0/1/2), w=id

            // Packed point/spot rows (max 8)
            float4 _PSL0[8];
            float4 _PSL1[8];
            float4 _PSL2[8];
            float4 _PSL3[8];

            // Shader properties
            float _Roughness, _Metalness, _Cutoff, _ParallaxStrength, _NormalHeight, _SpecularHighlights, _GlossyReflections, _SoftBody;
            sampler2D _MainTex, _NormalMap, _MOARMap, _cookieTexture, _ParallaxMap;

            // STs
            float4 _MainTex_ST;
            float4 _NormalMap_ST;
            float4 _MOARMap_ST;
            float4 _ParallaxMap_ST;

            struct appdata
            {
                float4 vertex  : POSITION;
                float3 normal  : NORMAL;
                float4 tangent : TANGENT;
                float4 color   : COLOR;
                float2 uv      : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex   : SV_POSITION;
                float4 color    : COLOR0;
                float3 worldPos : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS: TEXCOORD2;
                float2 uv       : TEXCOORD3;
                SHADOW_COORDS(4)
                #if defined(SHADOWS_SCREEN)
                    float4 shadowCoordinates : TEXCOORD5;
                #endif
                float3 tangentViewDir : TEXCOORD6;
            };

            // Vertex
            v2f vert(appdata v)
            {
                v2f o;

                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 nWS = UnityObjectToWorldNormal(v.normal);
                float3 tWS = UnityObjectToWorldDir(v.tangent.xyz);
                float  tW  = v.tangent.w;

                if (_SoftBody)
                {
                    // NOTE: WindVertexDeformation is defined in LightingCalculations.cginc
                    float3 wind = float3(0.33, 0.11515, 0.66);
                    float4 deformed = WindVertexDeformation(v.vertex, normalize(worldPos), 5.0, 0.01, 0.005, wind, 0.75, _Time);
                    o.vertex = UnityObjectToClipPos(deformed);
                    worldPos = mul(unity_ObjectToWorld, deformed).xyz;
                }
                else
                {
                    o.vertex = UnityObjectToClipPos(v.vertex);
                }

                o.worldPos  = worldPos;
                o.normalWS  = nWS;
                o.tangentWS = float4(tWS, tW);
                o.color     = v.color;
                o.uv        = v.uv;

                // Build tangent-space view dir for optional parallax
                float3 bWS = normalize(cross(nWS, tWS) * (tW * unity_WorldTransformParams.w));
                float3 viewDirWS = _WorldSpaceCameraPos - worldPos;
                float3x3 worldToTangent = float3x3(
                    tWS,
                    bWS,
                    nWS
                );
                o.tangentViewDir = mul(worldToTangent, viewDirWS);

                TRANSFER_VERTEX_TO_FRAGMENT(o);
                TRANSFER_SHADOW(o);
                return o;
            }

            // Fragment
            half4 frag(v2f i) : SV_Target
            {
                UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);

                // Start with base UV (apply optional parallax before sampling alpha)
                float2 uvMain = i.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                float2 uvMOAR = i.uv * _MOARMap_ST.xy + _MOARMap_ST.zw;
                float2 uvNrm  = i.uv * _NormalMap_ST.xy + _NormalMap_ST.zw;

                #if defined(_PARALLAX_MAP)
                    // Tangent-space parallax offset (matching your previous logic)
                    float3 tv = normalize(i.tangentViewDir);
                    tv.xy /= (tv.z + 0.42);
                    float  height = tex2D(_ParallaxMap, i.uv * _ParallaxMap_ST.xy + _ParallaxMap_ST.zw).r;
                    float2 parallaxOffset = tv.xy * (_ParallaxStrength * height);
                    uvMain += parallaxOffset;
                    uvMOAR += parallaxOffset;
                    uvNrm  += parallaxOffset;
                #endif

                // Early alpha clip to skip heavy work
                float4 MOARearly = tex2D(_MOARMap, uvMOAR);
                clip(MOARearly.b - _Cutoff);

                // Sample albedo and normal after clip
                float4 albedo = tex2D(_MainTex, uvMain);
                float3 nTex   = ExtractNormal(tex2D(_NormalMap, uvNrm), _NormalHeight);

                // Build TBN and final normal
                float3 tWS = i.tangentWS.xyz;
                float3 bWS = normalize(cross(i.normalWS, tWS) * (i.tangentWS.w * unity_WorldTransformParams.w));
                float3 nWS = normalize(
                    nTex.x * tWS +
                    nTex.y * bWS +
                    nTex.z * i.normalWS
                );

                float3 sh = ShadeSH9(float4(nWS, 1.0));
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb + sh;

                // View, reflection, grazing
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 reflection = reflect(-viewDir, nWS);
                albedo.rgb += 0.1; // tiny bias as in your original
                float3 grazingAngle = max(0, pow(1 - dot(i.normalWS, viewDir), 0.35));

                // Unity shadows/attenuation
                float shadow = attenuation;

                // MOAR (material params)
                float4 MOAR = MOARearly; // already sampled (r=metal, g=AO, b=alpha, a=roughness)
                float  metal  = max(0.001, _Metalness * MOAR.r);
                float  rough  = _Roughness * MOAR.a;

                // Accumulator
                float4 accumColor = float4(0,0,0,1);

                // ---- Directional lights (max 4), masked by count ----
                [unroll]
                for (int j = 0; j < 4; ++j)
                {
                    float active = step(j, _NumDirectionalLights - 1);

                    float4 position = _DirL0[j]; // note: for dir lights you can store dir here or in rotation
                    float4 color    = _DirL1[j]; color.w = 1;
                    float4 rotation = _DirL2[j];
                    float4 vars     = _DirL3[j]; // x=spotAngle, y=intensity, z=type(0 dir), w=id

                    float3 specColor = color.rgb;

                    float4 grab = LightAccumulation(
                        i.normalWS, nWS, viewDir, albedo, MOAR,
                        specColor, rough, metal,
                        i.worldPos, position, color.xyz,
                        position.w, vars.y,
                        vars.z, vars.x, grazingAngle,
                        reflection, _Cutoff, shadow, _cookieTexture, _SpecularHighlights, _GlossyReflections
                    );

                    accumColor += grab * active;
                }

                // ---- Point/Spot lights (max 8), masked by count ----
                [unroll]
                for (int k = 0; k < 8; ++k)
                {
                    float active = step(k, _NumPointSpotLights - 1);

                    float4 position = _PSL0[k];
                    float4 color    = _PSL1[k]; color.w = 1;
                    float4 rotation = _PSL2[k];
                    float4 vars     = _PSL3[k]; // z=type(1 point, 2 spot)

                    float3 specColor = color.rgb;

                    float4 grab = LightAccumulation(
                        i.normalWS, nWS, viewDir, albedo, MOAR,
                        specColor, rough, metal,
                        i.worldPos, position, color.xyz,
                        position.w, vars.y,
                        vars.z, vars.x, grazingAngle,
                        reflection, _Cutoff, shadow, _cookieTexture, _SpecularHighlights, _GlossyReflections
                    );

                    accumColor += grab * active;
                }
                accumColor + ambient;

                return accumColor;
            }
            ENDCG
        }

        // (Optional ShadowCaster pass was commented out in your original; leaving it out to preserve behavior)
    }

    FallBack "Diffuse"
}
