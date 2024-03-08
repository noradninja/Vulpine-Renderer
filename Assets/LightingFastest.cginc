#include <UnityCG.cginc>
#include <UnityLightingCommon.cginc>
#include "LightingCalculations.cginc"


float3 lightDir;
float attenuation;

// Decode RGBM encoded HDR values from a cubemap
float3 DecodeHDR(in float4 rgbm)
{
    return rgbm.rgb * rgbm.a * 16.0;
}
UnityIndirect CreateIndirectLight (float3 normal, float3 viewDir) {
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;

    indirectLight.diffuse += ShadeSH9(float4(normal, 1));
    float3 reflectionDir = reflect(-viewDir, normal);
    float4 envSample = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, reflectionDir);
    indirectLight.specular = DecodeHDR(envSample, unity_SpecCube0_HDR);

    return indirectLight;
}
float3 LightAccumulation(float3 normal, float3 viewDir, float3 albedo, float3 specularColor, float roughness,
                         float3 worldPosition, float3 lightPosition, float3 lightColor, float range, float intensity,
                         float lightType, float spotAngle)
{
    
    
    CreateIndirectLight(normal, viewDir);
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
    float diff = DisneyDiffuse(dot(normal, lightDir), albedo);
    float3 spec =//AnisotropicSpecular(viewDir, worldPosition, normal, lightPosition, lightColor, roughness);
                //RetroreflectiveSpecular(viewDir,normal,lightColor, roughness);
                GGXSpecular(normal, viewDir, lightDir, worldPosition, lightPosition, roughness, specularColor);

    // Fresnel-Schlick approximation for reflection based on the roughness
    float3 F0 = specularColor;
    float3 F = F0 + (1 - F0) * pow(1 - max(0.0, dot(normal, viewDir)), 10);
    half3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPosition)); //Direction of ray from the camera towards the object surface
    half3 reflection = reflect(-worldViewDir, UnityObjectToWorldNormal(normal)); // Direction of ray after hitting the surface of object
    half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflection, roughness * 5);
    half3 skyColor = DecodeHDR (skyData, unity_SpecCube0_HDR); // This is done becasue the cubemap is stored HDR            
    float3 combinedLight = (diff + spec);
    
    // Apply environment lighting using Unity 2018 built-in ambient lighting values and skybox light
    float3 ambientLight = UNITY_LIGHTMODEL_AMBIENT.rgb;
    float3 combinedColor = albedo * ambientLight * (combinedLight + skyColor * F) * fallOff;

    return combinedColor;
}
