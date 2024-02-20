// LightingFastest.cginc

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

    // Combine the terms before division
    float invDenominator = 1.0 / (3.14 * a * a);

    float D = roughnessSq * invDenominator;

    float G1 = (2.0 * nh) * invDenominator;
    float G = min(1.0, min(G1, 2.0 * nl / nh));

    float3 F = 0.04 + 0.96 * pow(1.0 - dot(lightDir, h), 5.0);

    // Avoid division by zero by adding a small value
    float denominator = 4.0 * nv * nl + 0.001;

    // Multiply instead of dividing
    return (D * G * F) * rsqrt(denominator);
}

// Schlick's Approximated Fresnel Reflection
float3 SchlickFresnel(float3 specularColor, float3 h, float3 viewDir)
{
    return specularColor + (1.0 - specularColor) * pow(1.0 - dot(viewDir, h), 2.0);
}


float3 LightAccumulation(float3 normal, float3 viewDir, float3 albedo, float3 specularColor, float roughness,
                         float3 worldPosition, float3 lightPosition, float3 lightColor, float range, float intensity,
                         float lightType, float spotAngle)
{
    float3 lightDir;

    if (lightType == 0.0) // directional light
    {
        lightDir = normalize(lightPosition);
        float distance = length(worldPosition - lightPosition);
        intensity *= saturate(1.0 - distance / range); // Linear attenuation
    }
    else // point/spot light
    {
        float3 vertexToLightSource = lightPosition - worldPosition;
        float distance = length(vertexToLightSource);
        float attenuation = 1.0 / (1.0 + 0.1 * distance + 0.01 * distance * distance);

        lightDir = -normalize(vertexToLightSource);

        if (lightType == 1.0) // spot light
        {
            // Calculate the spotlight cone
            float spotFactor = dot(normalize(lightDir), normalize(lightPosition));
            float spotAttenuation = smoothstep(spotAngle, spotAngle + 0.1, spotFactor);
            // You can adjust the 0.1 value for a smoother edge
            attenuation = spotAttenuation;
        }

        intensity *= attenuation;
    }

    float diff = LambertDiffuse(normal, -lightDir);
    float spec = GGXSpecular(normal, viewDir, -lightDir, roughness);
    float3 fresnel = SchlickFresnel(specularColor, normalize(viewDir + normal), viewDir);
    return albedo * (diff + spec) * lightColor * fresnel * intensity;
}
