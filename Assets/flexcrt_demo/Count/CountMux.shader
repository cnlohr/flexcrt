Shader "Unlit/CountMux"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
		
		
		Pass
		{
			Tags { }
			ZTest never
			Blend One One
			ZWrite Off

            Name "Demo Compute Test"	
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma geometry geo
			#pragma hull hull
			#pragma domain dom
			#pragma multi_compile_fog

			#pragma target 5.0

			#define CRTTEXTURETYPE uint4
			#include "/Assets/flexcrt/Assets/flexcrt/flexcrt.cginc"
			
			#include "/Assets/flexcrt/Assets/hashwithoutsine/hashwithoutsine.cginc"

			struct vtx
			{
				float4 vertex : SV_POSITION;
				uint4 batchID : TEXCOORD0;
			};

			struct g2f
			{
				float4 vertex		   : SV_POSITION;
			};

			// The vertex shader doesn't really perform much anything.
			vtx vert( appdata_customrendertexture IN )
			{
				vtx o;
				o.batchID = uint4( IN.vertexID / 6, 0, 0, 0 );
				
				// This is unused, but must be initialized otherwise things get janky.
				o.vertex = 0;
				return o;
			}
			
			// The base amount of geometry is 4 vertices which get transformed into 4 points.

			// Divx can be no more than 63x63 divisions
			// 63*63 => Will get us 4,096 iterations. 
			// 32*32 => Will get us 1,024 iterations. << We choose this for convenience.
			#define TESS_DIVX 127
			#define TESS_DIVY 127
			// 0, 0 = base
			// 1, 1 = x4
			// 3, 3 = x16
			// 7, 7 = x64
			//15,15 = x256
			//31,31 = x1024
			//63,63 = x4096
			
			// So, here, we could at most have 16,384 pixels from the tess shader.
			
			struct tessFactors
			{
				float edgeTess[4] : SV_TessFactor;
				float insideTess[2] : SV_InsideTessFactor;
			};

			tessFactors hullConstant(InputPatch<vtx, 4> I , uint quadID : SV_PrimitiveID)
			{
				tessFactors o = (tessFactors)0;

				if (quadID > 1) return o;

				o.edgeTess[0] = 0;
				o.edgeTess[1] = 0;
				o.edgeTess[2] = 0;
				o.edgeTess[3] = 0;
				o.insideTess[0] = TESS_DIVX+1;
				o.insideTess[1] = TESS_DIVY+1;
				o.edgeTess[1] = o.edgeTess[3] = o.insideTess[0];
				o.edgeTess[0] = o.edgeTess[2] = o.insideTess[1];
			   
				return o;
			}
		 
			[domain("quad")]
			[partitioning("integer")]
			[outputtopology("triangle_cw")]
			[patchconstantfunc("hullConstant")]
			[outputcontrolpoints(4)]
			vtx hull( InputPatch<vtx, 4> IN, uint uCPID : SV_OutputControlPointID )
			{
				vtx o = (vtx)0;
				o.vertex = IN[uCPID].vertex;
				o.batchID = uint4( IN[uCPID].batchID.xyzw );
				return o;
			}
	 
			[domain("quad")]
			vtx dom( tessFactors HSConstantData, const OutputPatch<vtx, 4> IN, float2 bary : SV_DomainLocation )
			{
				vtx o = (vtx)0;
				o.vertex = IN[0].vertex;
				o.batchID = uint4( IN[0].batchID.x, bary.xy*float2((TESS_DIVX+0.5), (TESS_DIVY+0.5)), IN[0].batchID.w);
				return o;
			}


			//#define MAXVERTEXCOUNT 256
			#define MAXINSTANCECOUNT 32
			#define MAXVERTEXCOUNT 1
			//#define MAXINSTANCECOUNT 1
			
			// Because we are outputting a vertex and a color, that's 8 interpolation value, so
			// with PS5.0 we can output a maximum of 128 pixels from each execution.
			[maxvertexcount(MAXVERTEXCOUNT)]
			
			// No extra instances for this test.
			[instance(MAXINSTANCECOUNT)]

			void geo( point vtx input[1], inout PointStream<g2f> stream,
				uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID )
			{
			
				int batchID = input[0].batchID.x;				

				int subdivid = input[0].batchID.y + input[0].batchID.z * TESS_DIVX;

				for( int i = 0; i < MAXVERTEXCOUNT; i++ )
				{
					g2f o;
					uint blockid = ((i + instanceID * 128) + geoPrimID * 4096)*(TESS_DIVX*TESS_DIVY) + subdivid;
					o.vertex = FlexCRTCoordinateOut( 0..xx );
					stream.Append(o);
				}
			}

			float4 frag( g2f IN ) : SV_Target
			{
				return 1;
			}
			ENDCG
		}
		
		
        Pass
        {

			Tags { }
			ZTest never
			ZWrite Off
			Blend Zero Zero

			Name "Black"
            CGPROGRAM

			#pragma target 5.0

			#define CRTTEXTURETYPE float4
			#include "/Assets/flexcrt/Assets/flexcrt/flexcrt.cginc"

            #pragma vertex DefaultCustomRenderTextureVertexShader
			#pragma fragment frag
            #pragma target 3.0

            float4      _Color;
            sampler2D   _Tex;

            float4 frag(v2f_customrendertexture IN) : COLOR
            {
				return .5;
			}
			ENDCG
		}
	}
}
