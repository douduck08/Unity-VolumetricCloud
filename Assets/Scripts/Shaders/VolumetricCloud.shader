Shader "Volumetric Rendering/Volumetric Cloud" {
    Properties {
        _NoiseTex ("Noise Texture", 3D) = "white" {}
        _NoiseScale ("Noise Scale", float) = 1.0
        _DensityOffset ("Density Offset", Range(0.0, 1.0)) = 0.0
    }
    SubShader {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        Cull Front
        ZWrite Off
        ZTest Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "VolumetricCloud.cginc"
            ENDCG
        }
    }
}
