using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace WSCG
{
	[RequireComponent(typeof(Light))]
	public class LightManager : MonoBehaviour
	{
		//flow control
		private bool _isInBuffer = false;
		private bool _isInCamera = false;
	
		//light
		private Light _lightObject;
		private int _thisLightSlot;
		private Bounds _lightBounds;
		private Vector3 _lightCenter;
		private float _lightRadius;
		
		//camera
		private Camera _mainCam;
		private Vector3 _cameraViewportPoint;
		private float _distanceToCamera;
		
		// Use this for initialization
		private void Start()
		{
			//cache refs for camera and light
			_mainCam = Camera.main;
			_lightObject = GetComponent<Light>();
			//check if light volume is in the camera view
			CheckCameraView(_lightObject);
		}
		
		// ReSharper disable once Unity.RedundantEventFunction
		private void Update()
		{
			/*
				-have an incrementor
				-on framerate%increment = 0, fire cam check
				-this gives us variable frequency [30/increment = int(fps)] for checking if we are in the camera view			
			*/
		}

		private void CheckCameraView(Light lightToCheck)
		{
			//grab our bounds and center, extract radius from bounds
			_lightBounds = lightToCheck.GetComponent<Renderer>().bounds;
			_lightCenter = _lightBounds.center;
			_lightRadius = _lightBounds.extents.magnitude;
			//get a point from the camera to the viewport center to check against, get distance to the light's center point
			_cameraViewportPoint = _mainCam.ViewportToWorldPoint( new Vector3(0.5f, 0.5f, _mainCam.nearClipPlane) );
			//find the distance from the light center to the camera center
			_distanceToCamera = Vector3.Distance(_lightCenter, _cameraViewportPoint);
			
			//check if camera distance is within light radius, toggle bool
			if (_distanceToCamera <= _lightRadius)
			{
				_isInCamera = true;
				AddLight(lightToCheck);
			}
			else
			{
				_isInCamera = false;
				RemoveLight(lightToCheck);
			}
		}
		
		private void AddLight(Light lightToAdd)
		{
			if (_isInBuffer)
				Debug.Log("Light is already in buffer in slot " + _thisLightSlot);
			else
			{
				if (LightBufferManager.usedSlots != Vector4.one) //does the buffer contain an empty slot?
				{
					for (int l = 0; l < LightBufferManager.MaxLights - 1; l++) //spin slot vector components
					{
						if (LightBufferManager.usedSlots[l] == 0) //the spot is empty
						{
							_isInBuffer = true; //toggle the boolean
							_thisLightSlot = l; //set our value to l value for use in removal
							LightBufferManager.Lights[_thisLightSlot] = _lightObject; //add this light to object list
							LightBufferManager.usedSlots[_thisLightSlot] = 1; //set the Vec4 component to 1 so it is 'used'
							Debug.Log("Light added to buffer in slot " + _thisLightSlot);
							Debug.Log("Available slots: " + LightBufferManager.usedSlots.ToString());
						}
					}
				}
				else
				{
					Debug.Log("All slots are occupied: " + LightBufferManager.usedSlots.ToString());
					/*
						-If all the slots are full, we should spin through them and check the _distanceToCamera, and if our
						_distanceToCamera is less than the largest value (furthest light), replace that light with this one;
						otherwise, we are the furthest light and should be skipped till the next check happens
					 */
				}
			}
		}

		private void RemoveLight(Light lightToRemove)
		{
			if (!_isInBuffer)
			{
				Debug.Log("Light not in buffer!");
			}
			else
			{
				_isInBuffer = false; //toggle the boolean
				LightBufferManager.Lights[_thisLightSlot] = null; //remove this light from object list
				LightBufferManager.usedSlots[_thisLightSlot] = 0; //set the Vec4 component to 0.0 so it is 'empty'
				Debug.Log("Light removed from buffer slot " + _thisLightSlot);
				Debug.Log("Available slots: " + LightBufferManager.usedSlots.ToString());
			}
		}
	}
}
