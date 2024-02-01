using System.Collections.Generic;
using UnityEngine;
using WSCG.Lib;
using WSCG.Lib.Rendering;

namespace WSCG.Lighting
{
    public class LightManager : MonoBehaviour
    {
        private List<LightData> visibleLightsData = new List<LightData>();
        private List<Light> visibleLights = new List<Light>();
        private LightData data = new LightData();

        public void OnVisible(Light light)
        {
            light.intensity = 25;
            // Add light data to the list
            data.position = light.transform.position;
            data.color = new Vector4(light.color.r, light.color.g, light.color.b, 1.0f);
            data.intensityRange = new Vector2(light.intensity, light.range);
            visibleLightsData.Add(data);

            // Sort lights by distance to the camera
            visibleLightsData.Sort((a, b) =>
                Vector3.Distance(Camera.main.transform.position, a.position)
                    .CompareTo(Vector3.Distance(Camera.main.transform.position, b.position)));
            visibleLights.Add(light);
            // Keep only the closest 6 lights
            visibleLightsData = visibleLightsData.GetRange(0, Mathf.Min(visibleLightsData.Count, 6));

            // Set isInBuffer boolean for lights
            light.GetComponent<LightVisibility>().isVisible = true;
            light.GetComponent<LightVisibility>().isInBuffer = true;
            ComputeBufferManager.AddLightData(data);
            Debug.Log(light.name + " added to buffer");
        }

        public void OnNotVisible(Light light)
        {
            light.intensity = 0;
            // Remove light data from the list
            visibleLightsData.RemoveAll(data => data.position == this.data.position);

            // Set isInBuffer boolean for lights
            light.GetComponent<LightVisibility>().isVisible = false;
            light.GetComponent<LightVisibility>().isInBuffer = false;
            ComputeBufferManager.RemoveLightData(data);
            Debug.Log(light.name + " removed from buffer");
        }
    }
}
