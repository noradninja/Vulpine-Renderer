using System;
using UnityEngine;
using UnityEngine.Serialization;

namespace WSCG
{
    public class LightBufferManager : MonoBehaviour
    {
        //set max light count onscreen, create array to hold lights
        //lights will add themselves to the array, based on if the bounds of their range falls within the screen, see LightManager.cs

        public static readonly int MaxLights = 4;
        public static Vector4 UsedSlots = Vector4.zero;
        public static Vector4 ScreenSpaceLightDistances = Vector4.zero;
        // ReSharper disable once FieldCanBeMadeReadOnly.Global
        public static Light[] Lights = new Light[MaxLights];
        
        //vectors to pack position for four lights 
        public Vector4 lightPosX;
        public Vector4 lightPosY;
        public Vector4 lightPosZ;
        //we are packing range for four lights in w 
        public Vector4 lightRangeW;

        //vectors to pack rgb color values for four lights
        public Vector4 lightColorR;
        public Vector4 lightColorG;
        public Vector4 lightColorB;
        //we are packing intensity for four lights in w 
        public Vector4 lightIntensityA;

        //Lighting data structure
        public LightingData[] _lightData;
        private int _lightDataSetLength;
        public static bool listIsDirty = true;

        //GPU data buffer
        private ComputeBuffer _lightingDataBuffer;

        private void Start()
        {
            //grab all our light data for passing to the GPU structured buffer
            _lightDataSetLength = (MaxLights / 4);
            _lightData = new LightingData[_lightDataSetLength - 1];
            if (listIsDirty)
                PackLightingData(_lightData, _lightDataSetLength - 1);

            /// IF I SET THE ABOVE new LightingData[] TO SIZE 0, I GET ONE COPY OF THE STRUCT, YES? IF I SET IT TO SIZE n, DOES IT RETURN n STRUCT'S, EACH CONTAINING UNIQUE INSTANCES OF THE VECTOR4'S THEY CONTAIN? IN EFFECT, AN ARRAY OF STRUCTS?

            _lightingDataBuffer = new ComputeBuffer(MaxLights, LightingData.GetSize() * _lightDataSetLength);
            _lightingDataBuffer.SetData(_lightData); 
        }
        
        // Update is called once per frame
        private void Update()
        {
            //if a flag is removed, added, or changed
            if (listIsDirty)
                PackLightingData(_lightData, _lightDataSetLength - 1);
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
             listIsDirty = false;
        }
    }
}
