using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class VolumetricCloud : MonoBehaviour {

    public NoiseAsset noiseAsset;

    void OnWillRenderObject () {
        Debug.Log ("OnWillRenderObject");
    }
}
