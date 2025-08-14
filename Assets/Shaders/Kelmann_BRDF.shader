Shader "Custom/KelemenBRDFShader"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)
        _Roughness ("Roughness", Range(0.0, 1.0)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            half4 _MainTex_ST;
            half3 _SpecularColor;
            half _Roughness;
            float3 _LightPosition; // Set this from script
            // Light buffers
            float4x4 _DirectionalLightsBuffer[2];
            float4x4 _PointSpotLightsBuffer[4];

            struct v2f
            {
                float4 vertex : SV_POSITION;
                half2 uv : TEXCOORD0;
                half3 worldPos : TEXCOORD1;
                half3 normal : TEXCOORD2;
                half3 viewDir : TEXCOORD3;
            };

            v2f vert(appdata_full v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.viewDir = normalize(_WorldSpaceCameraPos - o.worldPos);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                // Sample textures
                half4 albedo = tex2D(_MainTex, i.uv);
                half3 N = normalize(i.normal);
                half3 V = normalize(i.viewDir);
                half3 L = normalize(_LightPosition - i.worldPos);

                // Calculate half-vector
                half3 H = normalize(L + V);

                // Compute dot products
                half NdotL = saturate(dot(N, L));
                half NdotV = saturate(dot(N, V));
                half HdotV = saturate(dot(H, V));
                half HdotL = saturate(dot(H, L));

                // Fresnel term (simplified)
                half oneMinusHdotV = 1.0 - HdotV;
                half Fresnel = oneMinusHdotV * oneMinusHdotV;
                Fresnel *= Fresnel * oneMinusHdotV; // Fresnel = (1 - HdotV)^5
                half3 finalColor = 0;
                half3 diffuse = 0;
                UNITY_UNROLL
                // Iterate through all lights in one loop for efficiency
                for (int j = 0; j < 6; ++j)
                {
                    ;
                    UNITY_BRANCH
                    if (j < 2)
                    {
                        _LightPosition = _DirectionalLightsBuffer[j][0];
                        _SpecularColor = _DirectionalLightsBuffer[j][1];
                        //variables = _DirectionalLightsBuffer[j][3];
                    }
                    else
                    {
                        int index = j - 2;
                        _LightPosition = _PointSpotLightsBuffer[index][0];
                        _SpecularColor = _PointSpotLightsBuffer[index][1];
                        //variables = _PointSpotLightsBuffer[index][3];
                    }
                half3 F0 = _SpecularColor;
                half3 F = F0 + (1.0 - F0) * Fresnel;

                // Specular term
                half invDenominator = rcp(max(HdotV * HdotL, 1e-4));
                half specularCoefficient = NdotL * NdotV * invDenominator;
                half3 specular = F * specularCoefficient;

                // Diffuse term
                diffuse = NdotL * albedo.rgb;
                // Final color
                finalColor += specular;
                }
                return half4(finalColor + diffuse, albedo.a);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
