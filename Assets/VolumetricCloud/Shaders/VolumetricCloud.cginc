#include "UnityCG.cginc"

struct appdata {
    float4 vertex : POSITION;
};

struct v2f {
    float4 posCS : SV_POSITION;
    float3 posWS : TEXCOORD0;
    float4 posVS : TEXCOORD1;
    float4 posProj : TEXCOORD2;
};

sampler2D _CameraDepthTexture;
float4 _CameraDepthTexture_TexelSize;

sampler3D _NoiseTex;
float4 _NoiseScale1;
float4 _NoiseScale2;
float4 _NoiseScale3;
float4 _NoiseScolling1;
float4 _NoiseScolling2;
float4 _NoiseScolling3;

float3 _VolumePosition;
float3 _VolumeSize;
float3 _CloudColor;
float _DensityOffset;
float _DensityMultiplier;

float4 _Light;
float4 _LightColor;
float _LightAbsorption;

uint _CloudStepNumber;
uint _LightStepNumber;
float _MaxDistance;

// ******** //
//  vertex  //
// ******** //
v2f vert (appdata v) {
    v2f o;
    o.posCS = UnityObjectToClipPos(v.vertex);
    o.posWS = mul(unity_ObjectToWorld, v.vertex).xyz;
    o.posVS = mul (unity_CameraInvProjection, o.posCS);
    o.posProj = ComputeScreenPos(o.posCS);
    return o;
}

// ******** //
// fragment //
// ******** //
float2 BoxIntersection(float3 rayOrigin, float3 rayDir) {
    // ref: https://iquilezles.org/www/articles/intersectors/intersectors.htm
    float3 m = 1.0 / rayDir;
    float3 n = m * (rayOrigin - _VolumePosition);
    float3 k = abs(m) * _VolumeSize;
    float3 t1 = -n - k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float3 t2 = -n + k;
    float tF = min(min(t2.x, t2.y), t2.z);
    return float2(tN, tF);
}

float SampleDensity(float3 worldPos) {
    float density = 0;
    float t = _Time.x;
    density += tex3D(_NoiseTex, (worldPos + _NoiseScolling1.xyz * t) / _NoiseScale1.xyz).r * _NoiseScale1.w;
    density += tex3D(_NoiseTex, (worldPos + _NoiseScolling2.xyz * t) / _NoiseScale2.xyz).r * _NoiseScale2.w;
    density += tex3D(_NoiseTex, (worldPos + _NoiseScolling3.xyz * t) / _NoiseScale3.xyz).r * _NoiseScale3.w;
    return max(0, density - _DensityOffset) * _DensityMultiplier;
}

float GetLightTransmittance(float3 rayOrigin, float3 rayDir) {
    float2 boxHits = BoxIntersection(rayOrigin, rayDir) * length(rayDir);
    float nearDist = max(0, boxHits.x);
    float farDist = boxHits.y;
    if (farDist  < nearDist) {
        return 1.0;
    }

    rayDir = normalize(rayDir);
    float stepSize = (farDist - nearDist) / (_LightStepNumber - 1);
    float totalDensity = 0;
    [loop]
    for (uint i = 0; i < _LightStepNumber; ++i) {
        float3 samplePos = rayOrigin + rayDir * (nearDist + stepSize * i);
        totalDensity += SampleDensity(samplePos) * stepSize;
    }
    return exp(-totalDensity * _LightAbsorption);
}

float4 frag (v2f i) : SV_Target {
    // calculate distance (not depth) to scene object
    float3 posVS = i.posVS.xyz / i.posVS.w;
    float depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.posProj.xy / i.posProj.w));
    float sceneDst = depth * length(posVS) / (-posVS.z);
    
    // calculate distance to volume box
    float3 rayDir = i.posWS - _WorldSpaceCameraPos;
    float2 boxHits = BoxIntersection(_WorldSpaceCameraPos, rayDir) * length(rayDir);
    float nearDist = max(0, boxHits.x);
    float farDist = min(min(sceneDst, boxHits.y), _MaxDistance);
    clip(farDist - nearDist);

    // marching in volume
    rayDir = normalize(rayDir);
    float stepSize = (farDist - nearDist) / (_CloudStepNumber - 1);
    float transmittance = 1;
    float lightEnergy = 0;
    [loop]
    for (uint i = 0; i < _CloudStepNumber; ++i) {
        float3 samplePos = _WorldSpaceCameraPos + rayDir * (nearDist + stepSize * i);
        float density = SampleDensity(samplePos);
        float lightTransmittance = GetLightTransmittance(samplePos, _Light);

        density *= stepSize;
        lightEnergy += density * transmittance * lightTransmittance;
        transmittance *= exp(-density);

        if (transmittance < 0.01) {
            break;
        }
    }

    float alpha = 1 - transmittance;
    float3 color = _CloudColor * _LightColor * lightEnergy;
    return float4(color, alpha);
}