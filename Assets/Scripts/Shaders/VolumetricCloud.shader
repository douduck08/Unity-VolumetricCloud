﻿Shader "Volumetric Rendering/Volumetric Cloud" {
    Properties {
        _NoiseTex ("Noise Texture", 3D) = "white" {}
    }
    SubShader {
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "VolumetricCloud.cginc"
            ENDCG
        }
    }
}
