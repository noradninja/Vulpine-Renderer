using UnityEngine;

public class ShaderController : MonoBehaviour
{
    public static ShaderController Instance;

    void Awake()
    {
        Instance = this;
    }

    void Start()
    {
        Shader.SetGlobalFloatArray("_DirectionalLightsArray", new float[4 * 10 * 4]); // Initialize the global directional lights array
        Shader.SetGlobalFloatArray("_PointSpotLightsArray", new float[4 * 10 * 4]); // Initialize the global point/spot lights array
    }

    void Update()
    {
        // Assuming you have some way to trigger the update, perhaps a button click or some other event
        if (Input.GetKeyDown(KeyCode.U))
        {
            // Fetch the global directional lights array from the shader
            float[] directionalLightsArray = Shader.GetGlobalFloatArray("_DirectionalLightsArray");
            // Output the fetched directional lights data for readability
            DisplayDirectionalLightsInfo(directionalLightsArray);

            // Fetch the global point/spot lights array from the shader
            float[] pointSpotLightsArray = Shader.GetGlobalFloatArray("_PointSpotLightsArray");
            // Output the fetched point/spot lights data for readability
            DisplayPointSpotLightsInfo(pointSpotLightsArray);
        }
    }

    void DisplayDirectionalLightsInfo(float[] directionalLightsArray)
    {
        Debug.Log("Directional Lights:");

        for (int i = 0; i < directionalLightsArray.Length; i += 10)
        {
            Debug.Log("Light " + (i / 10 + 1) + ": " +
                      "Position: (" + directionalLightsArray[i] + ", " + directionalLightsArray[i + 1] + ", " + directionalLightsArray[i + 2] +
                      "), " +
                      "Color: (" + directionalLightsArray[i + 4] + ", " + directionalLightsArray[i + 5] + ", " + directionalLightsArray[i + 6] +
                      ", " + directionalLightsArray[i + 7] + "), " +
                      "Range: " + directionalLightsArray[i + 8] + ", " +
                      "Intensity: " + directionalLightsArray[i + 9]);
        }
    }

    void DisplayPointSpotLightsInfo(float[] pointSpotLightsArray)
    {
        Debug.Log("Point/Spot Lights:");

        for (int i = 0; i < pointSpotLightsArray.Length; i += 10)
        {
            Debug.Log("Light " + (i / 10 + 1) + ": " +
                      "Position: (" + pointSpotLightsArray[i] + ", " + pointSpotLightsArray[i + 1] + ", " + pointSpotLightsArray[i + 2] +
                      "), " +
                      "Color: (" + pointSpotLightsArray[i + 4] + ", " + pointSpotLightsArray[i + 5] + ", " + pointSpotLightsArray[i + 6] +
                      ", " + pointSpotLightsArray[i + 7] + "), " +
                      "Range: " + pointSpotLightsArray[i + 8] + ", " +
                      "Intensity: " + pointSpotLightsArray[i + 9]);
        }
    }
}
