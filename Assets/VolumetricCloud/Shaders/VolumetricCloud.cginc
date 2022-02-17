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

sampler2D _BlueNoise;
float4 _BlueNoise_TexelSize;

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
float4 _LightParams1;
float4 _LightParams2;

uint _CloudStepNumber;
uint _LightStepNumber;
float _MaxDistance;
float _RandomStrength;

#define _LightAbsorption _LightParams1.x
#define _AttenuationClamp _LightParams1.y
#define _ExtraBrightIntensity _LightParams1.z
#define _ExtraBrightExponent _LightParams1.w
#define _MinimumAttenuation _LightParams2.w
#define _InScatter _LightParams2.x
#define _OutScatter _LightParams2.y
#define _BlendScatter _LightParams2.z

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
    density += tex3Dlod(_NoiseTex, float4((worldPos + _NoiseScolling1.xyz * t) / _NoiseScale1.xyz, 0)).r * _NoiseScale1.w;
    density += tex3Dlod(_NoiseTex, float4((worldPos + _NoiseScolling2.xyz * t) / _NoiseScale2.xyz, 0)).r * _NoiseScale2.w;
    density += tex3Dlod(_NoiseTex, float4((worldPos + _NoiseScolling3.xyz * t) / _NoiseScale3.xyz, 0)).r * _NoiseScale3.w;
    return saturate((density - _DensityOffset) * _DensityMultiplier);
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
    float transmittance = exp(-totalDensity * _LightAbsorption);
    float transmittanceClamp = exp(-_AttenuationClamp * _LightAbsorption);
    return max(max(transmittance, transmittanceClamp), totalDensity * _MinimumAttenuation);
}

float HG(float vdotl, float g) {
    float g2 = g*g;
    return (1 - g2) / (4 * 3.1415926 * pow(1 + g2 - 2 * g * vdotl, 1.5));
}

float Scatter(float vdotl) {
    float inScatter = max(HG(vdotl, _InScatter), _ExtraBrightIntensity * pow(vdotl, _ExtraBrightExponent));
    float outScatter = HG(vdotl, -_OutScatter);
    return lerp(inScatter, outScatter, _BlendScatter);
}

float4 frag (v2f i) : SV_Target {
    // calculate distance (not depth) to scene object
    float3 posVS = i.posVS.xyz / i.posVS.w;
    float2 screenUv = i.posProj.xy / i.posProj.w;
    float depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUv));
    float sceneDst = depth * length(posVS) / (-posVS.z);
    
    // calculate distance to volume box
    float3 rayDir = i.posWS - _WorldSpaceCameraPos;
    float2 boxHits = BoxIntersection(_WorldSpaceCameraPos, rayDir) * length(rayDir);
    float nearDist = max(0, boxHits.x);
    float farDist = min(min(sceneDst, boxHits.y), _MaxDistance);
    clip(farDist - nearDist);

    // blue noise
    float2 noiseUv = screenUv * _CameraDepthTexture_TexelSize.zw * _BlueNoise_TexelSize.xy;
    float blueNoise = tex2Dlod(_BlueNoise, float4(noiseUv, 0, 0)).r * _RandomStrength;

    // marching in volume
    float stepSize = (farDist - nearDist) / (_CloudStepNumber - 1);
    nearDist += (blueNoise - 0.5) * 2.0 * stepSize;
    rayDir = normalize(rayDir);

    float3 samplePos = _WorldSpaceCameraPos + rayDir * nearDist;
    float lightScatter = Scatter(dot(rayDir, _Light.xyz));

    float transmittance = 1;
    float lightEnergy = 0;
    [loop]
    for (uint i = 0; i < _CloudStepNumber; ++i) {
        float density = SampleDensity(samplePos) * stepSize;
        float lightTransmittance = GetLightTransmittance(samplePos, _Light);

        lightEnergy += density * transmittance * lightTransmittance * lightScatter;
        transmittance *= exp(-density * _LightAbsorption);

        if (transmittance < 0.001) {
            break;
        }
        samplePos += rayDir * stepSize;
    }

    float alpha = 1 - transmittance;
    float3 color = _CloudColor * _LightColor * lightEnergy;
    return float4(color, alpha);
}