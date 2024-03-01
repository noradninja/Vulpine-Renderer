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
            renderMat.SetFloat("_Roughness", 0f);
            value = 0f;
        }

        private void Update()
        {
            for (int i = 1; i<241; i++)
            {
                value += 0.000005f;
                if (value > 1)
                    value = 1;
                renderMat.SetFloat("_Roughness", value);
            }
        }
}