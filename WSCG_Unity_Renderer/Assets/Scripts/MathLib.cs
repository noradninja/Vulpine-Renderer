using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace WSCG
{
	

public static class Math{



	public static float Vec4CompSum(Vector4 inputVector4)
	{
		return (inputVector4.x + inputVector4.y + inputVector4.z + inputVector4.w);
	}

	public static int Vec4CompMax(Vector4 inputVector4)
	{
		return (int)Mathf.Max((Mathf.Max(inputVector4.x, inputVector4.y)),
			(Mathf.Max(inputVector4.z, inputVector4.w)));
	}

	public static int Vec4CompMin(Vector4 inputVector4)
	{
		return (int)Mathf.Min((Mathf.Min(inputVector4.x, inputVector4.y)),
			(Mathf.Min(inputVector4.z, inputVector4.w)));
	}
}
}
