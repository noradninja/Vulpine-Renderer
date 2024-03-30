using System;
using UnityEngine;
[ExecuteInEditMode]
public class LightVisibility : MonoBehaviour
{
    public float lightID;
    public Light _thisLight;
    public LightManager _lightManager;
    public EventBroadcaster _broadcaster;
    public bool isVisible = false;
    public bool wasPreviouslyVisible = false;
    public bool isInBuffer = false;
    //lit. the inspector menu selections for light update frequency
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
        //set our references so we can be lazy
        _thisLight = GetComponent<Light>();
        _broadcaster = FindObjectOfType<EventBroadcaster>();
        _lightManager = FindObjectOfType<LightManager>();
        //bail if the event manager doesn't exist
        if (_broadcaster == null) return; 
        //check to see which interval we set, and subscribe to it's event
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
        //get the cube bounds that contain this light and its range
        Bounds lightBounds = new Bounds(transform.position, Vector3.one * _thisLight.range);
        //we are in the view frustum
        if (Camera.main != null && GeometryUtility.TestPlanesAABB(
            GeometryUtility.CalculateFrustumPlanes(Camera.main.projectionMatrix * Camera.main.worldToCameraMatrix),
            lightBounds))
        {
            //add the light if it wasn't in the view the previous tick
            if (!isVisible)
            {
                isVisible = true;
                _lightManager.OnVisible(_thisLight);
            }
            //update the info for the light if it is already in the buffer (and therefore visible)
            if (isInBuffer) 
                _lightManager.UpdateLightInBuffer(_thisLight, lightID);
        }
        //we are NOT in the view frustum
        if (Camera.main != null && !GeometryUtility.TestPlanesAABB(
            GeometryUtility.CalculateFrustumPlanes(Camera.main.projectionMatrix * Camera.main.worldToCameraMatrix), lightBounds))
        {
            //remove the light only if it is marked as visible, that way we don't inadvertently leave nonvisible lights in the array
            if (isVisible)
            {
                isVisible = false;
                _lightManager.OnNotVisible(_thisLight);
            }
        }
    }
}
