using UnityEngine;

public class LightVisibility : MonoBehaviour
{
    public Light _thisLight;
    public LightManager _lightManager;
    public EventBroadcaster _broadcaster;

    public bool isVisible = false;
    public bool wasPreviouslyVisible = false;
    public bool isInBuffer = false;

    public enum FrameInterval
    {
        EveryFrame,
        EveryOtherFrame,
        Every3Frames,
        Every5Frames,
        Every10Frames,
        Every15Frames,
        Every30Frames,
        Every60Frames
    };

    public FrameInterval frameInterval;

    private void Start()
    {
        _thisLight = GetComponent<Light>();
        _broadcaster = FindObjectOfType<EventBroadcaster>();
        _lightManager = FindObjectOfType<LightManager>();

        if (_broadcaster == null) return;

        switch (frameInterval)
        {
            case FrameInterval.EveryFrame:
                _broadcaster.onFrame1.AddListener(CheckVisibility);
                break;
            case FrameInterval.EveryOtherFrame:
                _broadcaster.onFrame2.AddListener(CheckVisibility);
                break;
            case FrameInterval.Every3Frames:
                _broadcaster.onFrame3.AddListener(CheckVisibility);
                break;
            case FrameInterval.Every5Frames:
                _broadcaster.onFrame5.AddListener(CheckVisibility);
                break;
            case FrameInterval.Every10Frames:
                _broadcaster.onFrame10.AddListener(CheckVisibility);
                break;
            case FrameInterval.Every15Frames:
                _broadcaster.onFrame15.AddListener(CheckVisibility);
                break;
            case FrameInterval.Every30Frames:
                _broadcaster.onFrame30.AddListener(CheckVisibility);
                break;
            case FrameInterval.Every60Frames:
                _broadcaster.onFrame60.AddListener(CheckVisibility);
                break;
        }
    }

    void CheckVisibility(int frame)
    {
        Bounds lightBounds = new Bounds(transform.position, Vector3.one * _thisLight.range);

        if (Camera.main != null && GeometryUtility.TestPlanesAABB(
                GeometryUtility.CalculateFrustumPlanes(Camera.main.projectionMatrix * Camera.main.worldToCameraMatrix),
                lightBounds))
        {
            if (!isVisible)
            {
                isVisible = true;
                _lightManager.OnVisible(_thisLight);

            }
        }

        if (Camera.main != null && !GeometryUtility.TestPlanesAABB(
                GeometryUtility.CalculateFrustumPlanes(Camera.main.projectionMatrix * Camera.main.worldToCameraMatrix), lightBounds))
        {
            if (isVisible)
            {
                isVisible = false;
                _lightManager.OnNotVisible(_thisLight);
            }
        }
        // Update wasPreviouslyVisible for the next frame
        wasPreviouslyVisible = isVisible;
    }
}
