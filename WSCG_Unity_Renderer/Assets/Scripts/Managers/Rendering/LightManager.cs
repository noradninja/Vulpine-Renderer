using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace WSCG.Managers
{
	[RequireComponent(typeof(Light))]
	public class LightManager : MonoBehaviour
	{
		//flow control
		private bool _isInBuffer = false;
		private bool _isInCamera = false;
		public bool[] usedSlots;
	
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
			usedSlots = new bool[LightBufferManager.UsedSlots.Length];
			usedSlots = LightBufferManager.UsedSlots;
			//Is light volume is in the camera view
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
				_isInCamera = true;
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
				for (int l = 0; l < LightBufferManager._totalLights; l++) //spin slot array
				{
					if (usedSlots[l] == false)
					{
						//the spot is empty
						_isInBuffer = true; //toggle the boolean
						_thisLightSlot = l; //set our value to l value for use in removal
						LightBufferManager.Lights[_thisLightSlot] = _lightObject; //add this light to object array
						LightBufferManager.ScreenSpaceLightDistances[_thisLightSlot] =
							distance; //store ss distance in array
						LightBufferManager.UsedSlots[_thisLightSlot] =
							true; //set the bool component to 1 so it is 'used'
						LightBufferManager.ListIsDirty = true; //flag light list data for refresh
						Debug.Log(_lightObject.name + " added to buffer in slot " + _thisLightSlot);
						Debug.Log("Available slots: " + usedSlots);
						break; //escape out as we have been added to the list
					}
				}
				CompareDistancesForCulling(lightToAdd, distance); //if there isn't an empty spot is a light further away than this?
			}
		}

		private void CompareDistancesForCulling(Light lightToAdd, float distance)
		{
			Debug.Log("All slots are occupied: " + usedSlots);
			int currentMax =
				Lib.Math.Vec4.ComponentMaxInt(LightBufferManager.ScreenSpaceLightDistances); //find light with longest distance
			int lightToRemove = Lib.Math.Vec4.ComponentMaxIndex(LightBufferManager.ScreenSpaceLightDistances); //get index 
			if (distance < currentMax) //are we closer than the light in this slot
			{
				RemoveLight(lightToRemove); //remove light at that index
				Debug.Log("Replacing Light: " + LightBufferManager.Lights[lightToRemove].name + " in slot " + lightToRemove);
				LightBufferManager.Lights[lightToRemove] = lightToAdd; //swap this light in object array
				LightBufferManager.ScreenSpaceLightDistances[lightToRemove] = distance; //store ss distance in array
				LightBufferManager.UsedSlots[_thisLightSlot] = true; //set the bool component to 1 so it is 'used'
				LightBufferManager.ListIsDirty = true; //flag light list data for refresh
			}
			else
				Debug.Log("Dropping light " + _lightObject.name + " for being the furthest light"); //drop light this cycle
		}


		private void RemoveLight(int lightIndexToRemove)
		{
			if (!_isInBuffer)
				Debug.Log("Light not in buffer!");
			else
			{
				_isInBuffer = false; //toggle the boolean
				LightBufferManager.Lights[lightIndexToRemove] = null; //remove this light from object list
				LightBufferManager.UsedSlots[lightIndexToRemove] = false; //set the bool component to 0 so it is 'available'
				Debug.Log(_lightObject.name + " removed from buffer slot " + lightIndexToRemove);
				Debug.Log("Available slots: " + usedSlots);
			}
		}
	}
}
