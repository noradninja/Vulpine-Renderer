using UnityEngine;

public class LightManager : MonoBehaviour
{
    public enum LightType
    {
        Directional,
        PointSpot
    }

    [System.Serializable]
    public struct LightData
    {
        public Vector4 position;
        public Vector4 color;
        public Vector4 variables;
    }

    private const int MaxLights = 8;
    private const int LightDataSize = sizeof(float) * 12;

    // Separate arrays for directional and point/spot lights
    public LightData[] directionalLightsArray = new LightData[MaxLights];
    public LightData[] pointSpotLightsArray = new LightData[MaxLights];

    private ComputeBuffer directionalLightsBuffer;
    private ComputeBuffer pointSpotLightsBuffer;

    public int numActiveDirectionalLights;
    public int numActivePointSpotLights;

    private void Start()
    {
        directionalLightsBuffer = new ComputeBuffer(MaxLights, LightDataSize, ComputeBufferType.Default);
        pointSpotLightsBuffer = new ComputeBuffer(MaxLights, LightDataSize, ComputeBufferType.Default);
        
        UpdateBuffer();
        SendBufferToGPU();
    }



    private void OnDestroy()
    {
        directionalLightsBuffer.Release();
        pointSpotLightsBuffer.Release();
    }

    public void OnVisible(Light visibleLight)
    {
        visibleLight.intensity = 3;
        LightData data = new LightData();

        data.position = new Vector4(visibleLight.transform.position.x, visibleLight.transform.position.y, visibleLight.transform.position.z, 1);
        data.color = visibleLight.color.linear;
        data.variables.x = visibleLight.range;
        data.variables.y = visibleLight.intensity;
        data.variables.z = 1;
        data.variables.w = 1;

        if (visibleLight.type == UnityEngine.LightType.Directional)
        {
            AddDirectionalLightToArray(data);
        }
        else if (visibleLight.type == UnityEngine.LightType.Point||

                 visibleLight.type == UnityEngine.LightType.Spot)
        {
            AddPointSpotLightToArray(data);
        }

        visibleLight.GetComponent<LightVisibility>().isInBuffer = true;
        visibleLight.GetComponent<LightVisibility>().wasPreviouslyVisible = false;

        UpdateBuffer();
        SendBufferToGPU();
    }

    public void OnNotVisible(Light nonVisibleLight)
    {
        LightData dataToRemove = new LightData();
        Vector4 NVLtransform = new Vector4(nonVisibleLight.transform.position.x, nonVisibleLight.transform.position.y,
            nonVisibleLight.transform.position.z, 1);

        if (nonVisibleLight.type == UnityEngine.LightType.Directional)
        {
            RemoveDirectionalLightFromArray(NVLtransform);
        }
        else if (nonVisibleLight.type == UnityEngine.LightType.Point || nonVisibleLight.type == UnityEngine.LightType.Point)
        {
            RemovePointSpotLightFromArray(NVLtransform);
        }

        nonVisibleLight.GetComponent<LightVisibility>().isInBuffer = false;
        nonVisibleLight.GetComponent<LightVisibility>().wasPreviouslyVisible = true;

        nonVisibleLight.intensity = 0;

        UpdateBuffer();
        SendBufferToGPU();
    }

    private void AddDirectionalLightToArray(LightData newLight)
    {
        if (numActiveDirectionalLights < MaxLights)
        {
            directionalLightsArray[numActiveDirectionalLights] = newLight;
            numActiveDirectionalLights++;
            DebugData(directionalLightsArray, "sent directionalLightsArray");
        }
    }

    private void AddPointSpotLightToArray(LightData newLight)
    {
        if (numActivePointSpotLights < MaxLights)
        {
            pointSpotLightsArray[numActivePointSpotLights] = newLight;
            numActivePointSpotLights++;
            DebugData(pointSpotLightsArray, "sent pointSpotLightsArray");
        }
    }

    private void RemoveDirectionalLightFromArray(Vector4 lightPosition)
    {
        int indexToRemove = -1;

        for (int i = 0; i < numActiveDirectionalLights; i++)
        {
            if (directionalLightsArray[i].position == lightPosition)
            {
                indexToRemove = i;
                break;
            }
        }

        if (indexToRemove != -1)
        {
            for (int i = indexToRemove; i < numActiveDirectionalLights - 1; i++)
            {
                directionalLightsArray[i] = directionalLightsArray[i + 1];
            }
            numActiveDirectionalLights--;
            DebugData(directionalLightsArray, "sent directionalLightsArray");
        }
    }

    private void RemovePointSpotLightFromArray(Vector4 lightPosition)
    {
        int indexToRemove = -1;

        for (int i = 0; i < numActivePointSpotLights; i++)
        {
            if (pointSpotLightsArray[i].position == lightPosition)
            {
                indexToRemove = i;
                break;
            }
        }

        if (indexToRemove != -1)
        {
            for (int i = indexToRemove; i < numActivePointSpotLights - 1; i++)
            {
                pointSpotLightsArray[i] = pointSpotLightsArray[i + 1];
            }
            numActivePointSpotLights--;
            DebugData(pointSpotLightsArray, "sent pointSpotLightsArray");
        }
    }

    private void UpdateBuffer()
    {
        //set the data in the buffer
        directionalLightsBuffer.SetData(directionalLightsArray);
        pointSpotLightsBuffer.SetData(pointSpotLightsArray);
        
    }

    private void SendBufferToGPU()
    {
        //send the data to the GPU
        Shader.SetGlobalBuffer("_DirectionalLightsBuffer", directionalLightsBuffer);
        Shader.SetGlobalBuffer("_PointSpotLightsBuffer", pointSpotLightsBuffer);
        Shader.SetGlobalInt("_NumDirectionalLights", numActiveDirectionalLights);
        Shader.SetGlobalInt("_NumPointSpotLights", numActivePointSpotLights);
    }
    
    private void DebugData(LightData[] lightDatas, string arrayName)
    {
        Debug.Log("Debugging Data from " + arrayName + ":");

        for (int i = 0; i < MaxLights; i++)
        {
            if (i < lightDatas.Length)
            {
                Debug.Log("Light " + (i + 1) + ": " +
                          "Position: " + lightDatas[i].position +
                          ", Color: " + lightDatas[i].color +
                          ", Range: " + lightDatas[i].variables.x +
                          ", Intensity: " + lightDatas[i].variables.y);
            }
            else
            {
                Debug.Log("Light " + (i + 1) + ": Inactive");
            }
        }
    }
}
