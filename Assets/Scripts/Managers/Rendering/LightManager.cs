using UnityEngine;
using UnityEngine.Experimental.PlayerLoop;
using UnityEngine.Serialization;

public class LightManager : MonoBehaviour
{
    [ExecuteInEditMode]
    [System.Serializable]
    public struct LightData
    {
        public Vector4 position;
        public Vector4 color;
        public Vector4 variables;
    }

    public struct AtlasData
    {
        public Vector4 quad0;
        public Vector4 quad1;
        public Vector4 quad2;
        public Vector4 quad3;
    }
   
    private const int MaxPointSpotLights = 8;
    private const int MaxDirectionalLights = 4;
    private const int MaxLightsTotal = MaxDirectionalLights + MaxPointSpotLights; //just in case we need it at some point
    //3 vec4 == 12 floats * 4 bytes == 48 bytes * 8 lights == 384 bytes/frame for 8 lights total 
    private const int LightDataSize = sizeof(float) * 12;
    //4 vec4 == 16 floats * 4 bytes == 64 bytes bytes/frame for 4 cookies total 
    private const int atlasDataSize = sizeof(float) * 16;
    private ComputeBuffer directionalLightsBuffer;
    private ComputeBuffer pointSpotLightsBuffer;

    private ComputeBuffer pointSpotAtlasBuffer;
    // Separate arrays for directional and point/spot lights
    public LightData[] directionalLightsArray = new LightData[MaxDirectionalLights];
    public LightData[] pointSpotLightsArray = new LightData[MaxPointSpotLights];
    public int numActiveDirectionalLights;
    public int numActivePointSpotLights;
    public Texture2D spotShapeCookie;
    public Texture2D flashlightShapeCookie;
    

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
        LightData data = new LightData();
        
       
        data.position = new Vector4(visibleLight.transform.position.x, visibleLight.transform.position.y, visibleLight.transform.position.z, visibleLight.intensity);
        data.color = visibleLight.color.linear;
        data.variables.x = visibleLight.range;
        data.variables.y = visibleLight.intensity;
        data.variables.z = 1;
        data.variables.w = visibleLight.GetComponent<LightVisibility>().lightID;


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
            numActiveDirectionalLights++;
            DebugData(directionalLightsArray, "sent directionalLightsArray");
        }
    }

    private void AddPointSpotLightToArray(LightData newLight, Light pointSpotLight)
    {
        if (numActivePointSpotLights < MaxPointSpotLights)
        {
            pointSpotLightsArray[numActivePointSpotLights] = newLight;
            //pointSpotCookieTextures[numActivePointSpotLights] = pointSpotLight.cookie != null ? pointSpotLight.cookie : cookiePlaceholder;
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

    public void UpdateLightInBuffer(Light lightToUpdate, float lightID)
    {
        if (lightToUpdate.type == UnityEngine.LightType.Directional) //directional light
        {
            for (int i = 0; i < numActiveDirectionalLights - 1; i++)
            {
                if (directionalLightsArray[i].variables.w == lightID)
                {
                    directionalLightsArray[i].position = new Vector4(lightToUpdate.transform.position.x, lightToUpdate.transform.position.y,
                        lightToUpdate.transform.position.z, 1);
                    directionalLightsArray[i].color = lightToUpdate.color.linear;
                    directionalLightsArray[i].variables.x = lightToUpdate.range;
                    directionalLightsArray[i].variables.y = lightToUpdate.intensity;
                    directionalLightsArray[i].variables.z = 1;
                    directionalLightsArray[i].variables.w = lightToUpdate.GetComponent<LightVisibility>().lightID; 
                }
            }
        }
        else //point/spot
        {
            for (int i = 0; i < numActivePointSpotLights - 1; i++)
            {
                if (pointSpotLightsArray[i].variables.w == lightID)
                {
                    pointSpotLightsArray[i].position = new Vector4(lightToUpdate.transform.position.x,
                        lightToUpdate.transform.position.y,
                        lightToUpdate.transform.position.z, 1);
                    pointSpotLightsArray[i].color = lightToUpdate.color.linear;
                    pointSpotLightsArray[i].variables.x = lightToUpdate.range;
                    pointSpotLightsArray[i].variables.y = lightToUpdate.intensity;
                    pointSpotLightsArray[i].variables.z = 1;
                    pointSpotLightsArray[i].variables.w = lightToUpdate.GetComponent<LightVisibility>().lightID;
                }
            }  
        }
        UpdateBuffer();
    }

    private void UpdateBuffer()
    {
        //set the data in the light buffers
        directionalLightsBuffer.SetData(directionalLightsArray);
        pointSpotLightsBuffer.SetData(pointSpotLightsArray);
        //pack 4 pointSpot cookies into an atlas
        //atlasTextures(pointSpotCookieTextures, 512, 512);
    }

    private void SendBufferToGPU()
    {
        //send the light data to the GPU
        Shader.SetGlobalBuffer("_DirectionalLightsBuffer", directionalLightsBuffer);
        Shader.SetGlobalBuffer("_PointSpotLightsBuffer", pointSpotLightsBuffer);
        //we need the number of objects in each array to iterate them in the shader
        Shader.SetGlobalInt("_NumDirectionalLights", numActiveDirectionalLights);
        Shader.SetGlobalInt("_NumPointSpotLights", numActivePointSpotLights);
        //send the spot cookie textures to a pair of global slots on the GPU
        Shader.SetGlobalTexture("_spotShapeCookie", spotShapeCookie);
        Shader.SetGlobalTexture("_flashlightShapeCookie", flashlightShapeCookie);
    }
    
    private void atlasTextures(Texture[] texturesToAtlas, int atlasWidth, int atlasHeight)
    {
        //here, I want to use Testure2D.PackTextures to take the  input textures and pack them to an output texture to pass to the GPU in a global texture
        //I also want to use Texture2D.GenerateAtlas to place the UV offsets for each of the four textures in the atlas into an AtlasData struct to send to the GPU in a global buffer 
    }
    
    //disabled to keep console clean
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
