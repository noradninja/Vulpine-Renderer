using System;
using UnityEngine;
using UnityEngine.Serialization;
using UnityEngine.SocialPlatforms;

namespace WSCG.Managers
{
    public class LightBufferManager : MonoBehaviour
    {
        //set max light count onscreen, create array to hold lights
        //lights will add themselves to the array, based on if the bounds of their range falls within the screen, see LightManager.cs

        public static int MaxLights = 4;
        public static bool[] UsedSlots;
        public static Vector4 ScreenSpaceLightDistances = Vector4.zero;
        // ReSharper disable once FieldCanBeMadeReadOnly.Global
        public static Light[] Lights;
        public static float visibilityBuffer; //value for camera buffer scale
        [Range(0.0f,1.0f)] public float frustumOverscan;
        public Light[] lights;//for debug 
        [Header("Light Position")]
        //vectors to pack position for four lights 
        public static Vector4 lightPosX;
        public static Vector4 lightPosY;
        public static Vector4 lightPosZ;
        [Header("Light Color")]
        //vectors to pack rgb color values for four lights
        public static Vector4 lightColorR;
        public static Vector4 lightColorG;
        public static Vector4 lightColorB;
        [Header("Light Properties")]
        //we are packing intensity for four lights in w 
        public static Vector4 lightIntensityA;
        //we are packing range for four lights in w 
        public static Vector4 lightRangeW;
        //Lighting data structure
        public static LightingData[] LightData;
        
    
        public static bool listIsDirty;
        public int lightDataSetLength;
        public static int TotalLights;
        private static ComputeBuffer _lightingDataBuffer;

    //light
        public Light lightObject;

        
        private Vector3 _lightCenter;
        private float _lightRadius;
        private static bool _isInBuffer; 
   
		public struct LightingData
        {
	        //vectors to pack position for four lights
	        public Vector4 LightPosX;
	        public Vector4 LightPosY;

	        public Vector4 LightPosZ;

	        //we are packing range for four lights in w
	        public Vector4 LightRangeW;

	        //vectors to pack rgb color values for four lights
	        public Vector4 LightColorR;
	        public Vector4 LightColorG;

	        public Vector4 LightColorB;

	        //we are packing intensity for four lights in w
	        public Vector4 LightIntensityA;

	        //we return sizeof(float) because sizeof(Vector4) is unsafe. 4 floats * 8 Vectors = 32 floats * 4 bytes/float = 128 bytes/frame
	        public static int GetSize()
	        {
		        return sizeof(float) * 4 * 8;
	        }
        }
		
        private void Start()
        {
            //set up all our light data for passing to the GPU structured buffer
            lightDataSetLength = MaxLights / 4;
            TotalLights = MaxLights * lightDataSetLength;
            UsedSlots = new bool[TotalLights];
            Lights = new Light[TotalLights]; 
            lights = new Light[TotalLights];
            LightData = new LightingData[lightDataSetLength];
            //_lightingDataBuffer = new ComputeBuffer(lightDataSetLength, LightingData.GetSize());
        }

     
        // Update is called once per frame
        private void Update()
        {
	        visibilityBuffer = frustumOverscan;
	        lights = Lights;
        }


        public static void CheckCameraView(Light lightToCheck, Camera camToCheck)
        {
	        _isInBuffer = new bool();
	        _isInBuffer = lightToCheck.GetComponent<LightCluster>()._isInBuffer;
	        int lightIndex = lightToCheck.GetComponent<LightCluster>().indexValue;
	        float lightRange = lightToCheck.range;
	        Transform lightTransform = lightToCheck.transform;
	        Vector3 lightPos = lightTransform.position;
	        Vector3 lightDirection = lightTransform.forward;
	        Vector3 lightArea = lightPos + lightDirection * lightRange;
	        Bounds lightBounds = new Bounds(lightPos, lightArea);
	        lightBounds.Expand(visibilityBuffer);

	        // Check if the expanded light bounds intersect with the camera's frustum
	        if (GeometryUtility.TestPlanesAABB(GeometryUtility.CalculateFrustumPlanes(camToCheck), lightBounds))
	        {
		        // Light is visible or partially visible, do something
		        Debug.Log("Light is visible or partially visible");
		        if (!_isInBuffer && lightIndex == 9)
			        AddLight(lightToCheck);
	        }
	        else
	        {
		        // Light is not visible, do something else
		        Debug.Log("Light is just outside the view frustum");
		        if (_isInBuffer && lightIndex != 9)
			        RemoveLight(lightToCheck, lightIndex);
	        }
        }
        
        private static void PackLightingData(LightingData[] lightingDataStruct, int lightingDataStructCount)
        {
	        //XYZ light positions for four lights, packed by axis 
            lightPosX = new Vector4(
                Lights[0].transform.position.x,
                Lights[1].transform.position.x,
                Lights[2].transform.position.x,
                Lights[3].transform.position.x
            );
             lightingDataStruct[lightingDataStructCount].LightPosX = lightPosX;
            
            lightPosY = new Vector4(
                Lights[0].transform.position.y,
                Lights[1].transform.position.y,
                Lights[2].transform.position.y,
                Lights[3].transform.position.y
            );
             lightingDataStruct[lightingDataStructCount].LightPosY = lightPosY;
            
            lightPosZ = new Vector4(
                Lights[0].transform.position.z,
                Lights[1].transform.position.z,
                Lights[2].transform.position.z,
                Lights[3].transform.position.z
            );
             lightingDataStruct[lightingDataStructCount].LightPosZ = lightPosZ;
            
            //range for four lights, packed
            lightRangeW = new Vector4(
                Lights[0].range,
                Lights[1].range,
                Lights[2].range,
                Lights[3].range
            );
             lightingDataStruct[lightingDataStructCount].LightRangeW = lightRangeW;
            
            //RGB light colors for four lights, packed by channel 
            lightColorR = new Vector4(
                Lights[0].color.r,
                Lights[1].color.r,
                Lights[2].color.r,
                Lights[3].color.r
            );
             lightingDataStruct[lightingDataStructCount].LightColorR = lightColorR;
            
            lightColorG = new Vector4(
                Lights[0].color.g,
                Lights[1].color.g,
                Lights[2].color.g,
                Lights[3].color.g
            );
             lightingDataStruct[lightingDataStructCount].LightColorG = lightColorG;

            lightColorB = new Vector4(
                Lights[0].color.b,
                Lights[1].color.b,
                Lights[2].color.b,
                Lights[3].color.b
            );
             lightingDataStruct[lightingDataStructCount].LightColorB = lightColorB;

            //intensity for four lights, packed
            lightIntensityA = new Vector4(
                Lights[0].intensity,
                Lights[1].intensity,
                Lights[2].intensity,
                Lights[3].intensity
            );
             lightingDataStruct[lightingDataStructCount].LightIntensityA = lightIntensityA;
             listIsDirty = false;
             _lightingDataBuffer.SetData(LightData); 
        }

        private static void AddLight(Light lightToAdd)
		{
		
			_isInBuffer = new bool();
			_isInBuffer = lightToAdd.GetComponent<LightCluster>()._isInBuffer;
			
			if (_isInBuffer)
				Debug.Log(lightToAdd.name + " is already in buffer.");
			else
			{
				// 	CompareDistancesForCulling(lightToAdd, distance); //if there isn't an empty spot is a light further away than this?
				for (int l = 0; l < TotalLights; l++) //spin slot array
				{
					if (UsedSlots[l] == false)
					{
						//the spot is empty
						lightToAdd.GetComponent<LightCluster>()._isInBuffer = true; //toggle the boolean
						UsedSlots[l] = true; //set our slot to used
						Lights[l] = lightToAdd; //add this light to object array
						lightToAdd.GetComponent<LightCluster>().indexValue = l;
						listIsDirty = true; //flag light list data for refresh
						Debug.Log(lightToAdd.name + " added to buffer in slot " + l);
						Debug.Log("Available slots: " + UsedSlots);
						lightToAdd.intensity = 25; //DEBUG: turn light on to see we added this
						break; //escape out as we have been added to the list
					}
					//PackLightingData(LightData, TotalLights);
				}
			}
		}

        private static void RemoveLight(Light lightToRemove, int lightIndex)
		{
			_isInBuffer = false; //toggle the boolean
			UsedSlots[lightIndex] = false; //set the bool component to 0 so it is 'available'
			lightToRemove.GetComponent<LightCluster>()._isInBuffer = false;
			lightToRemove.GetComponent<LightCluster>().indexValue = 9;
			Debug.Log(lightToRemove.name + " removed from buffer " + lightIndex);
			Debug.Log("Available slots: " + UsedSlots);
			Lights[lightIndex] = null; //remove this light from object list
		}
    }
}
