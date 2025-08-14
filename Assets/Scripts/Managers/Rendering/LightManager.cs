using UnityEngine;

[ExecuteInEditMode]
public class LightManager : MonoBehaviour
{
    [System.Serializable]
    public struct LightData
    {
        public Vector4 position;   // xyz=pos (or dir for dir lights), w=range
        public Vector4 rotation;   // xyz=dir (for dir/spot), w=1
        public Vector4 color;      // rgb=color, a=1
        public Vector4 variables;  // x=spotAngle (deg), y=intensity, z=type(0 dir,1 point,2 spot), w=lightID
    }

    private const int MaxPointSpotLights    = 8;
    private const int MaxDirectionalLights  = 4;

    public LightData[] directionalLightsArray = new LightData[MaxDirectionalLights];
    public LightData[] pointSpotLightsArray   = new LightData[MaxPointSpotLights];

    public int numActiveDirectionalLights;
    public int numActivePointSpotLights;

    // Packed rows (CPU-side)
    Vector4[] dirL0 = new Vector4[MaxDirectionalLights]; // pos/range or dir
    Vector4[] dirL1 = new Vector4[MaxDirectionalLights]; // color/intensity (a=1)
    Vector4[] dirL2 = new Vector4[MaxDirectionalLights]; // rotation/dir
    Vector4[] dirL3 = new Vector4[MaxDirectionalLights]; // variables

    Vector4[] psL0  = new Vector4[MaxPointSpotLights];
    Vector4[] psL1  = new Vector4[MaxPointSpotLights];
    Vector4[] psL2  = new Vector4[MaxPointSpotLights];
    Vector4[] psL3  = new Vector4[MaxPointSpotLights];

    bool _dirty;
    int _lastDirCount;
    int _lastPSCount;

    void Start()
    {
        _dirty = true;
        _lastDirCount = 0;
        _lastPSCount = 0;
    }

    // ---------- Public API ----------

    public void OnVisible(Light visibleLight)
    {
        LightData data = BuildLightData(visibleLight);

        int t = GetTypeFromData(data);
        if (t == 0) AddDirectionalLightToArray(data);
        else        AddPointSpotLightToArray(data);

        LightVisibility lv = visibleLight.GetComponent<LightVisibility>();
        if (lv != null)
        {
            lv.isInBuffer = true;
            lv.wasPreviouslyVisible = false;
        }
        _dirty = true;
    }

    public void OnNotVisible(Light nonVisibleLight)
    {
        LightVisibility lv = nonVisibleLight.GetComponent<LightVisibility>();
        if (lv != null)
        {
            if (nonVisibleLight.type == LightType.Directional) RemoveDirectionalLightById(lv.lightID);
            else                                               RemovePointSpotLightById(lv.lightID);

            lv.isInBuffer = false;
            lv.wasPreviouslyVisible = true;
        }
        _dirty = true;
    }

    public void UpdateLightInBuffer(Light lightToUpdate, float lightID)
    {
        if (lightToUpdate.type == LightType.Directional)
        {
            int idx = FindDirectionalIndexById(lightID);
            if (idx >= 0) { directionalLightsArray[idx] = BuildLightData(lightToUpdate); _dirty = true; }
        }
        else
        {
            int idx = FindPointSpotIndexById(lightID);
            if (idx >= 0) { pointSpotLightsArray[idx] = BuildLightData(lightToUpdate); _dirty = true; }
        }
    }

    /// Call once per frame after visibility updates
    public void UploadIfDirty()
    {
        FrameCounters.StartPack();

        FrameCounters.VisibleDirectional = numActiveDirectionalLights;
        FrameCounters.VisiblePointSpot   = numActivePointSpotLights;

        if (!_dirty && _lastDirCount == numActiveDirectionalLights && _lastPSCount == numActivePointSpotLights)
        {
            FrameCounters.EndPack();
            return;
        }

        // Pack rows
        int i;
        for (i = 0; i < numActiveDirectionalLights; i++)
        {
            LightData d = directionalLightsArray[i];
            dirL0[i] = d.position;   // for dir lights, store direction in rotation; position.w can be 1
            dirL1[i] = d.color;
            dirL2[i] = d.rotation;
            dirL3[i] = d.variables;
        }
        for (i = 0; i < numActivePointSpotLights; i++)
        {
            LightData d = pointSpotLightsArray[i];
            psL0[i] = d.position;
            psL1[i] = d.color;
            psL2[i] = d.rotation;
            psL3[i] = d.variables;
        }

        // Upload once
        Shader.SetGlobalVectorArray("_DirL0", dirL0);
        Shader.SetGlobalVectorArray("_DirL1", dirL1);
        Shader.SetGlobalVectorArray("_DirL2", dirL2);
        Shader.SetGlobalVectorArray("_DirL3", dirL3);

        Shader.SetGlobalVectorArray("_PSL0", psL0);
        Shader.SetGlobalVectorArray("_PSL1", psL1);
        Shader.SetGlobalVectorArray("_PSL2", psL2);
        Shader.SetGlobalVectorArray("_PSL3", psL3);

        Shader.SetGlobalInt("_NumDirectionalLights", numActiveDirectionalLights);
        Shader.SetGlobalInt("_NumPointSpotLights",  numActivePointSpotLights);

        // Counters (rough; Vector4=16 bytes per element)
        FrameCounters.GlobalSets += 10; // 8 arrays + 2 ints
        FrameCounters.BytesUploaded +=
            (numActiveDirectionalLights * 16 * 4) +
            (numActivePointSpotLights   * 16 * 4) +
            (sizeof(int) * 2);

        _lastDirCount = numActiveDirectionalLights;
        _lastPSCount  = numActivePointSpotLights;
        _dirty = false;

        FrameCounters.EndPack();
    }

    // ---------- Internals ----------

    LightData BuildLightData(Light l)
    {
        LightData data = new LightData();

        // base
        data.position = new Vector4(l.transform.position.x, l.transform.position.y, l.transform.position.z, l.range);

        Color c = l.color;
        data.color = new Vector4(c.r, c.g, c.b, 1.0f);

        Vector3 fwd = l.transform.forward;
        data.rotation = new Vector4(fwd.x, fwd.y, fwd.z, 1.0f);

        LightVisibility lv = l.GetComponent<LightVisibility>();

        float type = 1.0f; // default point
        float id   = 0.0f;
        if (lv != null)
        {
            type = lv.lightType; // 0 dir, 1 point, 2 spot
            id   = lv.lightID;
        }
        else
        {
            if (l.type == LightType.Directional) type = 0.0f;
            else if (l.type == LightType.Spot)   type = 2.0f;
            else                                  type = 1.0f;
        }

        data.variables.x = l.spotAngle;
        data.variables.y = l.intensity;
        data.variables.z = type;
        data.variables.w = id;

        return data;
    }

    static int GetTypeFromData(LightData d)
    {
        if (d.variables.z <= 0.5f) return 0;   // dir
        if (d.variables.z < 1.5f)  return 1;   // point
        return 2;                              // spot
    }

    void AddDirectionalLightToArray(LightData newLight)
    {
        if (numActiveDirectionalLights >= MaxDirectionalLights) return;
        directionalLightsArray[numActiveDirectionalLights] = newLight;
        numActiveDirectionalLights++;
    }

    void AddPointSpotLightToArray(LightData newLight)
    {
        if (numActivePointSpotLights >= MaxPointSpotLights) return;
        pointSpotLightsArray[numActivePointSpotLights] = newLight;
        numActivePointSpotLights++;
    }

    void RemoveDirectionalLightById(float lightID)
    {
        int index = FindDirectionalIndexById(lightID);
        if (index < 0) return;
        int i;
        for (i = index; i < numActiveDirectionalLights - 1; i++)
            directionalLightsArray[i] = directionalLightsArray[i + 1];
        numActiveDirectionalLights = Mathf.Max(0, numActiveDirectionalLights - 1);
    }

    void RemovePointSpotLightById(float lightID)
    {
        int index = FindPointSpotIndexById(lightID);
        if (index < 0) return;
        int i;
        for (i = index; i < numActivePointSpotLights - 1; i++)
            pointSpotLightsArray[i] = pointSpotLightsArray[i + 1];
        numActivePointSpotLights = Mathf.Max(0, numActivePointSpotLights - 1);
    }

    int FindDirectionalIndexById(float id)
    {
        int i;
        for (i = 0; i < numActiveDirectionalLights; i++)
            if (Mathf.Approximately(directionalLightsArray[i].variables.w, id)) return i;
        return -1;
    }

    int FindPointSpotIndexById(float id)
    {
        int i;
        for (i = 0; i < numActivePointSpotLights; i++)
            if (Mathf.Approximately(pointSpotLightsArray[i].variables.w, id)) return i;
        return -1;
    }
}
