using System;
using UnityEngine;
using UnityEngine.Serialization;

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
        [SerializeField] private Light[] _lights;
        [Header("Light Position")]
        //vectors to pack position for four lights 
        public Vector4 lightPosX;
        public Vector4 lightPosY;
        public Vector4 lightPosZ;
        [Header("Light Color")]
        //vectors to pack rgb color values for four lights
        public Vector4 lightColorR;
        public Vector4 lightColorG;
        public Vector4 lightColorB;
        [Header("Light Properties")]
        //we are packing intensity for four lights in w 
        public Vector4 lightIntensityA;
        //we are packing range for four lights in w 
        public Vector4 lightRangeW;
        //Lighting data structure
        public LightingData[] LightData;
        
    
        public static bool ListIsDirty = true;
        public int _lightDataSetLength;
        public static int _totalLights;
        public bool dirtyFlag = ListIsDirty;

        public bool[] usedSlot = UsedSlots;
        //GPU data buffer
        private ComputeBuffer _lightingDataBuffer;

        private void Start()
        {
            //set up all our light data for passing to the GPU structured buffer
            _lightDataSetLength = MaxLights / 4;
            _totalLights = MaxLights * _lightDataSetLength;
            UsedSlots = new bool[_totalLights];
            Lights = new Light[_totalLights]; 
            _lights = new Light[_totalLights];
            LightData = new LightingData[_lightDataSetLength];
            if (ListIsDirty)
                PackLightingData(LightData, _lightDataSetLength-1);
            
            _lightingDataBuffer = new ComputeBuffer(_lightDataSetLength, LightingData.GetSize());
            _lightingDataBuffer.SetData(LightData); 
        }
        
        // Update is called once per frame
        private void Update()
        {
            // //if a flag is removed, added, or changed
            // if (ListIsDirty)
            //     PackLightingData(LightData, _lightDataSetLength-1);
        }
        
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
        
        public void PackLightingData(LightingData[] lightingDataStruct, int lightingDataStructCount)
        {
            dirtyFlag = ListIsDirty;
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
            
            lightColorG = new Vector4(Lights[0].color.g,
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
             _lights = Lights;
             ListIsDirty = false;
             dirtyFlag = ListIsDirty;
        }
    }
}
