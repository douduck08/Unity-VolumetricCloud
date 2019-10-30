using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu (menuName = "Cloud Noise Asset", fileName = "CloudNoiseAsset")]
public class NoiseAsset : ScriptableObject {

    public enum Resolution {
        _64 = 64,
        _128 = 128,
        _256 = 256
    }

    [Header ("Data")]
    [SerializeField] bool isDirty;
    [SerializeField] Texture3D noiseTexture;

    [Header ("Resources")]
    [SerializeField] ComputeShader generateNoiseCS;

    [Header ("Settings")]
    [SerializeField] Resolution resolution = Resolution._64;

    [Space]
    [SerializeField] bool forceUpdate = false;

    public Texture3D GetNoiseTexture () {
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

        for (int z = 0; z < resolution; z++) {
            for (int y = 0; y < resolution; y++) {
                for (int x = 0; x < resolution; x++) {
                    noiseTexture.SetPixel (x, y, z, new Color ((float)x / resolution, 0, 0));
                }
            }
        }
        noiseTexture.Apply ();
    }

    void OnValidate () {
        isDirty = true;
    }
}
