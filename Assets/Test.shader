Shader "Custom/LightShader"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" { }
        _NormalMap ("Normal Map", 2D) = "bump" { }
        _Roughness ("Roughness", Range(0,1)) = 0.5
        _Specular ("Specular Intensity", Range(0, 1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma exclude_renderers gles xbox360 ps3
            #pragma fragment frag
            #pragma target 3.0
            #include "UnityCG.cginc"
            #include "UnityStandardConfig.cginc"
            #include "UnityPBSLighting.cginc"
            #include "UnityStandardUtils.cginc"
            #include "LightingFastest.cginc"

            // to make internal referencing easier
            struct LightData
            {
                float3 position;
                float4 color;
                float range;
                float intensity;
            };

            float _NumDirectionalLights;
            float _NumPointSpotLights;
            
            // Directional Lights
            StructuredBuffer<LightData> _DirectionalLightsBuffer;

            // Point/Spot Lights
            StructuredBuffer<LightData> _PointSpotLightsBuffer;

            // Shader Properties
            float _Roughness;
            float _Specular;
            sampler2D_half _MainTex, _NormalMap;
            
            // Struct for Vertex Input
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 color : COLOR;
                float2 uv: TEXCOORD0;
            };

            // Struct for Vertex Output
            struct v2f
            {
                float4 pos : POSITION;
                float4 color : COLOR;
                float3 worldPos : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float2 uv: TEXCOORD2;
                
            };

            // Vertex Shader
            v2f vert(appdata v)
            {
                v2f o;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normal = mul(v.normal, unity_WorldToObject);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.color = v.color * 0.5;
                o.uv = v.uv;
                return o;
            }

            // Fragment Shader
            half4 frag(v2f i) : COLOR
            {
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                // Initialize accumulated color
                float3 accumColor = 0;
                // Sample the albedo and normal maps
                float3 albedo = tex2D(_MainTex, i.uv).rgb;
                float3 vertNormal = normalize(i.normal);
                float4 normalMap = tex2D(_NormalMap, i.uv);
                float3 normalized = UnpackNormal(normalMap);
                // Apply normal mapping
                float3 normal = vertNormal;//nomalized * vertNormal; // <-------------THIS IS OBVIOUSLY WRONG, BUT OBJECTIVELY COOL LOOKING ANYWAY
                // Loop over directional lights
                for (int j = 0; j < _NumDirectionalLights; ++j)
                {
                    // Calculate array index for the current light
                    int arrayIndex = j;

                    // Extract LightData using array indices from the global buffer
                    LightData light = _DirectionalLightsBuffer[arrayIndex];

                    // Add directional light contribution
                    accumColor += LightAccumulation(
                        normal,
                        viewDir,
                        albedo,
                        light.color.rgb * _Specular,
                        _Roughness,
                        i.worldPos,
                        light.position,
                        light.color,
                        light.range,
                        light.intensity,
                        0.0,
                        0.0
                        );
                }

                // Loop over point/spot lights
                for (int k = 0; k < _NumPointSpotLights; ++k)
                {
                    // Calculate array index for the current light
                    int arrayIndexPS = k;

                    // Extract LightData using array indices from the global buffer
                    LightData pointSpotLight = _PointSpotLightsBuffer[arrayIndexPS];

                    // Add point/spot light contribution
                    accumColor += LightAccumulation(
                        normal,
                        viewDir,
                        float3(0.5,0.5,0.5),
                        pointSpotLight.color.rgb * _Specular,
                        _Roughness,
                        i.worldPos,
                        pointSpotLight.position,
                        pointSpotLight.color,
                        pointSpotLight.range,
                        pointSpotLight.intensity,
                        2.0,
                        45
                        );
                }
                // Assign the final color to the pixel
                return float4(accumColor, 1.0);
            }

            ENDCG
        }
    }

    FallBack "Diffuse"
}
