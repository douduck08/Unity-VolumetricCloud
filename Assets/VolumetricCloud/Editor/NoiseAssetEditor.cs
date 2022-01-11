using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomEditor (typeof (NoiseAsset))]
public class NoiseAssetEditor : Editor {
    public override void OnInspectorGUI () {
        base.OnInspectorGUI ();

        var noiseAsset = target as NoiseAsset;
        GUI.enabled = noiseAsset.NeedUpdate ();
        if (GUILayout.Button ("Apply")) {
            var texture = noiseAsset.ApplyNoiseSettings ();
            UpdateAsset (noiseAsset, texture);
        }
        GUI.enabled = true;
        if (GUILayout.Button ("Force Update")) {
            var texture = noiseAsset.ApplyNoiseSettings (true);
            UpdateAsset (noiseAsset, texture);
        }
    }

    void UpdateAsset (Object target, Texture3D texture) {
        var current = FindCurrentTexture (target);
        if (current != texture) {
            RemoveObject (target, texture.name);
            AssetDatabase.AddObjectToAsset (texture, target);
            AssetDatabase.ImportAsset (AssetDatabase.GetAssetPath (target));
        }
    }

    Texture3D FindCurrentTexture (Object target) {
        var path = AssetDatabase.GetAssetPath (target);
        var objs = AssetDatabase.LoadAllAssetsAtPath (path);
        foreach (var obj in objs) {
            if (obj is Texture3D) {
                return obj as Texture3D;
            }
        }
        return null;
    }

    void RemoveObject (Object target, string name) {
        var path = AssetDatabase.GetAssetPath (target);
        var objs = AssetDatabase.LoadAllAssetsAtPath (path);
        foreach (var obj in objs) {
            if (obj.name == name) {
                AssetDatabase.RemoveObjectFromAsset (obj);
            }
        }
    }
}
