// LightingFastest.cginc

// Lambertian Diffuse Term (Disney)
float3 DisneyDiffuse(float nl, float3 color)
{
    float3 baseColor = color.rgb;

    // Lambert diffuse term
    float diffuse = max(0.0, nl);

    // Energy-conserving adjustment
    float3 adjustedDiffuse = diffuse * (1.0 + (color.rgb / 3.14));

    // Apply base color
    return adjustedDiffuse * baseColor;
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
    float F0 = lerp(0.04, 0.97, roughness);
    float F = F0 + (1 - F0) * pow(1 - dot(viewDir, reflect(lightDir, normalize(float3(0, 1, 0)))), 5);


    // Avoid division by zero by adding a small value
    float denominator = 4.0 * nv * nl + 0.001;

    // Multiply instead of dividing
    return (D * G * F) * rsqrt(denominator);
}

//accumulate light in a single step
float3 LightAccumulation(float3 normal, float3 viewDir, float3 albedo, float3 specularColor, float roughness,
                         float3 worldPosition, float3 lightPosition, float3 lightColor, float range, float intensity,
                         float lightType, float spotAngle)
{
    float3 lightDir;
    float attenuation = 1.0;
    if (lightType == 0.0) // directional light
    {
        lightDir = normalize(lightPosition);
    }
    else // point/spot light
    {
        float3 vertexToLightSource = lightPosition - worldPosition;
        half lightDst = dot(vertexToLightSource, vertexToLightSource);
        lightDir = normalize(vertexToLightSource);
        half normalizedDist = lightDst / pow(range,0.25); //range needs to be squared because the light distance is also squared -> cheaper computation
        half fallOff = saturate(1.0 / (1.0 + 25.0 * normalizedDist * normalizedDist) * saturate((1 - normalizedDist) * 5.0));
        //
        attenuation = fallOff; //spotAttenuation;
        //
        intensity *= attenuation;
    }

    float diff = DisneyDiffuse(dot(normal,lightDir), albedo);
    float spec = GGXSpecular(normal, viewDir, lightDir, roughness);
    
    return albedo * (diff + spec) * lightColor * intensity;
}
