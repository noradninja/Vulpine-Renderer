using UnityEngine;
using UnityEngine.Serialization;

namespace WSCG
{
    public class LightBufferManager : MonoBehaviour
    {
        //set max light count onscreen, create array to hold lights
        //lights will add themselves to the array, based on if the bounds of their range falls within the screen,
        //see LightManager.cs

        public static int MaxLights = 4;
        public static Vector4 usedSlots = Vector4.zero;
        public static Light[] Lights = new Light[MaxLights];
        
        //vectors to pack position for four lights 
        public Vector4 lightPosX;
        public Vector4 lightPosY;
        public Vector4 lightPosZ;
        //we are packing range for four lights in w 
        public Vector4 lightPosW;

        //vectors to pack rgb color values for four lights
        public Vector4 lightColorR;
        public Vector4 lightColorG;
        public Vector4 lightColorB;
        //we are packing intensity for four lights in w 
        public Vector4 lightColorA;

        //Lighting data structure
        private LightingData[] _lightData;

        //GPU data buffer
        private ComputeBuffer _lightingDataBuffer;

        private void Start()
        {
            //grab all our light data for passing to the GPU structured buffer
            
            //XYZ light positions for four lights, packed by axis 
            lightPosX = new Vector4(
                Lights[0].transform.position.x,
                Lights[1].transform.position.x,
                Lights[2].transform.position.x,
                Lights[3].transform.position.x
            );
            lightPosY = new Vector4(
                Lights[0].transform.position.y,
                Lights[1].transform.position.y,
                Lights[2].transform.position.y,
                Lights[3].transform.position.y
            );
            lightPosZ = new Vector4(
                Lights[0].transform.position.z,
                Lights[1].transform.position.z,
                Lights[2].transform.position.z, 
                Lights[3].transform.position.z
            );
            //range for four lights, packed
            lightPosW = new Vector4(
                Lights[0].range,
                Lights[1].range,
                Lights[2].range,
                Lights[3].range
            );
            //RGB light colors for four lights, packed by channel 
            lightColorR = new Vector4(
                Lights[0].color.r,
                Lights[1].color.r,
                Lights[2].color.r,
                Lights[3].color.r
            );
            lightColorG = new Vector4(Lights[0].color.g,
                Lights[1].color.g,
                Lights[2].color.g,
                Lights[3].color.g
            );
            lightColorB = new Vector4(
                Lights[0].color.b,
                Lights[1].color.b,
                Lights[2].color.b,
                Lights[3].color.b
            );
            //intensity for four lights, packed
            lightColorA = new Vector4(
                Lights[0].intensity,
                Lights[1].intensity,
                Lights[2].intensity,
                Lights[3].intensity
            );

            _lightingDataBuffer = new ComputeBuffer(MaxLights, LightingData.GetSize());
        }

        // Update is called once per frame
        private void Update()
        {
            _lightData = new LightingData[1];
            _lightingDataBuffer.SetData(_lightData);
        }

        private struct LightingData
        {
            //vectors to pack position for four lights
            public Vector4 LightPosX;
            public Vector4 LightPosY;
            public Vector4 LightPosZ;
            //we are packing range for four lights in w
            public Vector4 LightPosW;

            //vectors to pack rgb color values for four lights
            public Vector4 LightColorR;
            public Vector4 LightColorG;
            public Vector4 LightColorB;
            //we are packing intensity for four lights in w
            public Vector4 LightColorA;

            //we return sizeof(float) because sizeof(Vector4) is unsafe. 4 floats * 8 Vectors = 32 floats * 4 bytes/float = 128 bytes/frame
            public static int GetSize()
            {
                return sizeof(float) * 4 * 8;
            }
        }
    }
}
