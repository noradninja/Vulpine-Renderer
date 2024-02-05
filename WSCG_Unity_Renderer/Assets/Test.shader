Shader "Custom/LightShader"
{
    Properties
    {
        _MainTex ("Base (RGB)", 2D) = "white" { }
        _Roughness ("Smoothness", Range(0,1)) = 0.5
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
            #pragma fragment frag
            #pragma target 3.0
            #include "UnityCG.cginc"
            #include "UnityStandardConfig.cginc"
            #include "UnityPBSLighting.cginc"
            #include "UnityStandardUtils.cginc"
            #include "Lighting.cginc"
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

            // Lambert Diffuse and Blinn-Phong Specular Lighting Calculation
            float4 LambertDiffuseAndBlinnPhongSpecular(float3 normal, float3 viewDir, float3 albedo, float3 lightColor, float shininess, float3 lightPos, float lightRange, float lightIntensity)
            {
                // Lambert Diffuse
                float diffuseFactor = max(0, dot(normal, normalize(lightPos)));
                float3 diffuse = albedo * lightColor * lightIntensity * diffuseFactor / (1 + (0.01 * lightRange * lightRange));

                // Blinn-Phong Specular
                float3 halfwayDir = normalize(lightPos + viewDir);
                float specularFactor = pow(max(0, dot(normal, halfwayDir)), shininess);
                float3 specular = _Specular * lightColor * lightIntensity * specularFactor / (1 + (0.01 * lightRange * lightRange));

                return float4(diffuse + specular, 1.0);
            }

            // Struct for Vertex Input
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            // Struct for Vertex Output
            struct v2f
            {
                float4 pos : POSITION;
                float4 color : COLOR;
                float3 worldPos : TEXCOORD0;
                float3 normal : TEXCOORD1;
            };

            // Vertex Shader
            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normal = UnityObjectToWorldNormal(v.normal);

                return o;
            }

            // Fragment Shader
            half4 frag(v2f i) : COLOR
            {
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                // Initialize accumulated color
                float3 accumColor = 0;

                // Loop over directional lights
                for (int j = 0; j < _NumDirectionalLights; ++j)
                {
                    // Calculate array index for the current light
                    int arrayIndex = j;

                    // Extract LightData using array indices from global buffer
                    LightData light = _DirectionalLightsBuffer[arrayIndex];

                    // Add directional light contribution
                    accumColor += LambertDiffuseAndBlinnPhongSpecular(i.normal, viewDir, float3(1, 1, 1), light.color.rgb, _Roughness, light.position, light.range, light.intensity);
                }

                // Loop over point/spot lights
                for (int k = 0; k < _NumPointSpotLights; ++k)
                {
                    // Calculate array index for the current light
                    int arrayIndexPS = k;

                    // Extract LightData using array indices from global buffer
                    LightData pointSpotLight = _PointSpotLightsBuffer[arrayIndexPS];

                    // Add point/spot light contribution
                    accumColor += LambertDiffuseAndBlinnPhongSpecular(i.normal, viewDir, float3(1, 1, 1), pointSpotLight.color.rgb, _Roughness, pointSpotLight.position, pointSpotLight.range, pointSpotLight.intensity);
                }

                // Assign final color to pixel
                return float4(accumColor, 1.0);
            }
            ENDCG
        }
    }

    FallBack "Diffuse"
}
