using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace WSCG.Lib
{
	namespace Math
	{
		public static class Vec4
		{

			public static float ComponentSum(Vector4 inputVector4)
			{
				return inputVector4.x + inputVector4.y + inputVector4.z + inputVector4.w;
			}

			public static float ComponentSumInt(Vector4 inputVector4)
			{
				return (int)inputVector4.x + (int)inputVector4.y + (int)inputVector4.z + (int)inputVector4.w;
			}


			public static float ComponentMax(Vector4 inputVector4)
			{
				return Mathf.Max(Mathf.Max(inputVector4.x, inputVector4.y),
					Mathf.Max(inputVector4.z, inputVector4.w));
			}

			public static int ComponentMaxInt(Vector4 inputVector4)
			{
				return Mathf.Max(Mathf.Max((int)inputVector4.x, (int)inputVector4.y),
					Mathf.Max((int)inputVector4.z, (int)inputVector4.w));
			}

			public static float ComponentMin(Vector4 inputVector4)
			{
				return Mathf.Min(Mathf.Min(inputVector4.x, inputVector4.y),
					Mathf.Min(inputVector4.z, inputVector4.w));
			}

			public static int ComponentMinInt(Vector4 inputVector4)
			{
				return Mathf.Min(Mathf.Min((int)inputVector4.x, (int)inputVector4.y),
					Mathf.Min((int)inputVector4.z, (int)inputVector4.w));
			}


			public static int ComponentMaxIndex(Vector4 inputVector4)
			{
				int maxLength = (int)Mathf.Max(Mathf.Max(inputVector4.x, inputVector4.y),
					Mathf.Max(inputVector4.z, inputVector4.w));
				int componentSlot = 0;
				for (int c = 0; c < 4; c++)
				{
					componentSlot = maxLength == (int)inputVector4[c] ? c : 0;
				}

				return componentSlot;
			}
		}

		public static class Vec3
		{

			public static float ComponentSum(Vector3 inputVector3)
			{
				return inputVector3.x + inputVector3.y + inputVector3.z;
			}

			public static int ComponentSumInt(Vector3 inputVector3)
			{
				return (int)inputVector3.x + (int)inputVector3.y + (int)inputVector3.z;
			}


			public static float ComponentMax(Vector3 inputVector3)
			{
				return Mathf.Max(Mathf.Max(inputVector3.x, inputVector3.y), inputVector3.z);
			}

			public static int ComponentMaxInt(Vector3 inputVector3)
			{
				return Mathf.Max(Mathf.Max((int)inputVector3.x, (int)inputVector3.y), (int)inputVector3.z);
			}

			public static float ComponentMin(Vector3 inputVector3)
			{
				return Mathf.Min(Mathf.Min(inputVector3.x, inputVector3.y), inputVector3.z);
			}

			public static int ComponentMinInt(Vector3 inputVector3)
			{
				return Mathf.Min(Mathf.Min((int)inputVector3.x, (int)inputVector3.y), (int)inputVector3.z);
			}


			public static int ComponentMaxIndex(Vector4 inputVector3)
			{
				int maxLength = ComponentMaxInt(inputVector3);
				int componentSlot = 0;
				for (int c = 0; c < 3; c++)
				{
					componentSlot = maxLength == (int)inputVector3[c] ? c : 0;
				}

				return componentSlot;
			}
		}
	}

	namespace Rendering
	{
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

		public struct LightData
		{
			public Vector4 position;
			public Vector4 color;
			public Vector2 intensityRange;
		}

	}
}
