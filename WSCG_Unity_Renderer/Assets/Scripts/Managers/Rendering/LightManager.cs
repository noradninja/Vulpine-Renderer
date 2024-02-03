using System;
using UnityEngine;
using UnityEngine.Rendering;

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
        public Vector3 position;
        public Vector4 color;
        public float range;
        public float intensity;
        public float lightType;
    }

    private const int MaxLights = 8;
    private const int LightDataSize = sizeof(float) * 10; // Total size of LightData in bytes = 4 bytes/float * (3 + 4 + 1 + 1 + 1)
    public LightData[] lightsArray = new LightData[MaxLights];
    private ComputeBuffer lightDataBuffer;
    private int numActiveLights;

    private void Start()
    {
        lightDataBuffer = new ComputeBuffer(MaxLights, LightDataSize);
        UpdateBuffer();
    }

    private void OnDestroy()
    {
        lightDataBuffer.Release();
    }

    public void OnVisible(Light visibleLight)
    {
        visibleLight.intensity = 25;
        LightData data = new LightData
        {
            position = visibleLight.transform.position,
            color = visibleLight.color.linear,
            range = visibleLight.range,
            intensity = visibleLight.intensity,
            lightType = (float)visibleLight.type
        };

        AddLightToArray(data);
        visibleLight.GetComponent<LightVisibility>().isInBuffer = true;
        visibleLight.GetComponent<LightVisibility>().wasPreviouslyVisible = false;

        UpdateBuffer();
    }

    public void OnNotVisible(Light nonVisibleLight)
    {
        LightData dataToRemove = new LightData();

        for (int i = 0; i < numActiveLights; i++)
        {
            if (lightsArray[i].position == nonVisibleLight.transform.position)
            {
                dataToRemove = lightsArray[i];
                break;
            }
        }

        RemoveLightFromArray(dataToRemove);
        nonVisibleLight.GetComponent<LightVisibility>().isInBuffer = false;
        nonVisibleLight.GetComponent<LightVisibility>().wasPreviouslyVisible = true;

        nonVisibleLight.intensity = 0;

        UpdateBuffer();
    }

    private void AddLightToArray(LightData newLight)
    {
        if (numActiveLights >= MaxLights)
        {
            float maxDistance = 0f;
            int indexToRemove = 0;

            for (int i = 0; i < numActiveLights; i++)
            {
                float distance = Vector3.Distance(lightsArray[i].position, Camera.main.transform.position);
                if (distance > maxDistance)
                {
                    maxDistance = distance;
                    indexToRemove = i;
                }
            }

            lightsArray[indexToRemove] = newLight;
        }
        else
        {
            lightsArray[numActiveLights] = newLight;
            numActiveLights++;
        }
    }

    private void RemoveLightFromArray(LightData lightToRemove)
    {
        int indexToRemove = -1;

        for (int i = 0; i < numActiveLights; i++)
        {
            if (lightsArray[i].position == lightToRemove.position)
            {
                indexToRemove = i;
                break;
            }
        }

        if (indexToRemove != -1)
        {
            for (int i = indexToRemove; i < numActiveLights - 1; i++)
            {
                lightsArray[i] = lightsArray[i + 1];
            }
            numActiveLights--;
        }
    }

    private void UpdateBuffer()
    {
        lightDataBuffer.SetData(lightsArray);
        Shader.SetGlobalBuffer("_LightDataBuffer", lightDataBuffer);
        Shader.SetGlobalInt("_NumActiveLights", numActiveLights);

        // Debug log the data in the lightDataBuffer with byte offsets
        byte[] debugData = new byte[sizeof(float) * 10 * MaxLights];
        lightDataBuffer.GetData(debugData);

        Debug.Log("Debugging LightDataBuffer:");

        for (int i = 0; i < numActiveLights; i++)
        {
            int byteOffset = i * sizeof(float) * 10;

            float posX = BitConverter.ToSingle(debugData, byteOffset);
            float posY = BitConverter.ToSingle(debugData, byteOffset + sizeof(float));
            float posZ = BitConverter.ToSingle(debugData, byteOffset + 2 * sizeof(float));

            float colorR = BitConverter.ToSingle(debugData, byteOffset + 3 * sizeof(float));
            float colorG = BitConverter.ToSingle(debugData, byteOffset + 4 * sizeof(float));
            float colorB = BitConverter.ToSingle(debugData, byteOffset + 5 * sizeof(float));
            float colorA = BitConverter.ToSingle(debugData, byteOffset + 6 * sizeof(float));

            float range = BitConverter.ToSingle(debugData, byteOffset + 7 * sizeof(float));
            float intensity = BitConverter.ToSingle(debugData, byteOffset + 8 * sizeof(float));
            float lightType = BitConverter.ToSingle(debugData, byteOffset + 9 * sizeof(float));

            Debug.Log("Light " + (i + 1) + ":");
            Debug.Log("Position: " + new Vector3(posX, posY, posZ) + " Color: " + new Color(colorR, colorG, colorB, colorA) + " Range: " + range + " Intensity: " + intensity + " LightType: " + lightType);
        }
    }
}
