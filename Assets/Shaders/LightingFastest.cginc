#include <UnityCG.cginc>
#include <UnityLightingCommon.cginc>
#include "LightingCalculations.cginc"

//local varyings
float3 lightDir;
float attenuation;

float4 LightAccumulation(float3 vertNormal, float3 normal, float3 viewDir, float4 albedo, float4 MOAR, float3 specularColor, float roughness,
                         float metalness, float3 worldPosition, float3 lightPosition, float3 lightColor, float range, float intensity,
                         float lightType, float spotAngle, float3 grazingAngle, float3 reflection, float cutOff, float shadow, sampler2D cookieTexture)
{
    half fallOff = 1.0;
    intensity *= 0.88; // compensate for inspector intensity range, should replace this with an approximation for lux and temp
    // Calculate light direction and distance
    float3 lightDir = lightPosition.xyz - worldPosition;
    float distance = length(lightDir);
    lightDir /= distance; // Normalize light direction
    
    if (lightType == 0.0) // directional light
    {
        lightDir = normalize(lightPosition);
    }
    else if (lightType == 3.0) // point light
    {
        float3 vertexToLightSource = lightPosition - worldPosition;
        float lightDst = dot(vertexToLightSource, vertexToLightSource);
        lightDir = normalize(vertexToLightSource);
        float normalizedDist = lightDst / (range * range);
        attenuation = saturate(1.0 / (1.0 + 10.0 * normalizedDist * normalizedDist) * saturate((1 - normalizedDist) * 10.0));
    }
    else if (lightType == 2.0) // spotlight
    {
        float3 lightDir = normalize(lightPosition - worldPosition);
        float3 spotAxis = normalize(lightPosition); // Adjust if needed based on how your spotlights are oriented
        // Sample cookie texture
        // Calculate the vector from the fragment to the light position
        float3 lightToFragment = lightPosition - worldPosition;

        // Project this vector onto the spotlight direction
        float projDistance = dot(lightToFragment, lightDir);

        // Scale the projected distance to [0, 1] range for the horizontal coordinate
        float u = projDistance / range;

        // Calculate the vertical coordinate using the cosine of the angle between normal and spotlight direction
        float v = dot(normalize(lightToFragment), lightDir);

        float2 uv = float2(u,v);
        // Sample the light cookie texture
        float4 cookieSample = tex2D(cookieTexture, uv);

        // Calculate spotlight attenuation with cookie
        float falloff = CalculateSpotlightFalloff(lightDir, spotAxis, spotAngle);
        // float cookieAttenuation = cookieSample * falloff; // Adjust if needed
        //
        // // Apply cookie attenuation to spotlight intensity
        // attenuation = cookieAttenuation;
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
        diff = DisneyDiffuse(dot(normal, lightDir), albedo, lightColor);
        spec = GGXSpecular(normal, viewDir, lightDir, worldPosition, lightPosition, lightColor, roughness, grazingAngle);
    }
    else if (materialSelection == 0) // Disney/retroreflective
    {
        diff = DisneyDiffuse(dot(normal, lightDir), albedo, lightColor);
        spec = RetroreflectiveSpecular(viewDir,normal, roughness,  grazingAngle);
    }
    else if (materialSelection <=0.5 && materialSelection> 0 ) // Disney/Anisotropic
    {
        diff = DisneyDiffuse(dot(normal, lightDir), albedo, lightColor);
        spec = AnisotropicSpecular(viewDir, worldPosition, normal, lightPosition, roughness,  grazingAngle);
    }
    else // Subsurface scattering/GGX
    {
        diff = SubsurfaceScatteringDiffuse(normal, -viewDir, lightDir, worldPosition, lightPosition, lightColor, albedo, roughness);
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
    float adjustedShadow = shadow * 4;
    half3 combinedLight = (diff * spec) * ((lightColor  * intensity) + adjustedShadow);
    // Final BRDF   
    float3 combinedColor = ((combinedLight * occlusion) + (skyColor * FR * metalness) + (albedo * (UNITY_LIGHTMODEL_AMBIENT.rgb)* 0.22));
    clip( alpha - cutOff );
    return float4(combinedColor, alpha);
}

