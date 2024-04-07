Shader "Hidden/Internal-PrePassLighting" {
    Properties {
        _LightTexture0 ("", any) = "" {}
        _LightTextureB0 ("", 2D) = "" {}
        _ShadowMapTexture ("", any) = "" {}
    }
    SubShader {
        CGINCLUDE
        #include "UnityCG.cginc"
        #include "UnityDeferredLibrary.cginc"

        sampler2D _CameraNormalsTexture;
        float4 _CameraNormalsTexture_ST;

        // GGX term for specular calculation
        half GGXTerm(half roughness, half3 normal, half) {
     
        }

      
        // Schlick Fresnel approximation
        half3 SchlickFresnel(half cosTheta, half3 F0) {
            return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
        }

        // Smith Joint GGX for specular calculation
        half SmithJointGGXCorrelated(half NdotL, half roughness) {
            half alpha = roughness * roughness;
            half alphaSqr = alpha * alpha;
            half lambdaL = NdotL * sqrt((-NdotL * alphaSqr) + NdotL);
            return 0.5 / (lambdaL + sqrt(1.0 + alphaSqr));
        }

        half4 CalculateLight (unity_v2f_deferred i)
        {
            float3 wpos;
            float2 uv;
            half3 lightDir;
            float atten, fadeDist;
            UnityDeferredCalculateLightParams (i, wpos, uv, lightDir, atten, fadeDist);

            // Compute view direction
            half3 viewDir = normalize(wpos - _WorldSpaceCameraPos.xyz);

            half4 nspec = tex2D (_CameraNormalsTexture, TRANSFORM_TEX(uv, _CameraNormalsTexture));
            half3 normal = nspec.rgb * 2 - 1;
            normal = normalize(normal);

            // Disney Diffuse
            half3 albedo = _LightColor.rgb / 3.14159;

            // Schlick Fresnel
            half3 fresnel = SchlickFresnel(max(0, dot(lightDir, normal)), _LightColor.rgb);
            float3 grazingAngle = max (0,pow(1 - dot(normal, viewDir), 0.35));
            // GGX Specular
            half roughness = 0;//nspec.a;
                       // Get dot products needed
            float3 h = normalize(viewDir + lightDir);
            float nh = max(0.0, dot(normal, h));
            float nv = max(0.0, dot(normal, viewDir));
            float nl = max(0.0, dot(normal, lightDir));
            float roughnessSq = roughness * roughness;
            // Absolute value of reflection intensity 
            float a = nh * nh * (roughnessSq - 1.0) + 1.0;
            // Combine the terms before division
            float invDenominator = 1.0 / (3.14 * a * a);
            // Normal distribution
            float D = roughnessSq * invDenominator;
           // Shadow sidedness
            float G1 = (1.0 * nh) * invDenominator;
            // Shadow distribution
            float G = min(1.0, min(G1, 2.0 * nl / nh));
            // Fresnel-Schlick approximation
            float3 F = grazingAngle;
            // Avoid division by zero by adding a small value
            float denominator = 4.0 * nv * nl + 0.001;
            // Multiply instead of dividing
            half3 specular = (D * G * F) * rsqrt(denominator);

            // Final result
            half3 diff = albedo * (1 - fresnel);
            half3 spec = specular;

            half4 res;
            res.xyz = (diff + spec) * (diff * atten);
            res.w = 1.0;

            float fade = fadeDist * unity_LightmapFade.z + unity_LightmapFade.w;
            res *= saturate(1.0 - fade);

            return res;
        }
        ENDCG

        /*Pass 1: LDR Pass - Lighting encoded into a subtractive ARGB8 buffer*/
        Pass {
            ZWrite Off
            Blend DstColor Zero

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_deferred
            #pragma fragment frag
            #pragma multi_compile_lightpass

            fixed4 frag (unity_v2f_deferred i) : SV_Target
            {
                return exp2(-CalculateLight(i));
            }
            ENDCG
        }

        /*Pass 2: HDR Pass - Lighting additively blended into floating point buffer*/
        Pass {
            ZWrite Off
            Blend One One

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_deferred
            #pragma fragment frag
            #pragma multi_compile_lightpass

            fixed4 frag (unity_v2f_deferred i) : SV_Target
            {
                return CalculateLight(i);
            }
            ENDCG
        }
    }
    Fallback Off
}
