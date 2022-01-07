using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent (typeof (Camera))]
public class VolumetricCloudCamera : MonoBehaviour {
    void Start () {
        var camera = GetComponent<Camera> ();
        camera.depthTextureMode = camera.depthTextureMode | DepthTextureMode.Depth;
    }
}
