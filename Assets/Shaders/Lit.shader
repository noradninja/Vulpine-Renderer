Shader "Vulpine Renderer/Lit"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "black" { }
        _MOARMap ("MOAR (RGBA)", 2D) = "black" { }
        _Cutoff ("Alpha cutoff", Range(0,1)) = 0
        _NormalMap ("Normal Map", 2D) = "bump" { }
        _NormalHeight ("Height", Range(-2,2)) = 1
        _Roughness ("Roughness", Range(0,1)) = 0.5
        _Metalness ("Metalness", Range(0, 1)) = 0.5
    }
    SubShader
    {
	    Tags { "RenderType"="Opaque"}
        ZWrite On
		Blend One OneMinusSrcAlpha //because we are going to clip at the end
		Cull Back
        LOD 100
        //Cull Off
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 4.5
            #include "UnityCG.cginc"
            #include "UnityPBSLighting.cginc"
            #include "AutoLight.cginc"
            #include "LightingFastest.cginc"

            // Global Properties
            float _NumDirectionalLights;
            float _NumPointSpotLights;
            // Shader Properties
            float _Roughness, _Metalness, _Cutoff;
            half _NormalHeight;
            sampler2D_half _MainTex, _NormalMap, _MOARMap;
            
            // Coordinate variables for textures
            float4 _NormalMap_ST;
            float4 _MainTex_ST;
            
            // Struct to match C# struct for referencing
            struct LightData
            {
                float4 position;
                float4 color;
                float4 variables;
            };
            // Struct for Vertex Input
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 color : COLOR;
                float2 uv: TEXCOORD0;
            };
            // Struct for Vertex Output
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 color : COLOR;
                float3 worldPos : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 tangent : TEXCOORD2;
                float2 uv: TEXCOORD3;
            	LIGHTING_COORDS(4,5)
                
            };
            
            // Global Directional Lights Buffer
                StructuredBuffer<LightData> _DirectionalLightsBuffer;
            // Global Point/Spot Lights Buffer
                StructuredBuffer<LightData> _PointSpotLightsBuffer;
            
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
            	TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }
            // Fragment Shader
            half4 frag(v2f i) : SV_Target
            {
                // Initialize accumulated color
                float4 accumColor = float4(0,0,0,1);
                // Prevents multing by zero on nonmetals
                _Metalness += 0.001;
               
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
                float3 grazingAngle = max (0,pow(1 - dot(i.normal, viewDir), 0.25));
                // Reflection
                half3 reflection = reflect(-viewDir, UnityObjectToWorldNormal(normal));
                // Add a tiny value to albedo to eliminate absolute blacks
                albedo.rgb += 0.1f;
                float shadow = LIGHT_ATTENUATION(i);
                // Loop over directional lights
                for (int j = 0; j < 4; ++j)
                {
                    // Calculate array index for the current light
                    int arrayIndex = j;
                    // Extract LightData using array indices from the global buffer
                    LightData light = _DirectionalLightsBuffer[arrayIndex];
                    // Add directional light contribution
                    accumColor += LightAccumulation(
                            i.normal, normal, viewDir, albedo, MOAR,
                            light.color.rgb * _Metalness, _Roughness, _Metalness,
                            i.worldPos, light.position, light.color,
                            light.variables.x, light.variables.y,
                            0.0, 0.0, grazingAngle, reflection, _Cutoff, shadow
                        );
                }
                // Loop over point/spot lights
                for (int k = 0; k < 8; ++k)
                {
                    // Calculate array index for the current light
                    int arrayIndexPS = k;
                    // Extract LightData using array indices from the global buffer
                    LightData pointSpotLight = _PointSpotLightsBuffer[arrayIndexPS];
                    // Add point/spot light contribution
                    accumColor += LightAccumulation(
                            i.normal, normal, viewDir, albedo, MOAR,
                            pointSpotLight.color.rgb * _Metalness, _Roughness, _Metalness,
                            i.worldPos, pointSpotLight.position, pointSpotLight.color,
                            pointSpotLight.variables.x, pointSpotLight.variables.y,
                            2.0, 45.0, grazingAngle, reflection, _Cutoff, shadow
                        );
                }
                // Assign the final color to the fragment
                return accumColor;
            }
            ENDCG
        }
//		//  Shadow rendering pass
//        Pass{
//            Tags {"LightMode"="ShadowCaster"}
//
//            CGPROGRAM
//            #pragma vertex vert
//            #pragma fragment frag
//			#pragma target 3.0
//            #pragma multi_compile_shadowcaster
//			#pragma multi_compile_fog
//			#pragma multi_compile _ LOD_FADE_CROSSFADE
//            #include "UnityCG.cginc"
//			#include "UnityPBSLighting.cginc" // TBD: remove
//			
//			struct v2f {
//				V2F_SHADOW_CASTER;
//				half2  uv : TEXCOORD0;
//				UNITY_VERTEX_OUTPUT_STEREO
//			};
//			struct appdata {
//				half3 vertex : POSITION;
//				half3 uv : TEXCOORD0;
//				
//
//			};
//			sampler2D_half _MainTex, _MOARMap;
//            float4 _MainTex_ST;
//            float _Cutoff;
//			
//						
//			v2f vert( appdata v )
//			{
//				v2f o;
//				half3 worldPos = mul (unity_ObjectToWorld, half4(v.vertex, 1) ).xyz;
//				UNITY_SETUP_INSTANCE_ID(v);
//				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
//				TRANSFER_SHADOW_CASTER(o);
//				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
//				return o;
//			}
//            
//			half4 frag( v2f i ) : SV_Target
//			{
//			
//				fixed4 texcol = tex2D( _MOARMap, i.uv );
//				
//		
//					clip(texcol.b - _Cutoff );
//						
//				SHADOW_CASTER_FRAGMENT(i);
//			}
//            ENDCG
//        }
    }
    FallBack "Diffuse"
}
