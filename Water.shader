Shader "Custom/Water"
{
    Properties {
		_CellSize ("Cell Size", Range(0, 5)) = 2
		_TimeScale ("Scrolling Speed", Range(0, 2)) = 1
		_ColourBase ("Colour Base", Color) = (0.1791562, 0.3472257, 0.6226414, 1)
		_ColourVoronoi ("Colour Voronoi", Color) = (0.5271004, 0.7999218, 0.9716981, 1)
		_VoronoiStrengthColour ("Voronoi Colour Strength", Range(0, 1)) = 0.4
		_VoronoiStrengthNormal ("Voronoi Normal Strength", Range(0, 1)) = 0.2
		_VoronoiStrengthDisplacement ("Voronoi Displacement Strength", Range(0, 10)) = 0.2
		_FoamDistance ("Foam Min Distance From Cell", Range(0, 1.5)) = 0.86
		_FoamStrength ("Foam Colour Strength", Range(0, 1)) = 0.4
		_MaxAlpha ("Max Alpha", Range(0, 1)) = 1
		_MinAlpha ("Min Alpha", Range(0, 1)) = 0.3
	}
	SubShader {
		Tags{ "RenderType"="Transparent" "Queue"="Transparent"}

		CGPROGRAM

		#pragma surface surf Standard fullforwardshadows vertex:vert nofog noshadow alpha
		#pragma target 3.0

		#include "UnityCG.cginc"
		// https://www.ronja-tutorials.com/post/024-white-noise/
		#include "Random.cginc"

		float _CellSize;
		float _TimeScale;
		float4 _ColourBase;
		float4 _ColourVoronoi;
		float _VoronoiStrengthColour;
		float _VoronoiStrengthNormal;
		float _VoronoiStrengthDisplacement;
		float _FoamDistance;
		float _FoamStrength;
		float _MaxAlpha;
		float _MinAlpha;

		struct Input {
			float3 worldPos;
			float3 normal;
			float3 tangent;
			float3 bitangent;
		};

		float3 voronoiNoise(float3 value){
			// https://www.ronja-tutorials.com/post/028-voronoi-noise/

			float3 baseCell = floor(value);

			//first pass to find the closest cell
			float minDistToCell = 10;
			float3 toClosestCell;
			float3 closestCell;
			[unroll]
			for(int x1=-1; x1<=1; x1++){
				[unroll]
				for(int y1=-1; y1<=1; y1++){
					[unroll]
					for(int z1=-1; z1<=1; z1++){
						float3 cell = baseCell + float3(x1, y1, z1);
						float3 cellPosition = cell + rand3dTo3d(cell);
						float3 toCell = cellPosition - value;
						float distToCell = length(toCell);
						if(distToCell < minDistToCell){
							minDistToCell = distToCell;
							closestCell = cell;
							toClosestCell = toCell;
						}
					}
				}
			}

			//second pass to find the distance to the closest edge
			//float minEdgeDistance = 10;
			//[unroll]
			//for(int x2=-1; x2<=1; x2++){
			//	[unroll]
			//	for(int y2=-1; y2<=1; y2++){
			//		[unroll]
			//		for(int z2=-1; z2<=1; z2++){
			//			float3 cell = baseCell + float3(x2, y2, z2);
			//			float3 cellPosition = cell + rand3dTo3d(cell);
			//			float3 toCell = cellPosition - value;

			//			float3 diffToClosestCell = abs(closestCell - cell);
			//			bool isClosestCell = diffToClosestCell.x + diffToClosestCell.y + diffToClosestCell.z < 0.1;
			//			if(!isClosestCell){
			//				float3 toCenter = (toClosestCell + toCell) * 0.5;
			//				float3 cellDifference = normalize(toCell - toClosestCell);
			//				float edgeDistance = dot(toCenter, cellDifference);
			//				minEdgeDistance = min(minEdgeDistance, edgeDistance);
			//			}
			//		}
			//	}
			//}

			//float random = rand3dTo1d(closestCell);
    		//return float3(minDistToCell, random, minEdgeDistance);
			return float3(minDistToCell, closestCell.x, closestCell.z);
		}

		float envolvente(float t)
		{
			const float e = 2.718281828459045;
			//return (pow(e,t)) / (e-1);
			//return sqrt(t);
			return t*t;
		}

		void vert(inout appdata_tan v, out Input o) {
            UNITY_INITIALIZE_OUTPUT(Input, o);

            float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
			float3 normal = mul(unity_ObjectToWorld, v.normal).xyz;

			float3 value = worldPos / _CellSize;
			value.y += _Time.y * _TimeScale;
			float3 vRes = voronoiNoise(value);

			o.worldPos = worldPos;
			v.vertex = mul(unity_WorldToObject, float4(worldPos + normal * (vRes.x -0.5)  * _VoronoiStrengthDisplacement, v.vertex.w));
			o.normal = normal;
			o.tangent = mul(unity_ObjectToWorld, v.tangent.xyz);
			o.bitangent = cross(o.normal, o.tangent);
			o.bitangent *= v.tangent.w;// * unity_WorldTransormParams.w; // to correctly handle flipping/mirroring
		}


		void surf (Input i, inout SurfaceOutputStandard o) {
			float3 pos = i.worldPos;
			float3 value = pos / _CellSize;
			value.y += _Time.y * _TimeScale;

			float3 vRes = voronoiNoise(value);
			float distToCell = vRes.x;
			float2 cell = vRes.yz;
			float env = envolvente(distToCell);

			const float3x3 mtxTngToWorld = {
				i.tangent.x, i.bitangent.x, i.normal.x,
				i.tangent.y, i.bitangent.y, i.normal.y,
				i.tangent.z, i.bitangent.z, i.normal.z
            };

			//float3 normal = float3(0, 0, 0);
			//normal.x = ddx(distToCell);
			//normal.y = ddy(distToCell);
			//normal *= _VoronoiStrengthNormal;
			//normal.z = 1;
			//normal = normalize(normal);

			float2 toCell = normalize(cell - value.xz);
			float3 normal = lerp(float3(0, 1, 0), float3(toCell.x, 0, toCell.y), clamp(env * _VoronoiStrengthNormal, 0, 1));
			normal = mul(normal, mtxTngToWorld); // surf wants the normal in tangent space
			

			o.Normal = normal;
			o.Albedo = _ColourBase + _ColourVoronoi * clamp(distToCell * _VoronoiStrengthColour, 0, 1);
			float foamLerpT = smoothstep(_FoamDistance - 0.1, _FoamDistance + 0.1, distToCell);
			if (foamLerpT > 0) {
				o.Albedo += lerp(float4(0, 0, 0, 0), _FoamStrength, foamLerpT);
				o.Alpha = 1;
            } else {
				o.Alpha = lerp(_MinAlpha, _MaxAlpha, distToCell);
            }
			//if (distToCell > _FoamDistance)
			//	o.Albedo += _FoamStrength;
			
		}
		ENDCG
	}
	FallBack "Standard"
}