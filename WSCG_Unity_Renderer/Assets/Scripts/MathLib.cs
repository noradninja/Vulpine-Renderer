using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace WSCG
{
	public static class MathLib{
		public static float Vec4CompSum(Vector4 inputVector4)
		{
			return (inputVector4.x + inputVector4.y + inputVector4.z + inputVector4.w);
		}

		public static float Vec4CompSumInt(Vector4 inputVector4)
		{
			return ((int)inputVector4.x + (int)inputVector4.y + (int)inputVector4.z + (int)inputVector4.w);
		}

		
		public static float Vec4CompMax(Vector4 inputVector4)
		{
			return Mathf.Max((Mathf.Max(inputVector4.x, inputVector4.y)),
				(Mathf.Max(inputVector4.z, inputVector4.w)));
		}

		public static int Vec4CompMaxInt(Vector4 inputVector4)
		{
			return (int) Mathf.Max((Mathf.Max(inputVector4.x, inputVector4.y)),
				(Mathf.Max(inputVector4.z, inputVector4.w)));
		}
		
		public static int Vec4CompMinInt(Vector4 inputVector4)
		{
			return (int) Mathf.Min((Mathf.Min(inputVector4.x, inputVector4.y)),
				(Mathf.Min(inputVector4.z, inputVector4.w)));
		} 
		
		public static float Vec4CompMin(Vector4 inputVector4)
		{
			return Mathf.Min((Mathf.Min(inputVector4.x, inputVector4.y)),
				(Mathf.Min(inputVector4.z, inputVector4.w)));
		}

		public static int Vec4MaxComponent(Vector4 inputVector4)
		{
			int maxLength = (int)Mathf.Max((Mathf.Max(inputVector4.x, inputVector4.y)),
				(Mathf.Max(inputVector4.z, inputVector4.w)));
			int componentSlot = 0;
			for (int c = 0; c < 3; c++)
			{
				componentSlot = maxLength == (int)inputVector4[c] ? c : 0;
			}

			return componentSlot;
		}
	}
}
