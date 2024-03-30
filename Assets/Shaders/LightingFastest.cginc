#include <UnityCG.cginc>
#include "LightingCalculations.cginc"

//initialize local varyings 
half3 lightDir;
half attenuation;
half fallOff = 1.0;
// lighting equation loop for one light, yes this is a lot of inputs, no we don't use them all yet, but I don't want to have to keep extending is
half4 LightAccumulation(half3 vertNormal, half3 normal, half3 viewDir, half4 albedo, half4 MOAR, float3 specularColor, half roughness,
                         half metalness, half3 worldPosition, half4 lightPosition, float3 lightColor, half range, half intensity,
                         half lightType, half spotAngle, half3 grazingAngle, half3 reflection, half cutOff, half shadow)
{
    intensity *= 1; // compensate for inspector intensity range, should replace this with an approximation for lux and temp
    if (lightType < 0.5) // directional light
    {
        //calc direction
        lightDir = normalize(lightPosition);
    }
    else // point/spot light
    {
        //get the vector from the surface to the light
        half3 vertexToLightSource = lightPosition - worldPosition;
        //calc distance, direction, and normalized distance
        half lightDst = dot(vertexToLightSource, vertexToLightSource);
        lightDir = normalize(vertexToLightSource);
        half normalizedDist = lightDst / range * range;
        //calc falloff/attenuation using normalized distance from light to surface
        fallOff = saturate(1.0 / (1.0 + 25.0 * normalizedDist * normalizedDist) * saturate((1 - normalizedDist) * 5.0));
    }
    //Decompose MOAR into channel values
    metalness = MOAR.r * metalness;
    half occlusion = MOAR.g;
    half alpha = MOAR.b;
    roughness = MOAR.a * roughness;
    // Use the alpha channel of albedo to choose between four material types
    half materialSelection = albedo.a;
    //initialize diffuse and spec terms
    half3 diff = 1;
    half3 spec = 1;
    //spin through the options for material types stored in albedo alpha
    if (materialSelection == 1) // Disney/GGX if white
    {
        diff = DisneyDiffuse(dot(normal, lightDir), albedo);
        spec = GGXSpecular(normal, viewDir, lightDir, worldPosition, lightPosition, lightColor, roughness, grazingAngle);
    }
    else if (materialSelection == 0) // Disney/retroreflective if black
    {
        diff = DisneyDiffuse(dot(normal, lightDir), albedo);
        spec = RetroreflectiveSpecular(viewDir,normal, roughness,  grazingAngle);
    }
    else if (materialSelection <=0.5 && materialSelection> 0 ) // Disney/Anisotropic if 0.5 grey
    {
        diff = DisneyDiffuse(dot(normal, lightDir), albedo);
        spec = AnisotropicSpecular(viewDir, worldPosition, normal, lightPosition, roughness,  grazingAngle);
    }
    else // Subsurface scattering/GGX for everything else
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
    float3 combinedLight = (diff + spec) * (lightColor * shadow * fallOff * intensity);
    // Final BRDF = COLOR & LIGHT + FRESNEL REFLECTION & METALNESS + AMBIENT LIGHT & ALBEDO MIX 
    half3 combinedColor = ((albedo * combinedLight * occlusion) + (skyColor * FR * metalness) + (albedo * (UNITY_LIGHTMODEL_AMBIENT.rgb * 0.1)));
    clip( alpha - cutOff );
    return half4(combinedColor, alpha);
}
