﻿// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Project:         Daggerfall Tools For Unity
// Copyright:       Copyright (C) 2009-2016 Daggerfall Workshop
// License:         MIT License (http://www.opensource.org/licenses/mit-license.php)
// Web Site:        http://www.dfworkshop.net
// Contact:         Michael Rauter (a.k.a. Nystul)
// Project Page:    https://github.com/Interkarma/daggerfall-unity
// Contributors:    
// 
// Notes: original wireframe shader source: http://scrawkblog.com/2013/03/18/wireframe-shader-for-unity/
//

Shader "Daggerfall/Automap"
{

	// Surface Shader for Automap Geometry
	Properties {
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Albedo Map", 2D) = "white" {}
		_BumpMap("Normal Map", 2D) = "bump" {}
		_EmissionMap("Emission Map", 2D) = "white" {}
		_EmissionColor("Emission Color", Color) = (0,0,0)
		_PlayerPosition("player position", Vector) = (0,0,0,1)
	}	

	SubShader // shader for target 4.0
	{
	    Tags { "Queue"="Geometry" /*"IgnoreProjector"="True"*/ "RenderType"="Opaque" }
		//Tags{ "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" }

    	Pass 
    	{
			//ZWrite On // not really necessary here since default setting

			CGPROGRAM

			#include "UnityCG.cginc"
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag
			
			#pragma multi_compile __ RENDER_IN_GRAYSCALE
			#pragma multi_compile __ AUTOMAP_RENDER_MODE_TRANSPARENT
			
			half4 _Color;
			sampler2D _MainTex;
			sampler2D _BumpMap;
			sampler2D _EmissionMap;
			half4 _EmissionColor;
			uniform float4 _PlayerPosition;
			uniform float _SclicingPositionY;
		
			struct v2f
			{
    			float4  pos : SV_POSITION;				
    			float2  uv : TEXCOORD0;
				float3 worldPos : TEXCOORD5;
			};		

			void vert(appdata_full v, out v2f OUT)
			{
    			OUT.pos = mul(UNITY_MATRIX_MVP, v.vertex);
    			OUT.uv = v.texcoord;
				OUT.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
			}


			half4 frag(v2f IN) : COLOR
			{
				float4 outColor;
				half4 albedo = tex2D(_MainTex, IN.uv) * _Color;
				//half3 emission = tex2D(_EmissionMap, IN.uv).rgb * _EmissionColor;
				outColor.rgb = albedo.rgb; // - emission; // Emission cancels out other lights
				outColor.a = albedo.a;
				if (IN.worldPos.y > _SclicingPositionY)
				{				
					discard;				
				}

				float dist = distance(IN.worldPos.y, _SclicingPositionY);
				outColor.rgb *= 1.0f - max(0.0f, min(0.6f, dist/20.0f));

				#if defined(RENDER_IN_GRAYSCALE)
					half3 color = outColor;
					float grayValue = dot(color.rgb, float3(0.3, 0.59, 0.11));
					outColor.rgb = half3(grayValue, grayValue, grayValue);
				#endif

				return outColor;

			}
			
			ENDCG

    	}

		Pass
		{
			ColorMask 0
		}
		
		Tags{ "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" }
		Blend SrcAlpha OneMinusSrcAlpha
		//Blend OneMinusSrcAlpha SrcAlpha		
		//Blend One One
		//Blend One OneMinusSrcAlpha
		//Blend One DstAlpha
		//Blend SrcAlpha One
		//Blend OneMinusSrcAlpha One

		BlendOp Add, Max

		Pass
		{
			ZWrite Off
			//ZTest Always
			//ColorMask RGBA

			CGPROGRAM

			#include "UnityCG.cginc"
			#pragma target 4.0
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag

			#pragma multi_compile __ RENDER_IN_GRAYSCALE
			#pragma multi_compile __ AUTOMAP_RENDER_MODE_WIREFRAME AUTOMAP_RENDER_MODE_TRANSPARENT

			half4 _Color;
			sampler2D _MainTex;
			sampler2D _BumpMap;
			sampler2D _EmissionMap;
			half4 _EmissionColor;
			uniform float4 _PlayerPosition;
			uniform float _SclicingPositionY;

			struct v2g
			{
				float4  pos : SV_POSITION;
				float2  uv : TEXCOORD0;
				float3 worldPos : TEXCOORD5;
			};

			void vert(appdata_full v, out v2g OUT)
			{
				OUT.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				OUT.uv = v.texcoord;
				OUT.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
			}

			struct g2f
			{
				float4  pos : SV_POSITION;
				float2  uv : TEXCOORD0;
				float3 dist : TEXCOORD1;
				float3 worldPos : TEXCOORD5;
			};

			[maxvertexcount(3)]
			void geom(triangle v2g IN[3], inout TriangleStream<g2f> triStream)
			{

				float2 WIN_SCALE = float2(_ScreenParams.x / 2.0, _ScreenParams.y / 2.0);

				//frag position
				float2 p0 = WIN_SCALE * IN[0].pos.xy / IN[0].pos.w;
				float2 p1 = WIN_SCALE * IN[1].pos.xy / IN[1].pos.w;
				float2 p2 = WIN_SCALE * IN[2].pos.xy / IN[2].pos.w;

				//barycentric position
				float2 v0 = p2 - p1;
				float2 v1 = p2 - p0;
				float2 v2 = p1 - p0;
				//triangles area
				float area = abs(v1.x*v2.y - v1.y * v2.x);

				g2f OUT;
				OUT.pos = IN[0].pos;
				OUT.uv = IN[0].uv;
				OUT.dist = float3(area / length(v0),0,0);
				OUT.worldPos = IN[0].worldPos;
				triStream.Append(OUT);

				OUT.pos = IN[1].pos;
				OUT.uv = IN[1].uv;
				OUT.dist = float3(0,area / length(v1),0);
				OUT.worldPos = IN[1].worldPos;
				triStream.Append(OUT);

				OUT.pos = IN[2].pos;
				OUT.uv = IN[2].uv;
				OUT.dist = float3(0,0,area / length(v2));
				OUT.worldPos = IN[2].worldPos;
				triStream.Append(OUT);



			}

			half4 frag(g2f IN) : COLOR
			{
				float4 outColor;
				half4 albedo = tex2D(_MainTex, IN.uv) * _Color;
				//half3 emission = tex2D(_EmissionMap, IN.uv).rgb * _EmissionColor;
				outColor.rgb = albedo.rgb; // - emission; // Emission cancels out other lights
				outColor.a = albedo.a;
				if (IN.worldPos.y > _SclicingPositionY)
				{
					#if defined(AUTOMAP_RENDER_MODE_WIREFRAME)
						//distance of frag from triangles center
						float d = min(IN.dist.x, min(IN.dist.y, IN.dist.z));
						//fade based on dist from center
						float I = exp2(-4.0*d*d);

						if (I < 0.1f)
						{
							clip(-1.0);
							outColor = float4(1.0, 0.0, 0.0, 1.0);
						}
						else
						{
							#if defined(RENDER_IN_GRAYSCALE)
								outColor = float4(0.25, 0.25, 0.25, 0.6);
							#else
								outColor = float4(0.9, 0.9, 0.7, 0.6);
							#endif
						}
					#elif defined(AUTOMAP_RENDER_MODE_TRANSPARENT)
						outColor.a = 0.65;
					#else //#elif defined(AUTOMAP_RENDER_MODE_CUTOUT)
						clip(-1.0);
						outColor = half4(1.0, 0.0, 0.0, 1.0);
					#endif					
				}
				else
				{
					discard;
				}

				float dist = distance(min(IN.worldPos.y, _SclicingPositionY), _SclicingPositionY);

				outColor.rgb *= 1.0f - max(0.0f, min(0.6f, dist / 20.0f));

				#if defined(RENDER_IN_GRAYSCALE)
					half3 color = outColor;
					float grayValue = dot(color.rgb, float3(0.3, 0.59, 0.11));
					outColor.rgb = half3(grayValue, grayValue, grayValue);
				#endif

				return outColor;

			}

			ENDCG
		}
	}

	SubShader // fallback shader for target 3.0
	{
		Tags{ "Queue" = "Geometry" "IgnoreProjector" = "True" "RenderType" = "Opaque" }

		Pass
		{
			CGPROGRAM

			#include "UnityCG.cginc"
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile __ RENDER_IN_GRAYSCALE
			#pragma multi_compile __ AUTOMAP_RENDER_MODE_TRANSPARENT

			half4 _Color;
			sampler2D _MainTex;
			sampler2D _BumpMap;
			sampler2D _EmissionMap;
			half4 _EmissionColor;
			uniform float4 _PlayerPosition;
			uniform float _SclicingPositionY;

			struct v2f
			{
				float4  pos : SV_POSITION;
				float2  uv : TEXCOORD0;
				float3 worldPos : TEXCOORD5;
			};

			void vert(appdata_full v, out v2f OUT)
			{
				OUT.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				OUT.uv = v.texcoord;
				OUT.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
			}


			half4 frag(v2f IN) : COLOR
			{
				float4 outColor;
			half4 albedo = tex2D(_MainTex, IN.uv) * _Color;
			//half3 emission = tex2D(_EmissionMap, IN.uv).rgb * _EmissionColor;
			outColor.rgb = albedo.rgb; // - emission; // Emission cancels out other lights
			outColor.a = albedo.a;
			if (IN.worldPos.y > _SclicingPositionY)
			{
				discard;
			}

			float dist = distance(IN.worldPos.y, _SclicingPositionY);
			outColor.rgb *= 1.0f - max(0.0f, min(0.6f, dist / 20.0f));

			#if defined(RENDER_IN_GRAYSCALE)
				half3 color = outColor;
				float grayValue = dot(color.rgb, float3(0.3, 0.59, 0.11));
				outColor.rgb = half3(grayValue, grayValue, grayValue);
			#endif

			return outColor;

			}

			ENDCG

		}

		Pass {
	        ColorMask 0
		}
		
		Tags{ "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" }
		Blend SrcAlpha OneMinusSrcAlpha
		BlendOp Add, Max

		Pass
		{
			ZWrite Off
			CGPROGRAM

			#include "UnityCG.cginc"
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile __ RENDER_IN_GRAYSCALE
			#pragma multi_compile __ AUTOMAP_RENDER_MODE_TRANSPARENT

			half4 _Color;
			sampler2D _MainTex;
			sampler2D _BumpMap;
			sampler2D _EmissionMap;
			half4 _EmissionColor;
			uniform float4 _PlayerPosition;
			uniform float _SclicingPositionY;

			struct v2f
			{
				float4  pos : SV_POSITION;
				float2  uv : TEXCOORD0;
				float3 worldPos : TEXCOORD5;
			};

			void vert(appdata_full v, out v2f OUT)
			{
				OUT.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				OUT.uv = v.texcoord;
				OUT.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
			}


			half4 frag(v2f IN) : COLOR
			{
				float4 outColor;
				half4 albedo = tex2D(_MainTex, IN.uv) * _Color;
				//half3 emission = tex2D(_EmissionMap, IN.uv).rgb * _EmissionColor;
				outColor.rgb = albedo.rgb; // - emission; // Emission cancels out other lights
				outColor.a = albedo.a;
				if (IN.worldPos.y > _SclicingPositionY)
				{
					#if defined(AUTOMAP_RENDER_MODE_TRANSPARENT)
						outColor.a = 0.65;
					#else //#elif defined(AUTOMAP_RENDER_MODE_CUTOUT)
						clip(-1.0);
						outColor = half4(1.0, 0.0, 0.0, 1.0);
					#endif					
				}
				else
				{
					discard;
				}

				float dist = distance(IN.worldPos.y, _SclicingPositionY);
				outColor.rgb *= 1.0f - max(0.0f, min(0.6f, dist / 20.0f));

				#if defined(RENDER_IN_GRAYSCALE)
					half3 color = outColor;
					float grayValue = dot(color.rgb, float3(0.3, 0.59, 0.11));
					outColor.rgb = half3(grayValue, grayValue, grayValue);
				#endif

				return outColor;

			}

			ENDCG

		}
	}
	FallBack "Standard"
}
