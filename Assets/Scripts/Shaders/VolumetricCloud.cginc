#include "UnityCG.cginc"

struct appdata {
    float4 vertex : POSITION;
};

struct v2f {
    float4 vertex : SV_POSITION;
    float4 worldPos : TEXCOORD0;
};

sampler3D _NoiseTex;

v2f vert (appdata v) {
    v2f o;
    o.vertex = UnityObjectToClipPos(v.vertex);
    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    return o;
}

float4 frag (v2f i) : SV_Target {
    float density = tex3D(_NoiseTex, i.worldPos.xyz).r;
    return float4(density.xxx, 1.0);
}