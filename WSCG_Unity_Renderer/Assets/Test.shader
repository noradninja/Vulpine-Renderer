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
            #pragma exclude_renderers gles xbox360 ps3
            #pragma fragment frag
            #pragma target 3.0
            #include "UnityCG.cginc"
            #include "UnityStandardConfig.cginc"
            #include "UnityPBSLighting.cginc"
            #include "UnityStandardUtils.cginc"
            #include "Lighting.cginc"

            // LightData setup to match C# struct
            struct LightData
            {
                float3 position;
                float4 color;
                float range;
                float intensity;
            };
            // Raw size of our buffers for looping
            float _NumDirectionalLights;
            float _NumPointSpotLights;
            float _NumLightCookies;
            
            // Directional Lights
            StructuredBuffer<LightData> _DirectionalLightsBuffer;
            // Point/Spot Lights
            StructuredBuffer<LightData> _PointSpotLightsBuffer;
            // Light Cookie textures
            StructuredBuffer<Texture2D_half> _CookieTextureBuffer;
            
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
                float4x4 modelMatrix = unity_ObjectToWorld;
                float4x4 modelMatrixInverse = unity_WorldToObject;
                
                o.worldPos = mul(modelMatrix, v.vertex).xyz;
                o.normal = mul(float4(v.normal, 0.0), modelMatrixInverse).xyz;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.color = v.color * 0.5;
                return o;
            }

            float SpecularTerm(float3 lightDir, float3 viewDir, float3 normal, float shininess)
            {
                float3 H = normalize(lightDir + viewDir);
                float spec = pow(max(0.0, dot(H, normal)), shininess);
                return spec;
            }

            
            // Lambert Diffuse and Blinn-Phong Specular Lighting Calculation
            float4 LambertDiffuseAndBlinnPhongSpecular(float3 normal, float3 viewDir, float3 worldPos, float3 albedo, float3 lightColor, float shininess, float3 lightPos, float lightRange, float lightIntensity, float lightType)
            {
                float3 normalDirection = normalize(normal);
                float3 viewDirection = normalize(viewDir);
                float3 lightDirection;
                float attenuation;

                if (0.0 == lightType) // directional light?
                {
                    attenuation = 1.0; // no attenuation
                    lightDirection = normalize(lightPos);
                }
                else // point or spot light
                {
                    float3 vertexToLightSource = lightPos - worldPos;
                    float distance = length(vertexToLightSource);
                    attenuation = 1.0 / distance; // linear attenuation 
                    lightDirection = normalize(vertexToLightSource);
                }

                float3 ambientLighting = UNITY_LIGHTMODEL_AMBIENT * albedo;

                float diff = LambertTerm(lightDirection, normalDirection);
                float spec = SpecularTerm(lightDirection, viewDirection, normalDirection, shininess);

                float3 diffuseReflection = attenuation * lightColor * albedo * diff;

                float3 specularReflection = attenuation * lightColor * _Specular * spec;

                return float4(ambientLighting + diffuseReflection + specularReflection, 1.0);
            }

            // Fragment Shader
            half4 frag(v2f i) : COLOR
            {
                // Get view dierction for lighting calcs
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                // Initialize accumulated color and light cookie attenuation
                float3 accumColor = 0;
                float cookieAttenuation = 1.0;
                // Loop over directional lights
                for (int j = 0; j < _NumDirectionalLights; ++j)
                {
                    // Calculate array index for the current light
                    int arrayIndex = j;
                    // Extract LightData using array indices from the global buffers
                    LightData light = _DirectionalLightsBuffer[arrayIndex];
                    Texture2D_half lightCookieTexture =  _CookieTextureBuffer[arrayIndex];
                    // Add directional light contribution
                    accumColor += LambertDiffuseAndBlinnPhongSpecular(i.normal, viewDir, i.worldPos, float3(1, 1, 1), light.color.rgb, _Roughness, light.position, light.range, light.intensity, 0.0);
                     // initialize cookie attenuation to 1.0 so we arent multiplying by zero in the case of no cookie
                    cookieAttenuation = tex2D(lightCookieTexture, light.position.xy + float2(0.5, 0.5)).a;
                    accumColor *= cookieAttenuation;
                }

                // Loop over point/spot lights
                for (int k = 0; k < _NumPointSpotLights; ++k)
                {
                    // Calculate array index for the current light
                    int arrayIndexPS = k;
                    // Extract LightData using array indices from the global buffers
                    LightData pointSpotLight = _PointSpotLightsBuffer[arrayIndexPS];
                    Texture2D_half lightCookieTexture =  _CookieTextureBuffer[arrayIndexPS];
                    // Add point/spot light contribution
                    accumColor += LambertDiffuseAndBlinnPhongSpecular(i.normal, viewDir, i.worldPos, float3(0.5, 0.5, 0.5), pointSpotLight.color.rgb, _Roughness, pointSpotLight.position, pointSpotLight.range, pointSpotLight.intensity, 1.0);
                    // initialize cookie attenuation to 1.0 so we arent multiplying by zero in the case of no cookie
                    cookieAttenuation = tex2D(lightCookieTexture, pointSpotLight.position.xy / pointSpotLight.position.w + float2(0.5, 0.5)).a;
                    accumColor *= cookieAttenuation;
                }

                // Assign the final color to the pixel
                return float4(accumColor, 1.0);
            }

            ENDCG
        }
    }

    FallBack "Diffuse"
}
