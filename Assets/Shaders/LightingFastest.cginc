#include <UnityCG.cginc>
#include <UnityLightingCommon.cginc>
#include "LightingCalculations.cginc"

//local varyings
float3 lightDir;
float attenuation;

float4 LightAccumulation(float3 vertNormal, float3 normal, float3 viewDir, float4 albedo, float4 MOAR, float3 specularColor, float roughness,
                         float metalness, float3 worldPosition, float3 lightPosition, float3 lightColor, float range, float intensity,
                         float lightType, float spotAngle, float3 grazingAngle, float3 reflection, float cutOff, float shadow, sampler2D cookieTexture, float isSpecular, float isReflective)
{
    intensity *= 0.02; // compensate for inspector intensity range, should replace this with an approximation for lux and temp
    // Calculate light direction and distance
    float3 lightDir = lightPosition.xyz - worldPosition;
    float distance = length(lightDir);
    lightDir /= distance; // Normalize light direction
    
    if (lightType == 0.0) // directional light
    {
        lightDir = normalize(lightPosition);
    }
    else if (lightType == 1.0) // point light
    {
        float3 vertexToLightSource = lightPosition - worldPosition;
        float lightDst = dot(vertexToLightSource, vertexToLightSource);
        lightDir = normalize(vertexToLightSource);
        float normalizedDist = lightDst / (range * range);
        attenuation = saturate(1.0 / (1.0 + 10.0 * normalizedDist * normalizedDist) * saturate((1 - normalizedDist) * 10.0));
    }
    else if (lightType == 2.0) // spotlight
    {
        // Calculate the direction vector for this light
        lightDir = normalize(lightPosition - worldPosition);
        // Calculate the vector for the axis of rotation for theis spotlight
        float3 spotAxis = normalize(lightPosition);
        // Calculate the vector from light to this point on the surface
        float3 lightToFragment = lightPosition - worldPosition;
        // Project that vector onto the spotlight direction
        float projDistance = dot(lightToFragment, lightDir);
        // Scale the projected distance to [0, 1] range for the horizontal coordinate
        float U = projDistance / range;
        // Calculate the vertical coordinate using the cosine of the angle between the surface normal relative to the light 'camera' and it's direction
        float V = dot(normalize(lightToFragment), lightDir);
        // These coordinates represent a projection along the Z axis of the light,
        // where u is relative to the distance from the surface and light range, and where v is relative to the surface angle and light direction
        float2 uv = float2(U,V);
        // Sample the light cookie texture //TODO//
        float4 cookieSample = tex2D(cookieTexture, uv);
        // Calculate spotlight attenuation with cookie
        attenuation = CalculateSpotlightFalloff(lightDir, spotAxis, spotAngle);
        // Apply cookie attenuation to spotlight intensity
        // attenuation *= cookieAttenuation; //TODO//
    }
    // Initialize lighting term values 
    half3 diff;
    half3 spec = 1;
    //Decompose MOAR texture into material property values
    metalness *= MOAR.r;
    half occlusion = MOAR.g;
    half alpha = MOAR.b;
    roughness *= MOAR.a;
    // Use the alpha channel of albedo to choose between four material types
    half specTermSelection = albedo.a;
    // Spin values to determine output terms
    if (specTermSelection == 1) // Disney/Smith-Correlated GGX
    {
        diff = DisneyDiffuse(dot(normal, lightDir), albedo, lightColor);
        if (isSpecular > 0)
            spec = GGXSpecular(normal, viewDir, lightDir, worldPosition, lightPosition, lightColor, roughness, grazingAngle);
    }
    else if (specTermSelection == 0) // Disney/retro-reflective
    {
        diff = DisneyDiffuse(dot(normal, lightDir), albedo, lightColor);
        if (isSpecular > 0)
            spec = RetroreflectiveSpecular(viewDir,normal, roughness,  grazingAngle);
    }
    else if (specTermSelection <=0.5 && specTermSelection > 0 ) // Disney/Anisotropic
    {
        diff = DisneyDiffuse(dot(normal, lightDir), albedo, lightColor);
        if (isSpecular > 0)
            spec = AnisotropicSpecular(viewDir, worldPosition, normal, lightPosition, roughness,  grazingAngle);
    }
    else // Subsurface scattering/Smith-Correlated GGX
    {
        diff = SubsurfaceScatteringDiffuse(normal, -viewDir, lightDir, worldPosition, lightPosition, lightColor, albedo, roughness);
        if (isSpecular > 0)
            spec = GGXSpecular(normal, viewDir, lightDir, worldPosition, lightPosition, lightColor, roughness, grazingAngle);
    }
    // Fresnel-Schlick approximation for grazing environmental reflection based on angle and surface roughness
    half3 F0 = metalness;
    half3 FR = F0 + (1 - F0) * pow(1 - dot(normal, viewDir), roughness);
    // Roughness multiplier here increases the range of the blur
    half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflection, roughness * 8);
    half3 skyColor = UNITY_LIGHTMODEL_AMBIENT.rgb; //set input value for non-glossy reflection
    // sample the probe instead if we have glossy reflection enabled
    if (isReflective) 
        // Cubemap is stored in HDR- the multiplier is to compensate for gamma screens, and is not physically accurate. 
        skyColor = DecodeHDR (skyData, unity_SpecCube0_HDR) * 0.05;            

    // Lighting model
    float adjustedShadow = shadow * half4(255 - lightColor.r, 255 - lightColor.g, 255 - lightColor.b, 1) * 0.0128;
    half3 combinedLight = (diff * spec) * ((lightColor  * intensity) + adjustedShadow);
    // Final BRDF   
    float3 combinedColor = ((combinedLight * occlusion) + (skyColor * FR * metalness) + (albedo * (UNITY_LIGHTMODEL_AMBIENT.rgb) * 0.22));
    clip( alpha - cutOff );
    return float4(combinedColor, alpha);
}

