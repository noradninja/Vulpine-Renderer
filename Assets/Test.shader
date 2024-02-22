Shader "Custom/LightShader"
{
    Properties
    {
        _MainTex ("Base (RGB)", 2D) = "white" { }
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

            // Struct for Vertex Input
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 color : COLOR;
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
                float4x4 modelMatrixInverse = unity_WorldToObject;

                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normal = mul(float4(v.normal, 0.0), modelMatrixInverse).xyz;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.color = v.color * 0.5;
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

                    // Extract LightData using array indices from the global buffer
                    LightData light = _DirectionalLightsBuffer[arrayIndex];

                    // Add directional light contribution
                    accumColor += LightAccumulation(
                        i.normal,
                        viewDir,
                        float3(0.5,0.5,0.5),
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
                        i.normal,
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
                        26
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
