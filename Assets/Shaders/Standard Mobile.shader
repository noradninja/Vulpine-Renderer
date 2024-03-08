﻿Shader "PSP2 RP/Standard Mobile"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" { }
        _NormalMap ("Normal Map", 2D) = "bump" { }
        _Roughness ("Roughness", Range(0,1)) = 0.5
        _Metalness ("Metalness", Range(0, 1)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #include "UnityCG.cginc"
            #include "UnityPBSLighting.cginc"
            #include "LightingFastest.cginc"

            // Global Properties
            float _NumDirectionalLights;
            float _NumPointSpotLights;
            // Shader Properties
            float _Roughness;
            float _Metalness;
            sampler2D _MainTex, _NormalMap;
            
            // Struct to match C# struct for referencing
            struct LightData
            {
                float3 position;
                float4 color;
                float range;
                float intensity;
            };
            // Struct for Vertex Input
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 color : COLOR;
                float2 uv: TEXCOORD0;
            };
            // Struct for Vertex Output
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 color : COLOR;
                float3 worldPos : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 tangent : TEXCOORD2;
                float2 uv: TEXCOORD3;
                
            };
            
            // Global Directional Lights Buffer
                StructuredBuffer<LightData> _DirectionalLightsBuffer;
            // Global Point/Spot Lights Buffer
                StructuredBuffer<LightData> _PointSpotLightsBuffer;
            
            // Vertex Shader
            v2f vert(appdata v)
            {
                v2f o;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normal = mul(v.normal, unity_WorldToObject);
                o.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.color = v.color;
                o.uv = v.uv;
                return o;
            }
            // Fragment Shader
            half4 frag(v2f i) : SV_Target
            {
                // Initialize accumulated color
                float3 accumColor = 0;
                // Sample the albedo and normal maps
                float3 albedo = tex2D(_MainTex, i.uv).rgb;
                float3 normalMap = UnpackNormal(tex2D(_NormalMap, i.uv.xy));
                // Prevents multing by zero on nonmetals
                _Metalness += 0.001;
                // Compute normal mapping
                float3 binormal = cross(i.normal, i.tangent.xyz) * (i.tangent.w * unity_WorldTransformParams.w);
                float3 normal = normalize(
		                        normalMap.x * i.tangent +
		                        normalMap.y * binormal +
		                        normalMap.z * i.normal);
                //Direction of ray from the camera towards the object surface
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos); 
                // Per vertex grazing/Schlick terms
                float3 grazingAngle = pow(1 - max(0.0, dot(i.normal, viewDir)), 4);
                float3 F = pow(1 - dot(i.normal, viewDir), 2);
                // Reflection direction- we *could* add a per vertex toggle here
                half3 reflection = reflect(-viewDir, UnityObjectToWorldNormal(normal)); // Direction of ray after hitting the surface of object
                
                // Loop over directional lights
                for (int j = 0; j < 4; ++j)
                {
                    // Calculate array index for the current light
                    int arrayIndex = j;
                    // Extract LightData using array indices from the global buffer
                    LightData light = _DirectionalLightsBuffer[arrayIndex];
                    // Add directional light contribution
                    accumColor += LightAccumulation(
                            normal, viewDir, albedo,
                            light.color.rgb * _Metalness, _Roughness,
                            i.worldPos, light.position, light.color,
                            light.range, light.intensity,
                            0.0, 0.0, grazingAngle, reflection, F
                        );
                }
                // Loop over point/spot lights
                for (int k = 0; k < 8; ++k)
                {
                    // Calculate array index for the current light
                    int arrayIndexPS = k;
                    // Extract LightData using array indices from the global buffer
                    LightData pointSpotLight = _PointSpotLightsBuffer[arrayIndexPS];
                    // Add point/spot light contribution
                    accumColor += LightAccumulation(
                            normal, viewDir, albedo,
                            pointSpotLight.color.rgb * _Metalness, _Roughness,
                            i.worldPos, pointSpotLight.position, pointSpotLight.color,
                            pointSpotLight.range, pointSpotLight.intensity,
                            2.0, 45.0, grazingAngle, reflection, F
                        );
                }
                // Assign the final color to the fragment
                return float4(accumColor, 1.0);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}