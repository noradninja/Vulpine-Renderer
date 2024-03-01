// LightingFastest.cginc

#include "LightingCalculations.cginc"
float3 lightDir;
float attenuation;

float3 LightAccumulation(float3 normal, float3 viewDir, float3 albedo, float3 specularColor, float roughness,
                         float3 worldPosition, float3 lightPosition, float3 lightColor, float range, float intensity,
                         float lightType, float spotAngle)
{
    if (lightType == 0.0) // directional light
    {
        lightDir = normalize(lightPosition);
    }
    else // point/spot light
    {
        float3 vertexToLightSource = lightPosition - worldPosition;
        half lightDst = dot(vertexToLightSource, vertexToLightSource);
        lightDir = normalize(vertexToLightSource);
        half normalizedDist = lightDst / pow(range,0.75);
        half fallOff = saturate(1.0 / (1.0 + 25.0 * normalizedDist * normalizedDist) * saturate((1 - normalizedDist) * 5.0));
                
        attenuation = fallOff;
        intensity *= attenuation;
    }
    //calculate the diffuse and specular terms
    float diff = DisneyDiffuse(dot(normal,lightDir), albedo);
    float spec = GGXSpecular(normal, viewDir, lightDir, worldPosition, lightPosition, roughness, specularColor);
    //return the beauty pass
    return (albedo + .5) * (diff + spec) * lightColor * intensity;
}
