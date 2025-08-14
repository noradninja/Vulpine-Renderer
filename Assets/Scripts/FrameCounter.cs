using UnityEngine;
using System.Diagnostics;

public static class FrameCounters
{
    public static int GlobalSets;
    public static int BytesUploaded;
    public static int VisibleDirectional;
    public static int VisiblePointSpot;

    public static long MsVisibility;
    public static long MsPack;
    public static long MsTotal;

    static Stopwatch _swVis = new Stopwatch();
    static Stopwatch _swPack = new Stopwatch();
    static int _frames;
    const int LogEvery = 60;

    public static void BeginFrame()
    {
        GlobalSets = 0;
        BytesUploaded = 0;
        VisibleDirectional = 0;
        VisiblePointSpot = 0;
        MsVisibility = 0;
        MsPack = 0;
        MsTotal = 0;
    }

    public static void StartVisibility()
    {
        _swVis.Reset();
        _swVis.Start();
    }

    public static void EndVisibility()
    {
        _swVis.Stop();
        MsVisibility += _swVis.ElapsedMilliseconds;
    }

    public static void StartPack()
    {
        _swPack.Reset();
        _swPack.Start();
    }

    public static void EndPack()
    {
        _swPack.Stop();
        MsPack += _swPack.ElapsedMilliseconds;
    }

    public static void EndFrame(long totalMs)
    {
        MsTotal = totalMs;
        _frames++;

        if (_frames % LogEvery == 0)
        {
            UnityEngine.Debug.Log(string.Format(
                "[Frames x{0}] Sets:{1} Bytes:{2} Vis: D={3} P/S={4} Time(ms): total={5} vis={6} pack={7}",
                LogEvery, GlobalSets, BytesUploaded, VisibleDirectional, VisiblePointSpot, MsTotal, MsVisibility, MsPack));
        }
    }
}