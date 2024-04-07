using UnityEngine;

[ExecuteInEditMode]
public class LightManager : MonoBehaviour
{

    [System.Serializable] //so we can see the struct data in the inspector for comparison
    public struct LightData
    {
        public Vector4 position;
        public Vector4 rotation;
        public Vector4 color;
        public Vector4 variables;
    }
    //constants for setting array sizes
    private const int MaxPointSpotLights = 8;
    private const int MaxDirectionalLights = 4;
    //separate arrays for directional and point/spot lights structs
    public LightData[] directionalLightsArray = new LightData[MaxDirectionalLights];
    public LightData[] pointSpotLightsArray = new LightData[MaxPointSpotLights];
    //these ints and arrays hold the information that will be transferred to the GPU once we have populated them
    public int numActiveDirectionalLights;
    public int numActivePointSpotLights;
    public Matrix4x4[] directionalLightsBuffer;
    public Matrix4x4[] pointSpotLightsBuffer;

    private void Start()
    {
        directionalLightsBuffer = new Matrix4x4[MaxDirectionalLights];
        pointSpotLightsBuffer = new Matrix4x4[MaxPointSpotLights];
    }

    public void OnVisible(Light visibleLight)
    {
        //pack light info into a struct
        LightData data;
        data = new LightData();
        data.position = new Vector4(visibleLight.transform.position.x, visibleLight.transform.position.y, visibleLight.transform.position.z, 
            visibleLight.range);
        data.color = visibleLight.color;
        data.rotation = new Vector4(visibleLight.transform.rotation.x, visibleLight.transform.rotation.y, visibleLight.transform.rotation.z, 
            1);
        data.variables.x = visibleLight.spotAngle;
        data.variables.y = visibleLight.intensity;
        //set based on light type
        if (visibleLight.GetComponent<LightVisibility>().lightType == 0) //directional
        {
            AddDirectionalLightToArray(data, visibleLight);
            data.variables.z = 0;
        }
        else if (visibleLight.GetComponent<LightVisibility>().lightType == 1) //point
        {
            AddPointSpotLightToArray(data, visibleLight);
            data.variables.z = 1;
        }
        else if (visibleLight.GetComponent<LightVisibility>().lightType == 2) //spot
        {
            AddPointSpotLightToArray(data, visibleLight);
            data.variables.z = 2;
        }

        data.variables.w = visibleLight.GetComponent<LightVisibility>().lightID;
        
        //set flags and send new data to array
        visibleLight.GetComponent<LightVisibility>().isInBuffer = true;
        visibleLight.GetComponent<LightVisibility>().wasPreviouslyVisible = false;
        UpdateBuffer();
    }

    public void OnNotVisible(Light nonVisibleLight)
    {
        //use the transform to remove from light, should change this to light id
        Vector4 nvLtransform = new Vector4(nonVisibleLight.transform.position.x, nonVisibleLight.transform.position.y,
            nonVisibleLight.transform.position.z, 1);
        //get type to remove from appropriate array
        switch (nonVisibleLight.type)
        {
            case UnityEngine.LightType.Directional:
                RemoveDirectionalLightFromArray(nvLtransform);
                break;
            default:
            {
                RemovePointSpotLightFromArray(nvLtransform);
                break;
            }
        }
        //set flags and send new data to array
        nonVisibleLight.GetComponent<LightVisibility>().isInBuffer = false;
        nonVisibleLight.GetComponent<LightVisibility>().wasPreviouslyVisible = true;
        UpdateBuffer();
    }

    private void AddDirectionalLightToArray(LightData newLight, Light directionalLight)
    {
        if (numActiveDirectionalLights >= MaxDirectionalLights) return;
        directionalLightsArray[numActiveDirectionalLights] = newLight;
        numActiveDirectionalLights++;
        //DebugData(directionalLightsArray, "sent directionalLightsArray");
    }

    private void AddPointSpotLightToArray(LightData newLight, Light pointSpotLight)
    {
        if (numActivePointSpotLights >= MaxPointSpotLights) return;
        pointSpotLightsArray[numActivePointSpotLights] = newLight;
        numActivePointSpotLights++; 
        //DebugData(pointSpotLightsArray, "sent pointSpotLightsArray");
    }

    private void RemoveDirectionalLightFromArray(Vector4 lightPosition)
    {
        int indexToRemove = -1;
        //loop till we find the light and grab it's index
        for (int i = 0; i < numActiveDirectionalLights; i++)
        {
            if (directionalLightsArray[i].position != lightPosition) continue;
            indexToRemove = i;
            break;
        }
        //if we found our index, reorder our array to 'remove' the light
        if (indexToRemove == -1) return;
        {
            for (int i = indexToRemove; i < numActiveDirectionalLights - 1; i++)
            {
                directionalLightsArray[i] = directionalLightsArray[i + 1];
            }
            numActiveDirectionalLights--;
            //  DebugData(directionalLightsArray, "sent directionalLightsArray");
        }
    }

    private void RemovePointSpotLightFromArray(Vector4 lightPosition)
    {
        int indexToRemove = -1;
        //loop till we find the light and grab it's index
        for (int i = 0; i < numActivePointSpotLights; i++)
        {
            if (pointSpotLightsArray[i].position != lightPosition) continue;
            indexToRemove = i;
            break;
        }
        //if we found our index, reorder our array to 'remove' the light
        if (indexToRemove == -1) return;
        {
            for (int i = indexToRemove; i < numActivePointSpotLights - 1; i++)
            {
                pointSpotLightsArray[i] = pointSpotLightsArray[i + 1];
            }
            numActivePointSpotLights--;
            //  DebugData(pointSpotLightsArray, "sent pointSpotLightsArray");
        }
    }

    public void UpdateLightInBuffer(Light lightToUpdate, float lightID)
    {
        if (lightToUpdate.type == UnityEngine.LightType.Directional) //directional light
        {
            //loop the array
            for (int i = 0; i < numActiveDirectionalLights - 1; i++)
            {
                //we are looking for the element with our lightID
                if (directionalLightsArray[i].variables.w != lightID) continue;
                //we found it, so let's update that element
                directionalLightsArray[i].position = new Vector4(lightToUpdate.transform.position.x, lightToUpdate.transform.position.y,
                    lightToUpdate.transform.position.z, lightToUpdate.range);
                directionalLightsArray[i].color = lightToUpdate.color;
                directionalLightsArray[i].variables.x = lightToUpdate.spotAngle;
                directionalLightsArray[i].variables.y = lightToUpdate.intensity;
                directionalLightsArray[i].variables.z = directionalLightsArray[i].variables.z;
                directionalLightsArray[i].variables.w = lightToUpdate.GetComponent<LightVisibility>().lightID;
            }
        }
        else //point/spot
        {
            //loop the array
            for (int i = 0; i < numActivePointSpotLights - 1; i++)
            {
                //we are looking for the element with our lightID
                if (pointSpotLightsArray[i].variables.w != lightID) continue;
                //we found it, so let's update that element
                pointSpotLightsArray[i].position = new Vector4(lightToUpdate.transform.position.x,
                    lightToUpdate.transform.position.y,
                    lightToUpdate.transform.position.z, lightToUpdate.range);
                pointSpotLightsArray[i].color = lightToUpdate.color;
                pointSpotLightsArray[i].variables.x = lightToUpdate.spotAngle;
                pointSpotLightsArray[i].variables.y = lightToUpdate.intensity;
                pointSpotLightsArray[i].variables.z = pointSpotLightsArray[i].variables.z;
                pointSpotLightsArray[i].variables.w = lightToUpdate.GetComponent<LightVisibility>().lightID;
            }  
        }
        //now we can update the buffer contents
        UpdateBuffer();
        Debug.Log(lightToUpdate + " triggered buffer update");
    }

    private void UpdateBuffer()
    {
        // loop directional lights, and set the columns in each light's 4x4 matrix with that light's values we stored in the array
        for (int i = 0; i < numActiveDirectionalLights; i++)
        {
            directionalLightsBuffer[i].SetRow(0, directionalLightsArray[i].position);
            directionalLightsBuffer[i].SetRow(1, directionalLightsArray[i].color);
            directionalLightsBuffer[i].SetRow(2, directionalLightsArray[i].rotation);
            directionalLightsBuffer[i].SetRow(3, directionalLightsArray[i].variables);
        }
        // loop point and spot lights, and set the columns in each light's 4x4 matrix with that light's values we stored in the array
        for (int i = 0; i < numActivePointSpotLights; i++)
        {
            pointSpotLightsBuffer[i].SetRow(0, pointSpotLightsArray[i].position);
            pointSpotLightsBuffer[i].SetRow(1, pointSpotLightsArray[i].color);
            pointSpotLightsBuffer[i].SetRow(2, pointSpotLightsArray[i].rotation);
            pointSpotLightsBuffer[i].SetRow(3, pointSpotLightsArray[i].variables);
        }
        //set the global buffers so shaders can access the data
        SendBufferToGPU();
    }

    private void SendBufferToGPU()
    {
        //send the light data to the GPU in global arrays
        Shader.SetGlobalMatrixArray("_DirectionalLightsBuffer", directionalLightsBuffer);
        Shader.SetGlobalMatrixArray("_PointSpotLightsBuffer", pointSpotLightsBuffer);
        //we need the number of objects in each array to iterate them in the shader
        Shader.SetGlobalInt("_NumDirectionalLights", numActiveDirectionalLights);
        Shader.SetGlobalInt("_NumPointSpotLights", numActivePointSpotLights);
    }
}