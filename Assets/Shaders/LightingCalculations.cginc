//this contains all the lighting term functions, as well as helper functions for common shader ops

/////////////////////DIFFUSE//////////////////////////////////////

// Disney
half3 DisneyDiffuse(half nl, half3 color)
{
    half3 baseColor = color.rgb;
    // Lambert diffuse term
    half diffuse = max(0.0, nl);
    // Energy-conserving adjustment
    half3 adjustedDiffuse = diffuse * ((color.rgb / 3.14159));
    // Apply base color
    return adjustedDiffuse * baseColor;
}
// Subsurface scattering with edge glow- this is still in progress and should not be used quite yet
half3 SubsurfaceScatteringDiffuse(half3 normal, half3 viewDir, half3 lightDir, half3 position, half3 lightPosition, half3 lightColor, half3 albedo, half roughness)
{
    half nl = max(0.0, dot(normal, lightDir));
    half nv = max(0.0, dot(normal, viewDir));
    // Subsurface scattering parameters
    half3 absorptionColor = albedo; // Adjust as needed
    half3 scatteringColor = lightColor; // Adjust as needed
    half scatteringCoeff = 0.1; // Adjust as needed
    // Calculate the distance the light travels through the material
    half3 h = normalize(viewDir + lightDir);
    half vh = pow(saturate(dot(nv, h)), 0.5);
    half3 sss = lerp(scatteringColor  * scatteringCoeff, absorptionColor, vh);
    return sss;
}
/////////////////////SPECULAR//////////////////////////////////////

// GGX
half3 GGXSpecular(half3 normal, half3 viewDir, half3 lightDir, half3 position, half3 lightPosition, half3 lightColor, half roughness, half3 grazingAngle)
{
    // Get dot products needed
    half3 h = normalize(viewDir + lightDir);
    half nh = max(0.0, dot(normal, h));
    half nv = max(0.0, dot(normal, viewDir));
    half nl = max(0.0, dot(normal, lightDir));
    half roughnessSq = roughness * roughness;
    // Absolute value of reflection intensity 
    half a = nh * nh * (roughnessSq - 1.0) + 1.0;
    // Combine the terms before division
    half invDenominator = 1.0 / (3.14 * a * a);
    // Normal distribution
    half D = roughnessSq * invDenominator;
   // Shadow sidedness
    half G1 = (2.0 * nh) * invDenominator;
    // Shadow distribution
    half G = min(1.0, min(G1, 2.0 * nl / nh));
    // Fresnel-Schlick approximation
    half3 F = grazingAngle;
    // Avoid division by zero by adding a small value
    half denominator = 4.0 * nv * nl + 0.001;
    // Multiply instead of dividing
    return (D * G * F) * rsqrt(denominator) * lightColor;
}
// Anisotropic
half3 AnisotropicSpecular(half3 viewDir, half3 position, half3 normal, half3 lightPosition, half roughness, half3 grazingAngle)
{
    // Compute light direction
    half3 lightDir = normalize(lightPosition - position);
    // Compute half vector
    half3 halfVec = normalize(viewDir - lightDir);
    // Add a small offset to roughness to prevent division by zero
    roughness = roughness + 0.001;
    // Beckmann distribution term
    half dotNH = dot(normal, halfVec);
    half exponent = (dotNH * dotNH) / (roughness) + ((1.0 - dotNH * dotNH) / (roughness));
    half D = exp(-exponent * 1-roughness) / (1  * roughness * pow(dotNH, 2));
    // Fresnel-Schlick approximation
    half3 F = grazingAngle;
    // Anisotropic reflection model
    return D * F;
}
// Retroreflective
half3 RetroreflectiveSpecular(half3 viewDir, half3 normal, half roughness, half grazingAngle)
{
    // Calculate the reflection direction
    half3 reflectionDir = reflect(-viewDir, normal);
    // Calculate the angle between the reflection direction and the view direction
    half angle = grazingAngle;
    // Retroreflective specular model (simple cosine lobe)
    half3 retroReflection = max(0.1, dot(viewDir, reflectionDir));
    // Simulate refraction scattering by adding the color of the reflectionDir based on the grazing angle
    half3 refractionScattering = lerp(retroReflection, normalize(normal) + retroReflection, angle);
    // Combine retroreflection and refraction scattering
    return retroReflection + (refractionScattering * angle * roughness);
}

/////////////////////UTILITIES//////////////////////////////////////

// Unpack a normalmap and apply a scale factor
half3 ExtractNormal (half4 packedNormal, half normalHeight) {
    half3 normal;
    normal.xy = (packedNormal.wy * 2 - 1);
    normal.xy *= normalHeight;
    normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
    return normal;
}
// Calculate binormal
half3 ComputeBinormal (half3 normal, half4 tangent)
{
    half3 binormal = cross(normal, tangent.xyz) * (tangent.w * unity_WorldTransformParams.w);
    return binormal;
}
//Calculate normal in tangent space
half3 ComputeNormal (half3 normalMap, half3 binormal, half3 normal, half3 tangent)
{
    normal = normalize(
        normalMap.x * tangent +
        normalMap.y * binormal +
        normalMap.z * normal);
    return normal;
}
// Unpack two normals from a single image- .rg = normalA.xy, .ba = normalB.xy, both .z are analytically derived
//to utilize this you need to run it twice, once with your .rg and once with your .ba components from your packed image
half3 ExtractpackedNormals (half2 packedNormal, half normalHeight) {
    half3 normal;
    normal.xy = (packedNormal * 2 - 1);
    normal.xy *= normalHeight;
    normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
    return normal;
}
//combine two normal maps together using whiteout blending for contrast
half3 BlendTwoNormals (half3 normalA, half3 normalB) {
    return normalize(half3(normalA.xy + normalB.xy, normalA.z * normalB.z));
}
// Decode RGBM encoded HDR values from a cubemap
half3 DecodeHDR(in half4 rgbm)
{
    return rgbm.rgb * rgbm.a * 16.0;
}