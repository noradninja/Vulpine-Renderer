using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[DisallowMultipleComponent]
public class VulpineRendererOrchestrator : MonoBehaviour
{
    [Header("Camera / Layers")]
    [SerializeField] Camera targetCamera;
    [SerializeField] LayerMask renderLayerMask = ~0;
    [SerializeField] LayerMask depthPrepassMask = 0;

    [Header("Materials")]
    [SerializeField] Material depthOnlyMaterial; // ZWrite On, ColorMask 0, same alpha clip as main shader
    [SerializeField] Material postMaterial;      // optional single-pass post

    [Header("Toggles")]
    [SerializeField] bool enableDepthPrepass = true;
    [SerializeField] bool enablePost = false;

    [Header("References")]
    [SerializeField] LightManager lightManager;

    // Command buffers
    CommandBuffer cbDepth;
    CommandBuffer cbOpaque;
    CommandBuffer cbAlphaTest;
    CommandBuffer cbTransparent;
    CommandBuffer cbPost;

    // Reused lists (avoid GC)
    readonly List<Renderer> _opaque = new List<Renderer>(1024);
    readonly List<Renderer> _alphaTest = new List<Renderer>(512);
    readonly List<Renderer> _transparent = new List<Renderer>(512);

    // Comparers (front-to-back for opaque/alpha, back-to-front for transparent)
    static readonly IComparer<Renderer> OpaqueSorter = new OpaqueComparer();
    static readonly IComparer<Renderer> AlphaTestSorter = new OpaqueComparer();
    static readonly IComparer<Renderer> TransparentSorter = new TransparentComparer();

    void Reset()
    {
        targetCamera = GetComponent<Camera>();
        if (lightManager == null) lightManager = FindObjectOfType<LightManager>();
    }

    void OnEnable()
    {
        if (targetCamera == null) targetCamera = GetComponent<Camera>();
        if (targetCamera == null)
        {
            Debug.LogError("VulpineRendererOrchestrator: No Camera assigned.");
            enabled = false;
            return;
        }

        // Prevent built-in render: we’ll draw everything via CBs
        targetCamera.cullingMask = 0;

        cbDepth       = new CommandBuffer(); cbDepth.name       = "Vulpine/DepthPrepass";
        cbOpaque      = new CommandBuffer(); cbOpaque.name      = "Vulpine/Opaque";
        cbAlphaTest   = new CommandBuffer(); cbAlphaTest.name   = "Vulpine/AlphaTest";
        cbTransparent = new CommandBuffer(); cbTransparent.name = "Vulpine/Transparent";
        cbPost        = new CommandBuffer(); cbPost.name        = "Vulpine/Post";

        targetCamera.AddCommandBuffer(CameraEvent.BeforeForwardOpaque, cbDepth);
        targetCamera.AddCommandBuffer(CameraEvent.BeforeForwardOpaque, cbOpaque);
        targetCamera.AddCommandBuffer(CameraEvent.BeforeForwardAlpha,   cbAlphaTest);
        targetCamera.AddCommandBuffer(CameraEvent.BeforeImageEffects,  cbTransparent);
        targetCamera.AddCommandBuffer(CameraEvent.AfterImageEffects,   cbPost);
    }

    void OnDisable()
    {
        if (targetCamera != null)
        {
            if (cbDepth != null)       targetCamera.RemoveCommandBuffer(CameraEvent.BeforeForwardOpaque, cbDepth);
            if (cbOpaque != null)      targetCamera.RemoveCommandBuffer(CameraEvent.BeforeForwardOpaque, cbOpaque);
            if (cbAlphaTest != null)   targetCamera.RemoveCommandBuffer(CameraEvent.BeforeForwardAlpha,   cbAlphaTest);
            if (cbTransparent != null) targetCamera.RemoveCommandBuffer(CameraEvent.BeforeImageEffects,  cbTransparent);
            if (cbPost != null)        targetCamera.RemoveCommandBuffer(CameraEvent.AfterImageEffects,   cbPost);
        }

        if (cbDepth != null)       cbDepth.Release();
        if (cbOpaque != null)      cbOpaque.Release();
        if (cbAlphaTest != null)   cbAlphaTest.Release();
        if (cbTransparent != null) cbTransparent.Release();
        if (cbPost != null)        cbPost.Release();

        cbDepth = null; cbOpaque = null; cbAlphaTest = null; cbTransparent = null; cbPost = null;
    }

    void LateUpdate()
    {
        if (RenderFrameTracker.Instance == null) return;
        RenderFrameTracker.Instance.BeginFrame(targetCamera);

        // Visibility accounting window (your LightVisibility runs in Update)
        FrameCounters.StartVisibility();
        FrameCounters.EndVisibility();

        // Single light upload if anything changed
        if (lightManager != null) lightManager.UploadIfDirty();

        // Build lists and submit CBs
        BuildAndSubmit();

        RenderFrameTracker.Instance.EndFrame();
    }

    void BuildAndSubmit()
    {
        if (cbDepth != null)       cbDepth.Clear();
        if (cbOpaque != null)      cbOpaque.Clear();
        if (cbAlphaTest != null)   cbAlphaTest.Clear();
        if (cbTransparent != null) cbTransparent.Clear();
        if (cbPost != null)        cbPost.Clear();

        CollectVisibleRenderers();

        // Depth prepass (selective)
        if (enableDepthPrepass && depthOnlyMaterial != null && cbDepth != null)
        {
            int i;
            for (i = 0; i < _opaque.Count; i++)
                if (IsInMask(_opaque[i], depthPrepassMask)) cbDepth.DrawRenderer(_opaque[i], depthOnlyMaterial);

            for (i = 0; i < _alphaTest.Count; i++)
                if (IsInMask(_alphaTest[i], depthPrepassMask)) cbDepth.DrawRenderer(_alphaTest[i], depthOnlyMaterial);
        }

        // Opaque (front-to-back within material buckets)
        _opaque.Sort(OpaqueSorter);
        SubmitByMaterial(cbOpaque, _opaque);

        // AlphaTest (front-to-back)
        _alphaTest.Sort(AlphaTestSorter);
        SubmitByMaterial(cbAlphaTest, _alphaTest);

        // Transparent (back-to-front)
        _transparent.Sort(TransparentSorter);
        SubmitByMaterial(cbTransparent, _transparent);

        // Post
        if (enablePost && postMaterial != null && cbPost != null)
        {
            cbPost.Blit(BuiltinRenderTextureType.CameraTarget,
                        BuiltinRenderTextureType.CameraTarget, postMaterial);
        }
    }

    void CollectVisibleRenderers()
    {
        _opaque.Clear();
        _alphaTest.Clear();
        _transparent.Clear();

        Plane[] planes = (RenderFrameTracker.Instance != null) ? RenderFrameTracker.Instance.FrustumPlanes : null;
        if (planes == null) return;

        Renderer[] all = Object.FindObjectsOfType<Renderer>();
        int i;
        for (i = 0; i < all.Length; i++)
        {
            Renderer r = all[i];
            if (!r.enabled) continue;
            if (!IsInMask(r, renderLayerMask)) continue;

            if (!GeometryUtility.TestPlanesAABB(planes, r.bounds)) continue;

            int q = (r.sharedMaterial != null) ? r.sharedMaterial.renderQueue : 2000;
            if (q >= 3000) _transparent.Add(r);
            else if (q >= 2450) _alphaTest.Add(r);
            else _opaque.Add(r);
        }
    }

    static bool IsInMask(Renderer r, LayerMask mask)
    {
        return (mask.value & (1 << r.gameObject.layer)) != 0;
    }

    static void SubmitByMaterial(CommandBuffer cb, List<Renderer> list)
    {
        if (cb == null || list == null || list.Count == 0) return;

        Material lastMat = null;
        int i;
        for (i = 0; i < list.Count; i++)
        {
            Renderer r = list[i];
            Material m = r.sharedMaterial;
            if (m == null) continue;

            // No explicit SetPass; DrawRenderer binds as needed.
            if (m != lastMat) lastMat = m;
            cb.DrawRenderer(r, m);
        }
    }

    // --- Comparers ---

    class OpaqueComparer : IComparer<Renderer>
    {
        public int Compare(Renderer a, Renderer b)
        {
            if (a == b) return 0;

            float da = DistanceSqr(a);
            float db = DistanceSqr(b);
            int cd = da.CompareTo(db); // front-to-back
            if (cd != 0) return cd;

            // cluster by shader then material to reduce SetPass churn
            Material ma = a.sharedMaterial;
            Material mb = b.sharedMaterial;
            int sa = (ma != null && ma.shader != null) ? ma.shader.GetInstanceID() : 0;
            int sb = (mb != null && mb.shader != null) ? mb.shader.GetInstanceID() : 0;
            int sm = sa.CompareTo(sb);
            if (sm != 0) return sm;

            int mia = (ma != null) ? ma.GetInstanceID() : 0;
            int mib = (mb != null) ? mb.GetInstanceID() : 0;
            return mia.CompareTo(mib);
        }
    }

    class TransparentComparer : IComparer<Renderer>
    {
        public int Compare(Renderer a, Renderer b)
        {
            if (a == b) return 0;

            float da = DistanceSqr(a);
            float db = DistanceSqr(b);
            int cd = db.CompareTo(da); // back-to-front
            if (cd != 0) return cd;

            Material ma = a.sharedMaterial;
            Material mb = b.sharedMaterial;
            int sa = (ma != null && ma.shader != null) ? ma.shader.GetInstanceID() : 0;
            int sb = (mb != null && mb.shader != null) ? mb.shader.GetInstanceID() : 0;
            int sm = sa.CompareTo(sb);
            if (sm != 0) return sm;

            int mia = (ma != null) ? ma.GetInstanceID() : 0;
            int mib = (mb != null) ? mb.GetInstanceID() : 0;
            return mia.CompareTo(mib);
        }
    }

    static float DistanceSqr(Renderer r)
    {
        Camera cam = Camera.main;
        if (cam == null)
        {
            Vector3 c = r.bounds.center;
            return c.sqrMagnitude;
        }
        Vector3 d = r.bounds.center - cam.transform.position;
        return Vector3.Dot(d, d);
    }
}
