// Upgrade NOTE: commented out 'float4x4 _CameraToWorld', a built-in variable
// Upgrade NOTE: replaced '_LightMatrix0' with 'unity_WorldToLight'
// Upgrade NOTE: replaced 'unity_World2Shadow' with 'unity_WorldToShadow'

Shader "Vulpine Renderer/Lit"
{
    Properties
    {
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
    }
    SubShader
    {
Tags { "Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType"="TransparentCutout" "Lightmode"="ForwardBase"} //I know this is weird but it's a workaround for the Vita
		LOD 80
		ZWrite On
		Cull Off
		Blend One OneMinusSrcAlpha //because we are going to clip at the end
       
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile _ SHADOWS_SCREEN
            // #pragma multi_compile _ SHADOWS_DEPTH
            #pragma multi_compile_fog
			// Compile specialized variants for when positional (point/spot) and spot lights are present
			#pragma multi_compile __ POINT SPOT
			#pragma multi_compile __ AMBIENT_ON
            #pragma shader_feature _PARALLAX_MAP
            #include "UnityCG.cginc"
            #include "UnityPBSLighting.cginc"
            #include "AutoLight.cginc"
            #include "LightingFastest.cginc"

            // Global Properties
            float _NumDirectionalLights;
            float _NumPointSpotLights;
            // Shader Properties
            float _Roughness, _Metalness, _Cutoff, _ParallaxStrength;;
            half _NormalHeight;
            sampler2D _MainTex, _NormalMap, _MOARMap, _cookieTexture, _ParallaxMap;


            
            // Coordinate variables for textures
            float4 _NormalMap_ST;
            float4 _MainTex_ST;
 
            // Struct for Vertex Input
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 color : COLOR;
                float2 uv: TEXCOORD0;
            	#if defined(_PARALLAX_MAP)
					float3 tangentViewDir : TEXCOORD1;
				#endif
            };
            // Struct for Vertex Output
            struct v2f
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float3 worldPos : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 tangent : TEXCOORD2;
                float2 uv: TEXCOORD3;
                SHADOW_COORDS(4)
                #if defined(SHADOWS_SCREEN)
		            float4 shadowCoordinates : TEXCOORD5;
	            #endif
					float3 tangentViewDir : TEXCOORD6;
			
            };
            
            // Global Directional Lights Buffer
                float4x4 _DirectionalLightsBuffer[4];
            // Global Point/Spot Lights Buffer
                float4x4 _PointSpotLightsBuffer[8];
            
            // Vertex Shader
            v2f vert(appdata v)
            {
                v2f o;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normal = mul(v.normal, unity_WorldToObject);
                o.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.color = v.color;
                o.uv = v.uv;
            	
					float3x3 objectToTangent = float3x3(
						v.tangent.xyz,
						cross(v.normal, v.tangent.xyz) * v.tangent.w,
						v.normal
					);
					o.tangentViewDir = mul(objectToTangent, ObjSpaceViewDir(v.vertex));
		
            	TRANSFER_VERTEX_TO_FRAGMENT(o);
                TRANSFER_SHADOW(o);
                return o;
            }
            
            // Fragment Shader
            half4 frag(v2f i) : COLOR
            {
                UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
                // Initialize accumulated color
                float4 accumColor = float4(0,0,0,1);
                float4 grabColor = float4(0,0,0,1);
                // Prevents multing by zero on nonmetals
                _Metalness += 0.001;
            	//apply parallax offsets
				
					i.tangentViewDir = normalize(i.tangentViewDir);
            		i.tangentViewDir.xy /= (i.tangentViewDir.z + 0.42);
            		float height = tex2D(_ParallaxMap, i.uv.xy).r;
					i.uv.xy += i.tangentViewDir.xy * (_ParallaxStrength * height);
                // Sample the albedo, MOAR, and normal maps with built-in tiling and offset values
                float4 MOAR = tex2D(_MOARMap, i.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                float4 albedo = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                float3 normalMap = ExtractNormal(tex2D(_NormalMap, i.uv * _NormalMap_ST.xy + _NormalMap_ST.zw), _NormalHeight);
                
                // Compute normal mapping
                float3 binormal = cross(i.normal, i.tangent.xyz) * (i.tangent.w * unity_WorldTransformParams.w);
                float3 normal = normalize(
		                        normalMap.x * i.tangent +
		                        normalMap.y * binormal +
		                        normalMap.z * i.normal);
                //Get direction of ray from the camera towards the object surface
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);                
               
                
                // Per vertex terms- replace i.normal with normal to make these per fragment
                // Schlick
                float3 grazingAngle = max (0,pow(1 - dot(i.normal, viewDir), 0.35));
                // Reflection
                half3 reflection = reflect(-viewDir, UnityObjectToWorldNormal(i.normal));
                // Add a tiny value to albedo to eliminate absolute blacks
                albedo.rgb += 0.1f;
                float shadow = attenuation;
                // Loop over directional lights
                for (int j = 0; j < 4; ++j)
                {
                    // Extract LightData using array indices from the global buffer
                    float4 position = _DirectionalLightsBuffer[j][0].xyzw;
                    float4 color = _DirectionalLightsBuffer[j][1].xyzw;
                    float4 rotation = _DirectionalLightsBuffer[j][2].xyzw;
                    color.w = 1;
                    float4 variables = _DirectionalLightsBuffer[j][3].xyzw;
                    float3 specColor = color.rgb;
                   
                    // Add directional light contribution
                    grabColor = LightAccumulation(
                            i.normal, normal, viewDir, albedo, MOAR,
                            specColor, _Roughness, _Metalness,
                            i.worldPos, position, color.xyz,
                            position.w, variables.y,
                            variables.z, variables.x, grazingAngle,
                            reflection, _Cutoff, shadow, _cookieTexture
                        );
                       accumColor += grabColor;
                }
                // Loop over point/spot lights
                for (int k = 0; k < 8; ++k)
                {
                    // Extract LightData using array indices from the global buffer
                    float4 position = _PointSpotLightsBuffer[k][0];
                    float4 color = _PointSpotLightsBuffer[k][1];
                    float4 rotation = _PointSpotLightsBuffer[k][2];
                    color.w = 1;
                    float4 variables = _PointSpotLightsBuffer[k][3];
                    float3 specColor = color.rgb;
                    
                    // Add point/spot light contribution
                    grabColor = LightAccumulation(
                            i.normal, normal, viewDir, albedo, MOAR,
                            specColor, _Roughness, _Metalness,
                            i.worldPos, position, color.xyz,
                            position.w, variables.y,
                            variables.z, variables.x, grazingAngle,
                            reflection, _Cutoff, shadow, _cookieTexture
                        );
                    accumColor += grabColor;
                }
                // Assign the final color to the fragment
                return accumColor;
            }
            ENDCG
        }
		Pass{
            Tags {"LightMode"="ShadowCaster"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma target 3.0
               #pragma multi_compile_fog
			// Compile specialized variants for when positional (point/spot) and spot lights are present
			#pragma multi_compile __ POINT SPOT
			#pragma multi_compile __ AMBIENT_ON
			#pragma multi_compile_fog
			#pragma multi_compile _ LOD_FADE_CROSSFADE
            #include "UnityCG.cginc"
			#include "UnityPBSLighting.cginc" // TBD: remove
			
			struct v2f {
				//V2F_SHADOW_CASTER;
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
            	float4 tangent : TANGENT;
				float3 tangentViewDir : TEXCOORD1;
            	UNITY_VERTEX_OUTPUT_STEREO
            };
			struct appdata {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
				float4 tangent : TEXCOORD2;
				float3 tangentViewDir : TEXCOORD1;
			};
			uniform half4 _MainTex_ST;
            float _ParallaxStrength;
            sampler2D _ParallaxMap;
	
			v2f vert( appdata v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.vertex = UnityClipSpaceShadowCasterPos(v.vertex.xyz, v.normal);
				o.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
				float3x3 objectToTangent = float3x3(
						v.tangent.xyz,
						cross(v.normal, v.tangent.xyz) * v.tangent.w,
						v.normal
					);
				o.tangentViewDir = mul(objectToTangent, ObjSpaceViewDir(v.vertex));
				o.normal = 0;
				return o;
			}
            
            sampler2D _MOARMap;
			float _Cutoff;

            float GetAlpha (v2f i) {
				float alpha = tex2D(_MOARMap, i.uv.xy).b;
				return alpha;
			}
			half4 frag( v2f i ) : COLOR
			{
				//apply parallax offsets
				i.tangentViewDir = normalize(i.tangentViewDir);
            	i.tangentViewDir.xy /= (i.tangentViewDir.z + 0.42);
            	float height = tex2D(_ParallaxMap, i.uv.xy).r;
				i.uv += i.tangentViewDir.xy * (_ParallaxStrength * height);
				SHADOW_CASTER_FRAGMENT(i.uv);
			}
            ENDCG
        }
    }
    FallBack "Diffuse"
}
