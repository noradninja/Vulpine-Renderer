using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace WSCG
{
	public class LightBufferManager : MonoBehaviour
	{
		//set max light count onscreen, create array to hold lights
		//lights will add themselves to the array, based on if the AABB of their range falls within the screen
		
		private static int maxLights = 4;
		public Light[] lights = new Light[maxLights];
		
		//vectors to pack position for four lights
		public Vector4 lightPosX;
		public Vector4 lightPosY;
		public Vector4 lightPosZ;
		//we are packing range for four lights in w for our shader to use, so we store it here to pass along
		public Vector4 lightPosW;
		
		//vectors to pack rgb color values for four lights
		public Vector4 lightColorR;
		public Vector4 lightColorG;
		public Vector4 lightColorB;
		//we are packing intensity for four lights in w for our shader to use, so we store it here to pass along
		public Vector4 lightColorA;
		
		//GPU buffer
		private ComputeBuffer lightingDataBuffer;
		 
		void Start() //grab all our light data for passing to the structured buffer
		{
			//XYZ light positions for four lights, packed by axis 
			lightPosX = new Vector4(lights[0].transform.position.x,
				                  lights[1].transform.position.x,
				                  lights[2].transform.position.x,
				                  lights[3].transform.position.x);
			
			lightPosY = new Vector4(lights[0].transform.position.y,
									  lights[1].transform.position.y,
								    lights[2].transform.position.y,
									lights[3].transform.position.y);
			
			lightPosZ = new Vector4(lights[0].transform.position.z,
									lights[1].transform.position.z,
									  lights[2].transform.position.z,
									lights[3].transform.position.z);
			//range for four lights, packed
			lightPosW= new Vector4(lights[0].range,
								   lights[1].range,
								   lights[2].range,
								  lights[3].range);
			//XYZ light colors for four lights, packed by channel 
			lightColorR	 = new Vector4(lights[0].color.r,
									   lights[1].color.r,
									   lights[2].color.r,
									   lights[3].color.r);
			
			lightColorG = new Vector4(lights[0].color.g,
									  lights[1].color.g,
									  lights[2].color.g,
									  lights[3].color.g);
			
			lightColorB = new Vector4(lights[0].color.b,
									  lights[1].color.b,
									  lights[2].color.b,
									 lights[3].color.b);
			//intensity for four lights, packed
			lightColorA = new Vector4(lights[0].intensity,
									  lights[1].intensity,
									  lights[2].intensity,
									 lights[3].intensity);

			lightingDataBuffer = new ComputeBuffer(maxLights, LightingData.GetSize());
		}
		// Update is called once per frame
		void Update() //here is where we will set up our command buffers for passing the above data to our shader
		{
			
			// ReSharper disable once RedundantJumpStatement
			return;
		}

		public struct LightingData
		{
			//vectors to pack position for four lights
			public Vector4 lightPosX;
			public Vector4 lightPosY;
			public Vector4 lightPosZ;
			//we are packing range for four lights in w for our shader to use, so we store it here to pass along
			public Vector4 lightPosW;
		
			//vectors to pack rgb color values for four lights
			public Vector4 lightColorR;
			public Vector4 lightColorG;
			public Vector4 lightColorB;
			//we are packing intensity for four lights in w for our shader to use, so we store it here to pass along
			public Vector4 lightColorA;
			public static int GetSize()
			{
				return sizeof(Vector4) * 8;
			}
		}
		
	}
}
