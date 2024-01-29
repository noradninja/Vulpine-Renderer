using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace WSCG.Managers
{
	public class LightCluster : MonoBehaviour
	{
		//flow control
		public bool _isInBuffer = false;
		public bool _isInCamera = false;
		public int tick = 0;
		public int updateTick;
		public enum Framerate : int
		{
			EveryFrame = 1,
			EveryOtherFrame = 2,
			EveryThirdFrame = 3,
			EveryFifthRrame = 5,
			Every10Frames = 10,
			Every15Frames = 15,
			Every30Frames = 30
		}

	//light
		public Light lightObject;
		public Camera camObject;
		private Vector3 _lightCenter;
		private float _lightRadius;
		public int indexValue = 9;
		
		// Use this for initialization
		private void Start()
		{
			//cache refs for light tick value
			lightObject = GetComponent<Light>();
			camObject = GameObject.FindGameObjectWithTag("MainCamera").GetComponent<Camera>();
			updateTick = 90 - (30 * QualitySettings.vSyncCount); //assume a baseline 120FPS to simplify the math
		}

		public void Awake()
		{
			LightBufferManager.CheckCameraView(lightObject, camObject);
			Debug.Log(lightObject.name + " Awake Done.");
		}

		// ReSharper disable once Unity.RedundantEventFunction
		private void Update()
		{
			if (tick <= updateTick/3) tick++;
			else
			{
				tick = 0;
				Debug.Log(lightObject.name + " Tick Fired at " + updateTick/3 + " frame interval.");
				LightBufferManager.CheckCameraView(lightObject, camObject);
			}
		}
	}
}
