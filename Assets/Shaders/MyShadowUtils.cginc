#include "UnityCG.cginc"

#define NUM_SAMPLES 50
#define NUM_RINGS 10
float2 poissonDisk[NUM_SAMPLES];

float rand_2to1(float2 uv)
{
    // 0 - 1
    float a = 12.9898, b = 78.233, c = 43758.5453;
    float dt = dot(uv.xy, float2(a, b));
    return frac(sin(dt) * c);
}

void createPoissonDisk(float2 seed)
{
    float deltaAngle = UNITY_TWO_PI * float(NUM_RINGS) / float(NUM_SAMPLES);
    float deltaNum = 1.0 / float(NUM_SAMPLES);

    float angel = rand_2to1(seed) * UNITY_TWO_PI;
    float radius = deltaNum;
    float deltaRadius = deltaNum;

    for (int i = 0; i < NUM_SAMPLES; i++)
    {
        poissonDisk[i] = float2(cos(angel), sin(angel)) * pow(radius, 0.5);
        angel += deltaAngle;
        radius += deltaRadius;
    }
}

float IGN(float2 pixCoord, int frameCount)
{
    const float3 magic = float3(0.06711056f, 0.00583715f, 52.9829189f);
    float2 frameMagicScale = float2(2.083f, 4.867f);
    pixCoord += frameCount * frameMagicScale;
    return frac(magic.z * frac(dot(pixCoord, magic.xy)));
}


