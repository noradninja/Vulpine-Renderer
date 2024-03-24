#include <UnityCG.cginc>
#include <UnityLightingCommon.cginc>
#include "LightingCalculations.cginc"

//local varyings
float3 lightDir;
float attenuation;

// Decode RGBM encoded HDR values from a cubemap
float3 DecodeHDR(in float4 rgbm)
{
    return rgbm.rgb * rgbm.a * 16.0;
}

// Loop for one light
float4 LightAccumulation(float3 normal, float3 viewDir, float4 albedo, float4 MOAR, float3 specularColor, float roughness,
                         float metalness, float3 worldPosition, float3 lightPosition, float3 lightColor, float range, float intensity,
                         float lightType, float spotAngle, float3 grazingAngle, float3 reflection)
{
    half fallOff = 1.0;
    if (lightType < 0.5) // directional light
    {
        lightDir = normalize(lightPosition);
    }
    else // point/spot light
    {
        float3 vertexToLightSource = lightPosition - worldPosition;
        half lightDst = dot(vertexToLightSource, vertexToLightSource);
        lightDir = normalize(vertexToLightSource);
        half normalizedDist = lightDst / range * range;
        fallOff = saturate(1.0 / (1.0 + 25.0 * normalizedDist * normalizedDist) * saturate((1 - normalizedDist) * 5.0));
    }
    //Decompose MOAR into values
    metalness = MOAR.r * metalness;
    half occlusion = MOAR.g;
    half alpha = MOAR.b;
    roughness = MOAR.a * roughness;
    
    // Calculate the diffuse and specular terms
    half3 diff = DisneyDiffuse(dot(normal, lightDir), albedo);
    // Use the alpha channel of albedo to choose between three specular terms
    half specSelect = albedo.a;
    half3 spec = 1;
    if (specSelect == 1)
    {
        spec = GGXSpecular(normal, viewDir, lightDir, worldPosition, lightPosition, roughness, specularColor, grazingAngle);
    }
    else if (specSelect == 0)
    {
        spec = RetroreflectiveSpecular(viewDir,normal, roughness,  grazingAngle);
    }
    else
    {
        spec = AnisotropicSpecular(viewDir, worldPosition, normal, lightPosition, roughness,  grazingAngle);
    }
    // Fresnel-Schlick approximation for grazing reflection based on angle and roughness
    half3 F0 = metalness;
    half3 FR = F0 + (1 - F0) * pow(1 - dot(normal, viewDir), roughness);
    // Roughness multiplier here increases the range of the blur
    half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflection, roughness * 4);
    // Cubemap is stored HDR- the multiplier is to compensate for gamma screens, and is not physically accurate. 
    half3 skyColor = DecodeHDR (skyData, unity_SpecCube0_HDR) * 0.05;            

    // Lighting model
    half3 combinedLight = (diff + spec) * (lightColor * fallOff);
    // Final BRDF   
    float3 combinedColor = ((albedo * combinedLight  * occlusion) + (skyColor * FR * metalness) + albedo * (UNITY_LIGHTMODEL_AMBIENT.rgb * 0.1));
    return half4(combinedColor, alpha);
}
