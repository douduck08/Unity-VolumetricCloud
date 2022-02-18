Shader "Hidden/Volumetric Cloud" {
    Properties {
    }
    SubShader {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        Cull Front
        ZWrite Off
        ZTest Off
        Blend One SrcAlpha

        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "VolumetricCloud.cginc"
            ENDCG
        }
    }
}
