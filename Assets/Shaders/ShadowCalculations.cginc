// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// ShadowCalculations.cginc

#include <HLSLSupport.cginc>
#include "AutoLight.cginc"
/////////////////////SHADOWCASTING//////////////////////////////////////
#if !defined(SHADOWS_INCLUDED)
#define SHADOWS_INCLUDED

#include "UnityCG.cginc"

struct VertexData {
    float4 position : POSITION;
};

struct alphaStruct
{
    float4 MOAR;
};

float4 ShadowsVertex (VertexData v) : SV_POSITION {
    return UnityObjectToClipPos(v.position);
}

half4 ShadowsFragment (alphaStruct i) : COLOR {
    // // Sample the albedo, MOAR, and normal maps with built-in tiling and offset values
    i.MOAR = tex2D(_MOARMap, uv * _MainTex_ST.xy + _MainTex_ST.zw);
    return float4(0,0,0,i.MOAR.a); 
}

#endif