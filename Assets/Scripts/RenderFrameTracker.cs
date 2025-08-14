using UnityEngine;
using System.Diagnostics;

public class RenderFrameTracker : MonoBehaviour
{
    public static RenderFrameTracker Instance;

    public Plane[] FrustumPlanes = new Plane[6];
    public Stopwatch Timer;
    public int FrameIndex;

    void Awake()
    {
        Instance = this;
        Timer = new Stopwatch();
    }

    public void BeginFrame(Camera cam)
    {
        FrameIndex++;
        Timer.Reset();
        Timer.Start();

        if (cam != null)
        {
            GeometryUtility.CalculateFrustumPlanes(cam, FrustumPlanes);
        }

        FrameCounters.BeginFrame();
    }

    public void EndFrame()
    {
        Timer.Stop();
        FrameCounters.EndFrame(Timer.ElapsedMilliseconds);
    }
}