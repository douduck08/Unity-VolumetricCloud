using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class VolumetricCloud : MonoBehaviour {

    [Header ("Resources")]
    public Shader shader;
    public Texture2D blueNoise;
    Material material;
    static Mesh cubeMesh;

    [System.Serializable]
    public struct NoiseLayer {
        public Vector3 scale;
        public Vector3 scrolling;
        public float scrollingSpeed;
        public float weight;
    }

    [Header ("Noise Settings")]
    public NoiseAsset noiseAsset;
    public NoiseLayer noiseLayer1 = new NoiseLayer { scale = Vector3.one, scrollingSpeed = 1, weight = 1 };
    public NoiseLayer noiseLayer2 = new NoiseLayer { scale = Vector3.one, scrollingSpeed = 1, weight = 0 };
    public NoiseLayer noiseLayer3 = new NoiseLayer { scale = Vector3.one, scrollingSpeed = 1, weight = 0 };

    [Header ("Cloud Settings")]
    public Vector3 volumeSize = Vector3.one;
    public float densityOffset = 0f;
    public float densityMultiplier = 1f;
    public float speedMultiplier = 1f;
    [ColorUsage (false)]
    public Color cloudColor = Color.white;

    [Header ("Lighting")]
    public Light sun;
    public float lightAbsorption = 1f;
    [Range (0f, 1f)]
    public float baseAttenuation = 0f;
    [Range (0f, 1f)]
    public float inScatter = 0f;
    [Range (0f, 1f)]
    public float outScatter = 0f;
    [Range (0f, 1f)]
    public float blendScatter = 0.5f;

    [Header ("Rendering Settings")]
    [Range (4, 64)]
    public int cloudStepNumber = 4;
    [Range (4, 16)]
    public int lightStepNumber = 4;
    public float maxDistance = 100;
    [Range (0f, 1f)]
    public float randomStrength = 0f;
    [SerializeField] bool renderInEditMode = false;
    [SerializeField] bool drawGizmos = false;

    void Update () {
        if (!renderInEditMode && !Application.isPlaying) {
            return;
        }
        if (!ValidateSettings ()) {
            return;
        }

        UpdateMaterial ();
        var mesh = GetCubeMesh ();
        var matrix = Matrix4x4.Translate (transform.position) * Matrix4x4.Scale (volumeSize);
        Graphics.DrawMesh (mesh, matrix, material, 0);
    }

    bool ValidateSettings () {
        if (shader == null || noiseAsset == null || noiseAsset.texture == null) {
            return false;
        }
        noiseLayer1.weight = Mathf.Max (0, noiseLayer1.weight);
        noiseLayer2.weight = Mathf.Max (0, noiseLayer2.weight);
        noiseLayer3.weight = Mathf.Max (0, noiseLayer3.weight);
        volumeSize.x = Mathf.Max (0.01f, volumeSize.x);
        volumeSize.y = Mathf.Max (0.01f, volumeSize.y);
        volumeSize.z = Mathf.Max (0.01f, volumeSize.z);
        lightAbsorption = Mathf.Max (0, lightAbsorption);
        cloudStepNumber = Mathf.Clamp (cloudStepNumber, 4, 64);
        lightStepNumber = Mathf.Clamp (lightStepNumber, 4, 16);
        return true;
    }

    void UpdateMaterial () {
        if (material == null) {
            material = new Material (shader);
        }

        var noiseTexture = noiseAsset.texture;
        var light = new Vector4 (0, 1, 0, 0);
        var lightColor = Vector4.one;
        if (sun != null) {
            light = -sun.transform.forward;
            lightColor = sun.color;
            lightColor *= sun.intensity;
        }

        material.SetTexture ("_BlueNoise", blueNoise);
        material.SetTexture ("_NoiseTex", noiseTexture);
        material.SetVector ("_NoiseScale1", new Vector4 (noiseLayer1.scale.x, noiseLayer1.scale.y, noiseLayer1.scale.z, noiseLayer1.weight));
        material.SetVector ("_NoiseScale2", new Vector4 (noiseLayer2.scale.x, noiseLayer2.scale.y, noiseLayer2.scale.z, noiseLayer2.weight));
        material.SetVector ("_NoiseScale3", new Vector4 (noiseLayer3.scale.x, noiseLayer3.scale.y, noiseLayer3.scale.z, noiseLayer3.weight));
        material.SetVector ("_NoiseScolling1", noiseLayer1.scrolling * noiseLayer1.scrollingSpeed * speedMultiplier);
        material.SetVector ("_NoiseScolling2", noiseLayer2.scrolling * noiseLayer2.scrollingSpeed * speedMultiplier);
        material.SetVector ("_NoiseScolling3", noiseLayer3.scrolling * noiseLayer3.scrollingSpeed * speedMultiplier);

        material.SetVector ("_VolumePosition", transform.position);
        material.SetVector ("_VolumeSize", volumeSize * 0.5f);
        material.SetVector ("_CloudColor", cloudColor);
        material.SetFloat ("_DensityOffset", densityOffset);
        material.SetFloat ("_DensityMultiplier", densityMultiplier);

        material.SetVector ("_Light", light);
        material.SetVector ("_LightColor", lightColor);
        material.SetVector ("_LightParams1", new Vector4 (lightAbsorption, baseAttenuation, 0, 0));
        material.SetVector ("_LightParams2", new Vector4 (inScatter, outScatter, blendScatter, 0));

        material.SetInt ("_CloudStepNumber", cloudStepNumber);
        material.SetInt ("_LightStepNumber", lightStepNumber);
        material.SetFloat ("_MaxDistance", maxDistance);
        material.SetFloat ("_RandomStrength", randomStrength);
    }

    void OnDrawGizmos () {
        if (drawGizmos) {
            Gizmos.color = new Color (0f, 1f, 1f, .3f);
            Gizmos.DrawWireCube (transform.position, volumeSize);
        }
    }

    static Mesh GetCubeMesh () {
        if (cubeMesh == null) {
            var go = GameObject.CreatePrimitive (PrimitiveType.Cube);
            cubeMesh = go.GetComponent<MeshFilter> ().sharedMesh;
            DestroyImmediate (go);
        }
        return cubeMesh;
    }
}
