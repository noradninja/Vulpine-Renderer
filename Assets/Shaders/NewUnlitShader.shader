Shader "Unlit/NewUnlitShader"
{
	 Properties
    {
    	[Enum(Opaque,2,Cutout,0)] _BlendingMode ("Blending Mode", Float) = 0.0
        _MainTex ("Albedo (RGB)", 2D) = "black" { }
        _MOARMap ("MOAR (RGBA)", 2D) = "black" { }
	    _ParallaxMap ("Parallax", 2D) = "white" {}
		_ParallaxStrength ("Parallax Strength", Range(0, 10)) = 0
        _cookieTexture ("LightCookie (RGBA)", 2D) = "black" { }
        _Cutoff ("Alpha cutoff", Range(0,1)) = 0
        _NormalMap ("Normal Map", 2D) = "bump" { }
        _NormalHeight ("Height", Range(-2,2)) = 1
        _Roughness ("Roughness", Range(0,1)) = 0.5
        _Metalness ("Metalness", Range(0, 1)) = 0.5
    	[ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0
    	[ToggleOff] _SoftBody("Soft Body", float) = 0.0
    }
    SubShader
    {
Tags { "Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType"="TransparentCutout" "Lightmode"="ForwardBase"} //I know this is weird but it's a workaround for the Vita
		LOD 80
		ZWrite On
		Cull [_BlendingMode]
		Blend One OneMinusSrcAlpha //because we are going to clip at the end
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 color : COLOR;
				#if defined(_PARALLAX_MAP)
					float3 tangentViewDir : TEXCOORD1;
				#endif
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv);
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
