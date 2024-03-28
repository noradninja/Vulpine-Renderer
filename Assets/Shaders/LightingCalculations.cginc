// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// LightingCalculations.cginc

#include <HLSLSupport.cginc>

/////////////////////DIFFUSE//////////////////////////////////////

// Disney
half3 DisneyDiffuse(float nl, float3 color)
{
    float3 baseColor = color.rgb;
    // Lambert diffuse term
    float diffuse = max(0.0, nl);
    // Energy-conserving adjustment
    float3 adjustedDiffuse = diffuse * ((color.rgb / 3.14159));
    // Apply base color
    return adjustedDiffuse * baseColor;
}

// Subsurface scattering with edge glow
half3 SubsurfaceScatteringDiffuse(float3 normal, float3 viewDir, float3 lightDir, float3 position, float3 lightPosition, float3 lightColor, float3 albedo, float roughness)
{
    float nl = max(0.0, dot(normal, lightDir));
    float nv = max(0.0, dot(normal, viewDir));
    // Subsurface scattering parameters
    float3 absorptionColor = albedo; // Adjust as needed
    float3 scatteringColor = lightColor; // Adjust as needed
    float scatteringCoeff = 0.1; // Adjust as needed
    // Calculate the distance the light travels through the material
    float3 h = normalize(viewDir + lightDir);
    half vh = pow(saturate(dot(nv, h)), 0.5);
 
    float3 sss = lerp(scatteringColor  * scatteringCoeff, absorptionColor, vh);
    
    return sss;
}



/////////////////////SPECULAR//////////////////////////////////////

// GGX
half3 GGXSpecular(float3 normal, float3 viewDir, float3 lightDir, float3 position, float3 lightPosition, float3 lightColor, float roughness, float3 grazingAngle)
{
    // Get dot products needed
    float3 h = normalize(viewDir + lightDir);
    float nh = max(0.0, dot(normal, h));
    float nv = max(0.0, dot(normal, viewDir));
    float nl = max(0.0, dot(normal, lightDir));
    float roughnessSq = roughness * roughness;
    // Absolute value of reflection intensity 
    float a = nh * nh * (roughnessSq - 1.0) + 1.0;
    // Combine the terms before division
    float invDenominator = 1.0 / (3.14 * a * a);
    // Normal distribution
    float D = roughnessSq * invDenominator;
   // Shadow sidedness
    float G1 = (2.0 * nh) * invDenominator;
    // Shadow distribution
    float G = min(1.0, min(G1, 2.0 * nl / nh));
    // Fresnel-Schlick approximation
    float3 F = grazingAngle;
    // Avoid division by zero by adding a small value
    float denominator = 4.0 * nv * nl + 0.001;
    // Multiply instead of dividing
    return (D * G * F) * rsqrt(denominator) * lightColor;
}

// Anisotropic
half3 AnisotropicSpecular(float3 viewDir, float3 position, float3 normal, float3 lightPosition, float roughness, float3 grazingAngle)
{
    // Compute light direction
    float3 lightDir = normalize(lightPosition - position);
    // Compute half vector
    float3 halfVec = normalize(viewDir - lightDir);
    // Add a small offset to roughness to prevent division by zero
    roughness = roughness + 0.001;
    // Beckmann distribution term
    float dotNH = dot(normal, halfVec);
    float exponent = (dotNH * dotNH) / (roughness) + ((1.0 - dotNH * dotNH) / (roughness));
    float D = exp(-exponent * 1-roughness) / (1  * roughness * pow(dotNH, 2));
    // Fresnel-Schlick approximation
    float3 F = grazingAngle;
    // Anisotropic reflection model
    return D * F;
}

// Retroreflective
half3 RetroreflectiveSpecular(float3 viewDir, float3 normal, float roughness, float grazingAngle)
{
    // Calculate the reflection direction
    float3 reflectionDir = reflect(-viewDir, normal);

    // Calculate the angle between the reflection direction and the view direction
    float angle = grazingAngle;

    // Retroreflective specular model (simple cosine lobe)
    half3 retroReflection = max(0.1, dot(viewDir, reflectionDir));

    // Simulate refraction scattering by adding the color of the reflectionDir based on the grazing angle
    half3 refractionScattering = lerp(retroReflection, normalize(normal) + retroReflection, angle);

    // Combine retroreflection and refraction scattering
    return retroReflection + (refractionScattering * angle * roughness);
}

/////////////////////UTILITIES//////////////////////////////////////

// Unpack a normalmap and apply a scale factor
half3 ExtractNormal (half4 packednormal, half bumpScale) {
    half3 normal;
    normal.xy = (packednormal.wy * 2 - 1);
    normal.xy *= bumpScale;
    normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
    return normal;
}
// Unpack two normals from a single image- .rg = normalA.xy, .ba = normalB.xy, both .z are analytically derived
half3 ExtractPackedNormals (half4 packednormal, half bumpScale) {
    half3 normal;
    normal.xy = (packednormal.wy * 2 - 1);//this will change, need to look at dxtnm format
    normal.xy *= bumpScale;
    normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
    return normal;
}
//combine two normal maps together using whiteout blending for contrast
half3 BlendTwoNormals (half3 n1, half3 n2) {
    return normalize(half3(n1.xy + n2.xy, n1.z * n2.z));
}