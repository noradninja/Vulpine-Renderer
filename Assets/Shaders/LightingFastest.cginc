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
float4 LightAccumulation(float3 vertNormal, float3 normal, float3 viewDir, float4 albedo, float4 MOAR, float3 specularColor, float roughness,
                         float metalness, float3 worldPosition, float4 lightPosition, float3 lightColor, float range, float intensity,
                         float lightType, float spotAngle, float3 grazingAngle, float3 reflection, float cutOff, float shadow)
{
    half fallOff = 1.0;
    intensity *= 0.1; // compensate for inspector intensity range, should replace this with an approximation for lux and temp
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
    
   
    // Use the alpha channel of albedo to choose between four material types
    half materialSelection = albedo.a;
    half3 diff = 1;
    half3 spec = 1;
    if (materialSelection == 1) // Disney/GGX
    {
        diff = DisneyDiffuse(dot(normal, lightDir), albedo);
        spec = GGXSpecular(normal, viewDir, lightDir, worldPosition, lightPosition, lightColor, roughness, grazingAngle);
    }
    else if (materialSelection == 0) // Disney/retroreflective
    {
        diff = DisneyDiffuse(dot(normal, lightDir), albedo);
        spec = RetroreflectiveSpecular(viewDir,normal, roughness,  grazingAngle);
    }
    else if (materialSelection <=0.5 && materialSelection> 0 ) // Disney/Anisotropic
    {
        diff = DisneyDiffuse(dot(normal, lightDir), albedo);
        spec = AnisotropicSpecular(viewDir, worldPosition, normal, lightPosition, roughness,  grazingAngle);
    }
    else // Subsurface scattering/GGX
    {
        diff = SubsurfaceScatteringDiffuse(vertNormal, viewDir, lightDir, worldPosition, lightPosition, lightColor, albedo, roughness);
        spec = GGXSpecular(normal, viewDir, lightDir, worldPosition, lightPosition, lightColor, roughness, grazingAngle);
    }
    // Fresnel-Schlick approximation for grazing reflection based on angle and roughness
    half3 F0 = metalness;
    half3 FR = F0 + (1 - F0) * pow(1 - dot(normal, viewDir), roughness);
    // Roughness multiplier here increases the range of the blur
    half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflection, roughness * 8);
    // Cubemap is stored HDR- the multiplier is to compensate for gamma screens, and is not physically accurate. 
    half3 skyColor = DecodeHDR (skyData, unity_SpecCube0_HDR) * 0.05;            

    // Lighting model
    half3 combinedLight = (diff + spec) * (lightColor * shadow * fallOff * intensity);
    // Final BRDF   
    float3 combinedColor = ((albedo * combinedLight * occlusion) + (skyColor * FR * metalness) + (albedo * (UNITY_LIGHTMODEL_AMBIENT.rgb * 0.1)));
    clip( alpha - cutOff );
    return half4(combinedColor, alpha);
}
