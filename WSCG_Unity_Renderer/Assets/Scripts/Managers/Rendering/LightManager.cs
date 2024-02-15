using UnityEngine;

public class LightManager : MonoBehaviour
{
    [System.Serializable]
    public struct LightData
    {
        public Vector4 position;
        public Vector4 color;
        public Vector4 variables;
    }

   
    private const int MaxPointSpotLights = 6;
    private const int MaxDirectionalLights = 2;
    private const int MaxLightsTotal = MaxDirectionalLights + MaxPointSpotLights;
    //4 vec4 == 12 floats * 4 bytes == 48 bytes * 8 lights == 384 bytes/frame for 8 lights total 
    private const int LightDataSize = sizeof(float) * 12; 
    private ComputeBuffer directionalLightsBuffer;
    private ComputeBuffer pointSpotLightsBuffer;
   
    // Separate arrays for directional and point/spot lights
    public LightData[] directionalLightsArray = new LightData[MaxDirectionalLights];
    public LightData[] pointSpotLightsArray = new LightData[MaxPointSpotLights];
    public int numActiveDirectionalLights;
    public int numActivePointSpotLights;
    //we will pack the cookies into an atlas and set it as a global texture
    public Texture[] lightCookieTextures = new Texture[MaxLightsTotal];
    public Texture cookiePlaceholder; //set up a placeholder for light cookies if no cookie, a 1x1 white pixel
    public Texture2D atlasedLightCookies;
    

    private void Start()
    {
        directionalLightsBuffer = new ComputeBuffer(MaxDirectionalLights, LightDataSize, ComputeBufferType.Default);
        pointSpotLightsBuffer = new ComputeBuffer(MaxPointSpotLights, LightDataSize, ComputeBufferType.Default);

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
            AddDirectionalLightToArray(data, visibleLight);
        else if (visibleLight.type == UnityEngine.LightType.Point ||
                 visibleLight.type == UnityEngine.LightType.Spot)
            AddPointSpotLightToArray(data, visibleLight);

        visibleLight.GetComponent<LightVisibility>().isInBuffer = true;
        visibleLight.GetComponent<LightVisibility>().wasPreviouslyVisible = false;

        UpdateBuffer();
        SendBufferToGPU();
    }

    public void OnNotVisible(Light nonVisibleLight)
    {
        Vector4 nvLtransform = new Vector4(nonVisibleLight.transform.position.x, nonVisibleLight.transform.position.y,
            nonVisibleLight.transform.position.z, 1);

        if (nonVisibleLight.type == UnityEngine.LightType.Directional)
            RemoveDirectionalLightFromArray(nvLtransform);
        else if (nonVisibleLight.type == UnityEngine.LightType.Point || nonVisibleLight.type == UnityEngine.LightType.Point)
            RemovePointSpotLightFromArray(nvLtransform);

        nonVisibleLight.GetComponent<LightVisibility>().isInBuffer = false;
        nonVisibleLight.GetComponent<LightVisibility>().wasPreviouslyVisible = true;

        nonVisibleLight.intensity = 0;

        UpdateBuffer();
        SendBufferToGPU();
    }

    private void AddDirectionalLightToArray(LightData newLight, Light directionalLight)
    {
        if (numActiveDirectionalLights < MaxDirectionalLights)
        {
            directionalLightsArray[numActiveDirectionalLights] = newLight;
            lightCookieTextures[numActiveDirectionalLights] = directionalLight.cookie != null ? directionalLight.cookie : cookiePlaceholder; //null check doesnt set cookiePlaceholder at runtime?
            numActiveDirectionalLights++;
            DebugData(directionalLightsArray, "sent directionalLightsArray");
        }
    }

    private void AddPointSpotLightToArray(LightData newLight, Light pointSpotLight)
    {
        if (numActivePointSpotLights < MaxPointSpotLights)
        {
            pointSpotLightsArray[numActivePointSpotLights] = newLight;
            lightCookieTextures[numActivePointSpotLights] = pointSpotLight.cookie != null ? pointSpotLight.cookie : cookiePlaceholder;
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
        //set the data in the light buffers
        directionalLightsBuffer.SetData(directionalLightsArray);
        pointSpotLightsBuffer.SetData(pointSpotLightsArray);
        //pack textures into an atlas
        atlasTextures(lightCookieTextures,256);
    }

    private void SendBufferToGPU()
    {
        //send the light data to the GPU
        Shader.SetGlobalBuffer("_DirectionalLightsBuffer", directionalLightsBuffer);
        Shader.SetGlobalBuffer("_PointSpotLightsBuffer", pointSpotLightsBuffer);
        //we need the number of objects in each array to iterate them in the shader
        Shader.SetGlobalInt("_NumDirectionalLights", numActiveDirectionalLights);
        Shader.SetGlobalInt("_NumPointSpotLights", numActivePointSpotLights);
        //send the packed texture to a global texture slot on the GPU
        Shader.SetGlobalTexture("_lightCookiesAtlas", atlasedLightCookies);
        
    }
    
    private void atlasTextures(Texture[] texturesToAtlas, int atlasScale)
    {
        
    }
    
    private void DebugData(LightData[] lightDatas, string arrayName)
    {
        // Debug.Log("Debugging Data from " + arrayName + ":");
        //
        // for (int i = 0; i < MaxLightsTotal; i++)
        // {
        //     if (i < lightDatas.Length)
        //         Debug.Log("Light " + (i + 1) + ": " +
        //                   "Position: " + lightDatas[i].position +
        //                   ", Color: " + lightDatas[i].color +
        //                   ", Range: " + lightDatas[i].variables.x +
        //                   ", Intensity: " + lightDatas[i].variables.y);
        //     else
        //         Debug.Log("Light " + (i + 1) + ": Inactive");
        // }
    }
}
