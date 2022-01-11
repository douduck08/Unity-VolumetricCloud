using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

[CreateAssetMenu (menuName = "Cloud Noise Asset", fileName = "CloudNoiseAsset")]
public class NoiseAsset : ScriptableObject {

    public enum Resolution {
        _64 = 64,
        _128 = 128,
        _256 = 256
    }

    [Header ("Data")]
    [SerializeField, HideInInspector] bool isDirty;
    [SerializeField, HideInInspector] Texture3D noiseTexture;
    public Texture3D texture { get => noiseTexture; }

    [Header ("Resources")]
    [SerializeField] ComputeShader generateNoiseCS;

    [Header ("Settings")]
    [SerializeField] Resolution resolution = Resolution._64;
    [SerializeField, Range (1, 16)] int cellNumber = 1;

    void OnValidate () {
        isDirty = true;
    }

    public bool NeedUpdate () {
        return isDirty;
    }

    public Texture3D ApplyNoiseSettings (bool forceUpdate = false) {
        if (noiseTexture == null || isDirty || forceUpdate) {
            isDirty = false;
            CreateNoiseTexture ();
        }
        return noiseTexture;
    }

    void CreateNoiseTexture () {
        var textureFormat = TextureFormat.RHalf;
        var resolution = (int)this.resolution;
        noiseTexture = new Texture3D (resolution, resolution, resolution, textureFormat, false);
        noiseTexture.name = "3D Noise Texture";
        noiseTexture.filterMode = FilterMode.Bilinear;
        noiseTexture.wrapMode = TextureWrapMode.Repeat;

        var distances = GetWorleyNoise (generateNoiseCS, resolution, cellNumber);
        var maxDst = distances.Max ();
        noiseTexture.SetPixels (distances.Select (d => new Color (1f - d / maxDst, 0f, 0f)).ToArray ());
        noiseTexture.Apply ();
    }

    static float[] GetWorleyNoise (ComputeShader generateNoiseCS, int resolution, int cellNumber) {
        var cellSize = 1.0f / cellNumber;
        var pointCount = cellNumber * cellNumber * cellNumber;
        var points = new Vector3[pointCount];
        for (int z = 0, index = 0; z < cellNumber; z++) {
            for (int y = 0; y < cellNumber; y++) {
                for (int x = 0; x < cellNumber; x++, index++) {
                    var offset = new Vector3 (Random.value, Random.value, Random.value);
                    var point = (new Vector3 (x, y, z) + offset) * cellSize;
                    points[index] = point;
                }
            }
        }

        var pointsBuffer = new ComputeBuffer (points.Length, sizeof (float) * 3, ComputeBufferType.Default);
        var distancesBuffer = new ComputeBuffer (resolution * resolution * resolution, sizeof (float), ComputeBufferType.Default);
        pointsBuffer.SetData (points);

        generateNoiseCS.SetBuffer (0, "_Points", pointsBuffer);
        generateNoiseCS.SetBuffer (0, "_Distances", distancesBuffer);
        generateNoiseCS.SetInt ("_CellNumber", cellNumber);
        generateNoiseCS.SetInt ("_Resolution", resolution);

        const int THREAD_GROUP_SIZE = 4;
        generateNoiseCS.Dispatch (0, resolution / THREAD_GROUP_SIZE, resolution / THREAD_GROUP_SIZE, resolution / THREAD_GROUP_SIZE);

        var distances = new float[resolution * resolution * resolution];
        distancesBuffer.GetData (distances);

        pointsBuffer.Release ();
        distancesBuffer.Release ();
        return distances;
    }
}
