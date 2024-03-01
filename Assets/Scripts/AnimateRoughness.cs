using System;
using UnityEngine;
using UnityEngine.Rendering;
    public class AnimateRoughness : MonoBehaviour
    {
        public Material renderMat;
        public float value;
        public float calcValue;
        private int tick = 0;
        private void Start()
        {
            value = renderMat.GetFloat("_Roughness");
        }

        private void Update()
        {
            for (int i = 1; i<241; i++)
            {
                value += 0.0000083f;
                if (value > 1)
                    value = 1;
                renderMat.SetFloat("_Roughness", value);
            }
    }
}