using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class ShadowCaster : MonoBehaviour
{
    public int targetSize = 512;
    public float shadowBias = 0.005f;

    public Camera cam;
    public RenderTexture depthTarget;

    private void OnEnable()
    {
        UpdateResources();
    }

    private void OnValidate()
    {
        UpdateResources();
    }

    private void Start()
    {
        cam = this.gameObject.AddComponent(typeof(Camera)) as Camera;
        UpdateResources();
    }

    private void UpdateResources()
    {
        if (cam != null)
        {
            cam.transform.position = this.transform.position;
            cam.transform.rotation = this.transform.rotation;
            cam.fieldOfView = this.GetComponent<Light>().spotAngle;
            cam.depth = -1000;
        }

        if (depthTarget == null || depthTarget.width != targetSize)
        {
            int sz = Mathf.Max(targetSize, 16);
            depthTarget = new RenderTexture(sz, sz, 16, RenderTextureFormat.Depth, RenderTextureReadWrite.Linear);
            depthTarget.wrapMode = TextureWrapMode.Clamp;
            depthTarget.filterMode = FilterMode.Bilinear;
            depthTarget.autoGenerateMips = false;
            depthTarget.useMipMap = false;
        }
        cam.targetTexture = depthTarget;
    }

    private void OnPostRender()
    {
        var bias = new Matrix4x4()
        {
            m00 = 0.5f, m01 = 0, m02 = 0, m03 = 0.5f,
            m10 = 0, m11 = 0.5f, m12 = 0, m13 = 0.5f,
            m20 = 0, m21 = 0, m22 = 0.5f, m23 = 0.5f,
            m30 = 0, m31 = 0, m32 = 0, m33 = 1,
        };

        Matrix4x4 view = cam.worldToCameraMatrix;
        Matrix4x4 proj = cam.projectionMatrix;
        Matrix4x4 mtx = bias * proj * view;

        Shader.SetGlobalMatrix("_ShadowMatrix", mtx);
        Shader.SetGlobalTexture("_ShadowTex", depthTarget);
        Shader.SetGlobalFloat("_ShadowBias", shadowBias);
    }
}