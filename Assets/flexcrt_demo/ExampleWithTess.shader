//
// Demo showing how to perform 8 million random-writes per CRT pass.
// This demo abuses tessellation to turn the two emitted faces per
// frame into 2048 (though, it could go as high as 7,938)
//

Shader "flexcrt/ExampleWithTess"
{
	Properties
	{
	}

	CGINCLUDE
		#pragma vertex vert
		#pragma fragment frag
		#pragma geometry geo
		#pragma multi_compile_fog
        #pragma target 5.0

		#define CRTTEXTURETYPE uint4
		#include "/Assets/flexcrt/flexcrt.cginc"
	ENDCG


	SubShader
    {
		Tags { "RenderType"="Opaque" }

		Pass
		{
            Name "Demo Compute Test"
			
			CGPROGRAM
			
			#pragma hull hull
			#pragma domain dom

			#include "/Assets/hashwithoutsine/hashwithoutsine.cginc"

			struct vtx
			{
				float4 vertex : SV_POSITION;
				uint4 batchID : TEXCOORD0;
			};

			struct g2f
			{
				float4 vertex		   : SV_POSITION;
				uint4 color            : TEXCOORD0;
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


			// Divx can be no more than 63x63 divisions
			// 63*63 => Will get us 3,969 iterations. 
			// 32*32 => Will get us 1,024 iterations. << We choose this for convenience.
			#define TESS_DIVX 32
			#define TESS_DIVY 32

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

			// Because we are outputting a vertex and a color, that's 8 interpolation value, so
			// with PS5.0 we can output a maximum of 128 pixels from each execution.
			[maxvertexcount(128)]
			
			// No extra instances for this test.
			[instance(32)]

			void geo( triangle vtx input[3], inout PointStream<g2f> stream,
				uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID )
			{
				//if( geoPrimID < 0 ) discard;
				//We are foregoing half of our incoming data to test just the tess data.

				int batchID = input[0].batchID.x;				

				int subdivid = input[0].batchID.y + input[0].batchID.z * TESS_DIVX;

				for( int i = 0; i < 128; i++ )
				{
					g2f o;
					uint blockid = ((i + instanceID * 128) + geoPrimID * 4096)*(TESS_DIVX*TESS_DIVY) + subdivid;
					o.vertex = FlexCRTCoordinateOut( uint2( blockid % 4096, blockid / 4096 ) );
					o.color = uint4( (_Time.y * 65536)%65536, (subdivid%2)*65536, 0, 0 );
					stream.Append(o);
				}
			}

			uint4 frag( g2f IN ) : SV_Target
			{
				return IN.color;
			}
			ENDCG
		}
	}
}
