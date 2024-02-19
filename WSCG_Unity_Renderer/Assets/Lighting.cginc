// Lighting.cginc

#include <UnityCG.cginc>
// Lambertian Diffuse Function
float LambertDiffuse(float3 normal, float3 lightDir)
{
    return max(0.0, dot(normal, lightDir));
}

// GGX Specular Reflection Function
float GGXSpecular(float3 normal, float3 viewDir, float3 lightDir, float roughness)
{
    float3 h = normalize(viewDir + lightDir);
    float nh = max(0.0, dot(normal, h));
    float nv = max(0.0, dot(normal, viewDir));
    float nl = max(0.0, dot(normal, lightDir));

    float roughnessSq = roughness * roughness;
    float a = nh * nh * (roughnessSq - 1.0) + 1.0;
    float D = roughnessSq / (UNITY_PI * a * a);

    float G1 = (2.0 * nh) / (nh + sqrt(roughnessSq + (1.0 - roughnessSq) * nh * nh));
    float G = min(1.0, min(G1, 2.0 * nl / nh));

    float3 F = 0.04 + 0.96 * pow(1.0 - dot(lightDir, h), 5.0);

    return (D * G * F) / (4.0 * nv * nl + 0.001); // Added small value to prevent division by zero
}

// Schlick's Approximated Fresnel Reflection
float3 SchlickFresnel(float3 specularColor, float3 h, float3 viewDir)
{
    return specularColor + (1.0 - specularColor) * pow(1.0 - dot(viewDir, h), 5.0);
}

// Light Accumulation Function
float3 LightAccumulation(float3 normal, float3 viewDir, float3 albedo, float3 specularColor, float roughness, float3 lightPosition, float3 lightColor, float3 lightDirection)
{
    float3 lightDir = normalize(lightDirection);
    float diff = LambertDiffuse(normal, -lightDir);
    float spec = GGXSpecular(normal, viewDir, -lightDir, roughness);
    float3 fresnel = SchlickFresnel(specularColor, normalize(viewDir + lightDir), viewDir);
    
    return albedo * lightColor * (diff + spec) * fresnel;
}
