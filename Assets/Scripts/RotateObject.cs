using UnityEngine;

public class RotateObject : MonoBehaviour
{
    public Vector3 rotationSpeed = new Vector3(1.0f, 2.0f, 3.0f);

    void Update()
    {
        // Rotate the object on all three axes
        transform.Rotate(rotationSpeed * Time.deltaTime);
    }
}