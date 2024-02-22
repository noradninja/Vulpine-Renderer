// LightingCalculations.cginc

#include "UnityCG.cginc"

struct LightData
{
    float3 position;
    float3 color;
    float2 intensityRange;
};

fixed3 LambertianDiffuse(float3 normal, float3 viewDir, float3 position, float3 lightPosition)
{
    // Lambertian diffuse model
    return max(0, dot(normalize(lightPosition - position), normal));
}

fixed3 SubsurfaceScatteringDiffuse(float3 normal, float3 viewDir, float3 position, float3 lightPosition)
{
    // Subsurface scattering parameters
    float3 absorptionColor = float3(0.5, 0.2, 0.1); // Adjust as needed
    float3 scatteringColor = float3(1.0, 0.8, 0.6); // Adjust as needed
    float scatteringCoeff = 0.05; // Adjust as needed

    // Calculate the distance the light travels through the material
    float distance = length(lightPosition - position);

    // Calculate the diffusion term
    float diffusion = exp(-scatteringCoeff * distance);

    // Calculate the Lambertian diffuse term
    float3 lambertianDiffuse = max(0, dot(normalize(lightPosition - position), normal));

    // Subsurface scattering model
    return absorptionColor * scatteringColor * diffusion * lambertianDiffuse;
}

fixed3 AnisotropicSpecular(float3 viewDir, float3 position, float3 lightPosition, float3 lightColor)
{
    // Beckmann distribution parameters
    float roughnessX = 0.2; // Adjust as needed
    float roughnessY = 0.5; // Adjust as needed

    // Half vector calculation
    float3 halfVec = normalize(viewDir + normalize(lightPosition - position));

    // Beckmann distribution term
    float exponent = (halfVec.x * halfVec.x) / (roughnessX * roughnessX) + (halfVec.y * halfVec.y) / (roughnessY * roughnessY);
    float D = exp(-exponent) / (UNITY_PI * roughnessX * roughnessY * roughnessX * roughnessY * pow(halfVec.z, 4));

    // Fresnel-Schlick approximation
    float3 F = lightColor + (1 - lightColor) * pow(1 - dot(halfVec, viewDir), 5);

    // Anisotropic reflection model
    return D * F;
}


fixed3 RetroreflectiveSpecular(float3 viewDir, float3 normal, float3 lightColor)
{
    // Calculate the reflection direction
    float3 reflectionDir = reflect(-viewDir, normal);

    // Calculate the angle between the reflection direction and the view direction
    float angle = max(0, dot(viewDir, reflectionDir));

    // Retroreflective specular model (simple cosine lobe)
    return pow(angle, 5) * lightColor;
}

fixed3 GGXSpecular(float3 viewDir, float3 normal, float3 lightColor)
{
    // GGX distribution parameters
    float roughness = 0.2; // Adjust as needed

    // Half vector calculation
    float3 halfVec = normalize(viewDir + _WorldSpaceCameraPos);

    // GGX distribution term
    float NdotH = max(0, dot(normal, halfVec));
    float alphaSquared = roughness * roughness;
    float D = alphaSquared / (UNITY_PI * pow(NdotH * NdotH * (alphaSquared - 1) + 1, 2));

    // Fresnel-Schlick approximation
    float3 F = lightColor + (1 - lightColor) * pow(1 - dot(halfVec, viewDir), 5);

    // GGX reflection model
    return D * F;
}
