using UnityEngine;
using WSCG.Lib.Rendering;
using WSCG.Lighting;
using WSCG.Systems;

namespace WSCG.Lib
{


    public class LightVisibility : MonoBehaviour
    {
        public bool isVisible = false;
        public bool isInBuffer = false;
        public bool wasPreviouslyVisible;
        public Light thisLight;
        public LightManager lightManager;


        public FrameInterval frameInterval;

        private void Start()
        {
            thisLight = GetComponent<Light>();
            EventBroadcaster broadcaster = FindObjectOfType<EventBroadcaster>();
            if (broadcaster != null)
            {
                switch (frameInterval)
                {
                    case FrameInterval.EveryFrame:
                        broadcaster.onFrame1.AddListener(CheckVisibility);
                        break;
                    case FrameInterval.EveryOtherFrame:
                        broadcaster.onFrame2.AddListener(CheckVisibility);
                        break;
                    case FrameInterval.Every3Frames:
                        broadcaster.onFrame3.AddListener(CheckVisibility);
                        break;
                    case FrameInterval.Every5Frames:
                        broadcaster.onFrame5.AddListener(CheckVisibility);
                        break;
                    case FrameInterval.Every10Frames:
                        broadcaster.onFrame10.AddListener(CheckVisibility);
                        break;
                    case FrameInterval.Every15Frames:
                        broadcaster.onFrame15.AddListener(CheckVisibility);
                        break;
                    case FrameInterval.Every30Frames:
                        broadcaster.onFrame30.AddListener(CheckVisibility);
                        break;
                    case FrameInterval.Every60Frames:
                        broadcaster.onFrame60.AddListener(CheckVisibility);
                        break;
                }
            }
        }

        void CheckVisibility(int frame)
        {
            wasPreviouslyVisible = isVisible;
            Bounds lightBounds = new Bounds(transform.position, Vector3.one * GetComponent<Light>().range);
            Debug.Log(thisLight.name + " is checking visibility at interval " + frameInterval);
            if (Camera.main != null)
            {
                isVisible = GeometryUtility.TestPlanesAABB(
                    GeometryUtility.CalculateFrustumPlanes(Camera.main.projectionMatrix * Camera.main.worldToCameraMatrix), lightBounds);

                if (isVisible && !wasPreviouslyVisible)
                {
                    lightManager.OnVisible(thisLight);
                }
                else if (!isVisible && wasPreviouslyVisible)
                {
                    lightManager.OnNotVisible(thisLight);
                }

                // Update wasPreviouslyVisible for the next frame
                wasPreviouslyVisible = isVisible;
            }
        }
    }
}
