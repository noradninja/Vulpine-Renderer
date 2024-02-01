using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using WSCG.Lib.Rendering;

namespace WSCG.Lighting
{


    public class ComputeBufferManager : MonoBehaviour
    {
        private static ComputeBuffer lightDataBuffer;

        private static List<LightData> lightDataList = new List<LightData>();


        private void Start()
        {
            lightDataBuffer = new ComputeBuffer(1, sizeof(float) * 10);
        }

        public static void AddLightData(LightData data)
        {
            lightDataList.Add(data);
            UpdateBuffer();
        }

        public static void RemoveLightData(LightData data)
        {
            lightDataList.Remove(data);
            UpdateBuffer();
        }

        private static void UpdateBuffer()
        {

            // Check if the buffer needs to be resized
            if (lightDataList.Count != lightDataBuffer.count)
            {
                lightDataBuffer.Release();
                lightDataBuffer = new ComputeBuffer(lightDataList.Count, sizeof(float) * 10);
            }

            // Set data to the compute buffer
            lightDataBuffer.SetData(lightDataList.ToArray());

            // Execute the command buffer to make the buffer available to shaders
            CommandBuffer commandBuffer = new CommandBuffer();
            commandBuffer.SetGlobalBuffer("_LightDataBuffer", lightDataBuffer);
            Graphics.ExecuteCommandBuffer(commandBuffer);
        }

        void OnDisable()
        {
            // Release resources when the script is disabled
            lightDataBuffer.Release();
        }
    }
}
