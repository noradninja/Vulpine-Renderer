using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace WSCG
{
	[RequireComponent(typeof(Light))]
	public class LightManager : MonoBehaviour
	{
		//flow control
		private bool _isInBuffer = false;
		private bool _isInCamera = false;
		private Vector4 _usedSlots = LightBufferManager.UsedSlots;
	
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
				-have an incrementor, ideally globally
				-on framerate%increment = 0, fire cam check
				-this gives us variable frequency [30/increment = int(fps)] for checking if we are in the camera view			
			*/
		}

		private void CheckCameraView(Light lightToCheck)
		{
			//grab our radius and center, extract radius from bounds
			_lightCenter = lightToCheck.transform.position;
			_lightRadius = lightToCheck.range;
			//get a point from the camera to the viewport center to check against, get distance to the light's center point
			_cameraViewportPoint = _mainCam.ViewportToWorldPoint( new Vector3(0.5f, 0.5f, _mainCam.nearClipPlane) );
			//find the distance from the light center to the camera center
			_distanceToCamera = Vector3.Distance(_lightCenter, _cameraViewportPoint);
			
			//check if camera distance is within light radius
			if (_distanceToCamera <= _lightRadius)
			{
				_isInCamera = true; //
				AddLight(lightToCheck, _distanceToCamera);
			}
			else
			{
				_isInCamera = false;
				if (_isInBuffer)
					RemoveLight(_thisLightSlot);
			}
		}
		
		private void AddLight(Light lightToAdd, float distance)
		{
			if (_isInBuffer)
				Debug.Log(_lightObject.name + " is already in buffer in slot " + _thisLightSlot);
			else
			{
				if (_usedSlots != Vector4.one) //does the buffer contain an empty slot?
				{
					for (int l = 0; l < LightBufferManager.MaxLights - 1; l++) //spin slot array
					{
						if (_usedSlots[l] == 0) //the spot is empty
						{
							_isInBuffer = true; //toggle the boolean
							_thisLightSlot = l; //set our value to l value for use in removal
							LightBufferManager.Lights[_thisLightSlot] = _lightObject; //add this light to object array
							LightBufferManager.ScreenSpaceLightDistances[_thisLightSlot] = distance; //store ss distance in array
							_usedSlots[_thisLightSlot] = 1; //set the Vec4 component to 1 so it is 'used'
							LightBufferManager.listIsDirty = true; //flag light list data for refresh
							Debug.Log(_lightObject.name + " added to buffer in slot " + _thisLightSlot);
							Debug.Log("Available slots: " + _usedSlots.ToString());
						}
					}
				}
				else 
				{
					Debug.Log("All slots are occupied: " + _usedSlots.ToString());
					int currentMax = MathLib.Vec4CompMaxInt(LightBufferManager.ScreenSpaceLightDistances); // find light with longest distance
					int lightToRemove = MathLib.Vec4MaxComponent(LightBufferManager.ScreenSpaceLightDistances); //get index 
					if (distance < currentMax) //are we closer than the light in this slot
					{
						RemoveLight(lightToRemove); //remove light at that index
						Debug.Log("Replacing Light: " + LightBufferManager.Lights[lightToRemove].name + " in slot " + lightToRemove);
						LightBufferManager.Lights[lightToRemove] = lightToAdd; //swap this light in object array
						LightBufferManager.ScreenSpaceLightDistances[lightToRemove] = distance; //store ss distance in array
						_usedSlots[_thisLightSlot] = 1; //set the Vec4 component to 1 so it is 'used'
						LightBufferManager.listIsDirty = true; //flag light list data for refresh
						
					}
					else
						Debug.Log("Dropping light " + _lightObject.name + " for being the furthest light"); //drop this light this cycle
				}
			}
		}
		

		private void RemoveLight(int lightIndexToRemove)
		{
			if (!_isInBuffer)
				Debug.Log("Light not in buffer!");
			else
			{
				_isInBuffer = false; //toggle the boolean
				LightBufferManager.Lights[lightIndexToRemove] = null; //remove this light from object list
				_usedSlots[lightIndexToRemove] = 0; //set the Vec4 component to 0.0 so it is 'empty'
				Debug.Log(_lightObject.name + " removed from buffer slot " + lightIndexToRemove);
				Debug.Log("Available slots: " + _usedSlots.ToString());
			}
		}
	}
}
