#include "UnityCG.cginc"

struct appdata {
    float4 vertex : POSITION;
};

struct v2f {
    float4 pos : SV_POSITION;
    float4 objPos : TEXCOORD0;
    float4 projPos : TEXCOORD1;
    float4 viewDir : TEXCOORD2;
};

sampler3D _NoiseTex;
float _NoiseScale;

sampler2D _CameraDepthTexture;
float4 _CameraDepthTexture_TexelSize;

float SampleDensity(float3 worldPos) {
    return tex3D(_NoiseTex, worldPos / _NoiseScale).r;
}

float GetInBoxDst(float3 objPos) {
    float3 cameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0)).xyz;
    float3 dir = objPos - cameraPos;
    float3 absDir = abs(dir);
    float maxComponent = max(max(absDir.x, absDir.y), absDir.z);
    dir /= maxComponent;
    float3 worldDir = mul((float3x3)unity_ObjectToWorld, dir);
    return length(worldDir);
}

v2f vert (appdata v) {
    v2f o;
    o.pos = UnityObjectToClipPos(v.vertex);
    o.objPos = v.vertex;
    
    float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
    o.projPos = ComputeScreenPos(o.pos);
    o.projPos.z = -UnityWorldToViewPos(worldPos).z;
    o.viewDir.xyz = _WorldSpaceCameraPos - worldPos;
    o.viewDir.w = 0;
    return o;
}

float4 frag (v2f i) : SV_Target {
    float3 viewDir = normalize(i.viewDir.xyz);
    float sceneZ = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.projPos.xy / i.projPos.w));
    float farDist = min(sceneZ, GetInBoxDst(i.objPos));
    float nearDist = i.projPos.z;
    
    const int SAMPLES_NUMBER = 16;
    float stepSize = (farDist - nearDist) / SAMPLES_NUMBER;
    float startDst = nearDist + stepSize * 0.5;
    float density = 0;
    for (int i = 0; i < SAMPLES_NUMBER; ++i) {
        float3 samplePos = _WorldSpaceCameraPos + viewDir * (startDst + stepSize * i);
        density += SampleDensity(samplePos);
    }

    density /= SAMPLES_NUMBER;
    float cloud = exp(-density);
    return float4(farDist.xxx / 10, 1);
}