using UnityEngine;
using UnityEngine.Events;

    public class EventBroadcaster : MonoBehaviour
    {
        [System.Serializable]
        public class FrameEvent : UnityEvent<int>
        {
        }

        public FrameEvent onFrame1;
        public FrameEvent onFrame2;
        public FrameEvent onFrame3;
        public FrameEvent onFrame5;
        public FrameEvent onFrame10;
        public FrameEvent onFrame15;
        public FrameEvent onFrame30;
        public FrameEvent onFrame60;

        private int currentFrame = 0;

        void Update()
        {
            currentFrame++;

            if (currentFrame%1 == 0) onFrame1.Invoke(currentFrame);
            if (currentFrame%2 == 0) onFrame2.Invoke(currentFrame);
            if (currentFrame%3 == 0) onFrame3.Invoke(currentFrame);
            if (currentFrame%5 == 0) onFrame5.Invoke(currentFrame);
            if (currentFrame%10 == 0) onFrame10.Invoke(currentFrame);
            if (currentFrame%15 == 0) onFrame15.Invoke(currentFrame);
            if (currentFrame%30 == 0) onFrame30.Invoke(currentFrame);
            if (currentFrame%60 == 0)
            {
                onFrame60.Invoke(currentFrame);
                currentFrame = 0;
            }
        }
}
