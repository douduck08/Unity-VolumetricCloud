#include "UnityCG.cginc"

struct appdata {
    float4 vertex : POSITION;
};

struct v2f {
    float4 posCS : SV_POSITION;
    float4 posOS : TEXCOORD0;
    float3 posWS : TEXCOORD1;
    float4 posVS : TEXCOORD2;
    float4 posProj : TEXCOORD3;
};

sampler2D _CameraDepthTexture;
float4 _CameraDepthTexture_TexelSize;

sampler3D _NoiseTex;
float _NoiseScale;
float _DensityOffset;

float SampleDensity(float3 worldPos) {
    return max(0, tex3D(_NoiseTex, worldPos / _NoiseScale).r - _DensityOffset);
}

float2 BoxIntersection(float3 rayOrigin, float3 rayDir) {
    // ref: https://iquilezles.org/www/articles/intersectors/intersectors.htm
    float3 m = 1.0 / rayDir;
    float3 n = m * rayOrigin;
    float3 k = abs(m) * 0.5;
    float3 t1 = -n - k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float3 t2 = -n + k;
    float tF = min(min(t2.x, t2.y), t2.z);
    return float2(tN, tF);
}

v2f vert (appdata v) {
    v2f o;
    o.posCS = UnityObjectToClipPos(v.vertex);
    o.posOS = v.vertex;
    o.posWS = mul(unity_ObjectToWorld, v.vertex).xyz;
    o.posVS = mul (unity_CameraInvProjection, o.posCS);
    o.posProj = ComputeScreenPos(o.posCS);
    return o;
}

#define SAMPLES_NUMBER 32

float4 frag (v2f i) : SV_Target {
    float3 posVS = i.posVS.xyz / i.posVS.w;
    float depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.posProj.xy / i.posProj.w));
    float sceneDst = depth * length(posVS) / (-posVS.z);
    
    float3 rayDir = i.posWS - _WorldSpaceCameraPos;
    float3 cameraPosOS = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0)).xyz;
    float2 boxHits = BoxIntersection(cameraPosOS, i.posOS.xyz - cameraPosOS) * length(rayDir);
    float nearDist = max(0, boxHits.x);
    float farDist = min(sceneDst, boxHits.y);

    clip(farDist - nearDist);

    rayDir = normalize(rayDir);
    float stepSize = (farDist - nearDist) / (SAMPLES_NUMBER - 1);
    float totalDensity = 0;
    for (int i = 0; i < SAMPLES_NUMBER; ++i) {
        float3 samplePos = _WorldSpaceCameraPos + rayDir * (nearDist + stepSize * i);
        totalDensity += SampleDensity(samplePos) * stepSize;
    }

    float cloud = 1 - exp(-totalDensity);
    return cloud;
}