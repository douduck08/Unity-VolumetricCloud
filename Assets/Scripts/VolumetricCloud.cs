using System.Collections;
using System.Collections.Generic;
using UnityEngine;

// [ExecuteInEditMode]
public class VolumetricCloud : MonoBehaviour {

    public Material material;
    public NoiseAsset noiseAsset;

    void OnWillRenderObject () {
        if (material != null && noiseAsset != null) {
            var noiseTexture = noiseAsset.texture;
            if (noiseTexture != null) {
                material.SetTexture ("_NoiseTex", noiseTexture);
            }
        }
    }
}
