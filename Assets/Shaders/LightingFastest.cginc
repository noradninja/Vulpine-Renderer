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
// Get indirect lighting 
UnityIndirect CreateIndirectLight (float3 normal, float3 viewDir) {
    UnityIndirect indirectLight;
    indirectLight.diffuse = UNITY_LIGHTMODEL_AMBIENT.rgb;    
    indirectLight.diffuse += ShadeSH9(float4(normal, 1));
    float3 reflectionDir = reflect(-viewDir, normal);
    float4 envSample = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, reflectionDir);
    indirectLight.specular = DecodeHDR(envSample, unity_SpecCube0_HDR);

    return indirectLight;
}
// Loop for one light
float3 LightAccumulation(float3 normal, float3 viewDir, float3 albedo, float3 specularColor, float roughness,
                         float3 worldPosition, float3 lightPosition, float3 lightColor, float range, float intensity,
                         float lightType, float spotAngle, float3 grazingAngle, float3 reflection, float3 F)
{
    
    UnityIndirect indirectLight = CreateIndirectLight(normal, viewDir);
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

    // Calculate the diffuse and specular terms
    half3 diff = DisneyDiffuse(dot(normal, lightDir), albedo);
    half3 spec =//AnisotropicSpecular(viewDir, worldPosition, normal, lightPosition, roughness,  F);
                //RetroreflectiveSpecular(viewDir,normal, roughness,  F);
                GGXSpecular(normal, viewDir, lightDir, worldPosition, lightPosition, roughness, specularColor, F);

    // Fresnel-Schlick approximation for grazing reflection based on angle and roughness
    half3 F0 = specularColor;
    half3 FR = F0 + (1 - F0) * grazingAngle;
    // Roughness multiplier here increases the range of the blur
    half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflection, roughness * 5);
    // Cubemap is stored HDR- the multiplier is to compensate for gamma screens, and is not physically accurate. 
    half3 skyColor = DecodeHDR (skyData, unity_SpecCube0_HDR) * 0.175;            

    // Lighting model
    diff *= indirectLight.diffuse;
    spec *= indirectLight.specular;
    half3 combinedLight = (diff + spec) * lightColor * fallOff;
    // Final BRDF   
    float3 combinedColor = albedo * combinedLight + (skyColor * FR);
    return combinedColor;
}
