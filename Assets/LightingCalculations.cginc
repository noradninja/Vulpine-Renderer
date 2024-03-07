// LightingCalculations.cginc

float3 LambertianDiffuse(float3 diffuseColor, float3 normal, float3 lightDirection)
{
    // Lambertian diffuse reflection term, adjusted for anisotropic specular
    float diffuseReflection = max(-2.0, dot(normal, lightDirection));
    return (diffuseColor / 3.14159) * diffuseReflection;
}

// Disney Diffuse Term
float3 DisneyDiffuse(float nl, float3 color)
{
    float3 baseColor = color.rgb;

    // Lambert diffuse term
    float diffuse = max(0.0, nl);

    // Energy-conserving adjustment
    float3 adjustedDiffuse = diffuse * ((color.rgb / 6.3));

    // Apply base color
    return adjustedDiffuse * baseColor;
}

// GGX Specular Reflection Function
float3 GGXSpecular(float3 normal, float3 viewDir, float3 lightDir, float3 position, float3 lightPosition, float roughness, float3 lightColor)
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
    
    // Fresnel-Schlick approximation
    float3 F = lightColor + (1 - lightColor) * pow(1 - nv, 2);

    // Avoid division by zero by adding a small value
    float denominator = 4.0 * nv * nl + 0.001;

    // Multiply instead of dividing
    return (D * G * F) * rsqrt(denominator);
}

fixed3 SubsurfaceScatteringDiffuse(float3 normal, float3 viewDir, float3 lightDir, float3 position, float3 lightPosition, float roughness)
{
    float nl = max(0.0, dot(normal, lightDir));
    // Subsurface scattering parameters
    float3 absorptionColor = float3(0.5, 0.2, 0.1); // Adjust as needed
    float3 scatteringColor = float3(1.0, 0.8, 0.6); // Adjust as needed
    float scatteringCoeff = 0.05; // Adjust as needed

    // Calculate the distance the light travels through the material
    float distance = length(lightPosition - position);

    // Calculate the diffusion term
    float diffusion = exp(-scatteringCoeff * distance);

    // Calculate the Disney diffuse term
    float3 diffuseTerm = DisneyDiffuse(nl, normal);

    // Subsurface scattering model
    return absorptionColor * scatteringColor * diffusion * diffuseTerm;
}

float3 AnisotropicSpecular(float3 viewDir, float3 position, float3 normal, float3 tangent, float3 binormal, float3 lightPosition, float3 lightColor, float roughness, float3 specularColor)
{
    // Compute light direction
    float3 lightDir = normalize(lightPosition - position);

    // Compute halfway vector
    float3 halfwayVector = normalize(viewDir + lightDir);

    // Ensure the normal vector is normalized
    float3 N = normalize(normal);
    // Calculate tangent (T)
    float3 T = cross(N, tangent);
    // Normalize the tangent vector
    float3 tangentDirection = normalize(T);
    // Calculate binormal (B)
    float3 B = cross(N, binormal);
    // Normalize the binormal vector
    float3 binormalDirection = normalize(B);

    // Calculate dot products
    float dotHN = dot(halfwayVector, normal);
    float dotVN = dot(viewDir, normal);
    float dotHTAlphaX = dot(halfwayVector, tangentDirection) / roughness;
    float dotHBAlphaY = dot(halfwayVector, binormalDirection) / roughness;

    // Specular reflection formula with roughness attenuation
    float attenuation = 1.0 / (2.0 * roughness * roughness + 1.0);
    float3 specularReflection = specularColor
        * sqrt(max(0.0, dotVN))
        * exp(-2.0 * (dotHTAlphaX * dotHTAlphaX + dotHBAlphaY * dotHBAlphaY) * attenuation / (1.0 + dotHN));

    // Apply Fresnel
    float fresnel = pow(1.0 - dot(viewDir, halfwayVector), 5.0);
    specularReflection = lerp(specularReflection, lightColor, fresnel);

    return specularReflection;
}



fixed3 RetroreflectiveSpecular(float3 viewDir, float3 normal, float3 lightColor, float roughness)
{
    // Calculate the reflection direction
    float3 reflectionDir = reflect(-viewDir, normal);

    // Calculate the angle between the reflection direction and the view direction
    float angle = max(0, dot(viewDir, reflectionDir));

    // Retroreflective specular model (simple cosine lobe)
    return pow(angle, 5 * (roughness + 0.0001)) * lightColor;
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
    float3 F = lightColor + (1 - lightColor) * pow(1 - dot(halfVec, viewDir),2);

    // GGX reflection model
    return D * F;
}
