Shader "Custom/ShadowReciver"
{
    Properties
    {
        _Color("Color",Color)=(1,1,1,1)
        _SampleNumber("Sample Number",Range(1,100))=16
        _RingNumber("Ring Number",Range(1,100))=10
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            #include "UnityCG.cginc"

            float4 _Color;
            float4x4 _gWorldToShadow;
            sampler2D _gShadowMapTexture;
            float _gShadow_bias;
            float _gShadowStrength;
            float4 _gShadowMapTexture_TexelSize;
            float _gShadowFilterStride;
            float _SampelNumber;
            float _RingNumber;


            #define NUM_SAMPLES 50
            #define NUM_RINGS 10


            struct v2f
            {
                float4 shadowCoord : TEXCOORD0;
                float4 pos : SV_POSITION;
            };

            float IGN(float2 pixCoord, int frameCount)
            {
                const float3 magic = float3(0.06711056f, 0.00583715f, 52.9829189f);
                float2 frameMagicScale = float2(2.083f, 4.867f);
                pixCoord += frameCount * frameMagicScale;
                return frac(magic.z * frac(dot(pixCoord, magic.xy)));
            }

            float useShadowMap(sampler2D shadowMap, float4 coords)
            {
                float closestDepth = DecodeFloatRGBA(tex2D(shadowMap, coords.xy));

                float currentDepth = coords.z;

                float shadow = currentDepth - _gShadow_bias > closestDepth ? 0.0 : 1.0;

                return shadow;
            }

            float rand_2to1(float2 uv)
            {
                // 0 - 1
                float a = 12.9898, b = 78.233, c = 43758.5453;
                float dt = dot(uv.xy, float2(a, b));
                return frac(sin(dt) * c);
            }


            float2 poissonDisk[NUM_SAMPLES];

            void createPoissonDisk(float2 seed)
            {
                float deltaAngle = UNITY_TWO_PI * float(_RingNumber) / float(NUM_SAMPLES);
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


            
            float PCF_PoissonSample(sampler2D shadowMap, float4 coords)
            {
                createPoissonDisk(coords.xy);

                float curDepth = coords.z;
                float shadow = 0.0;
                float2 offset = _gShadowMapTexture_TexelSize.xy * _gShadowFilterStride;
                for(int i=0;i<NUM_SAMPLES;i++)
                {
                    float2 poissonCoords=poissonDisk[i]*offset+coords.xy;
                    float texDepth=DecodeFloatRGBA(tex2D(_gShadowMapTexture,poissonCoords));
                    shadow+=curDepth-_gShadow_bias>texDepth?0.0:1.0;
                }
                shadow/=float(NUM_SAMPLES);

                return shadow;
            }



            float PCF3x3(sampler2D shadowMap, float4 coords)
            {
                float currentDep = coords.z;
                float shadow = 0.0;
                float2 offset = _gShadowMapTexture_TexelSize.xy * _gShadowFilterStride;

                for (int i = -1; i <= 1; i++)
                    for (int j = -1; j <= 1; j++)
                    {
                        float2 nowCoord = float2(i, j) * offset + coords.xy;
                        float pcfDepth = DecodeFloatRGBA(tex2D(shadowMap, nowCoord));
                        shadow += currentDep - _gShadow_bias > pcfDepth ? 0.0 : 1.0;
                    }
                shadow /= 9.0;
                return shadow;
            }

            float PCF3x3_IGN(sampler2D shadowMap, float4 coords, float3 pos)
            {
                float currentDep = coords.z;
                float shadow = 0.0;
                float2 offset = _gShadowMapTexture_TexelSize.xy * _gShadowFilterStride;

                for (int i = -1; i <= 1; i++)
                    for (int j = -1; j <= 1; j++)
                    {
                        float2 nowCoord = float2(i, j) * offset * IGN(pos.xy, 0) + coords.xy;
                        float pcfDepth = DecodeFloatRGBA(tex2D(shadowMap, nowCoord));
                        shadow += currentDep - _gShadow_bias > pcfDepth ? 0.0 : 1.0;
                    }
                shadow /= 9.0;
                return shadow;
            }


            v2f vert(appdata_full v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.shadowCoord = mul(_gWorldToShadow, worldPos);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 coord = 0;
                i.shadowCoord.xyz = i.shadowCoord.xyz / i.shadowCoord.w;

                coord.xy = i.shadowCoord.xy * 0.5 + 0.5;
                #if defined(SHADER_TARGET_GLSL)
                    coord.z = i.shadowCoord.z * 0.5 + 0.5; //[-1, 1]-->[0, 1]
                #elif defined(UNITY_REVERSED_Z)
                coord.z = 1 - i.shadowCoord.z; //[1, 0]-->[0, 1]
                #endif

                float visibility = 1;
                //visibility = PCF3x3(_gShadowMapTexture, float4(coord, 1.0));
                //visibility = PCF3x3_IGN(_gShadowMapTexture, i.shadowCoord, i.pos);
                visibility = PCF_PoissonSample(_gShadowMapTexture, float4(coord, 1.0));
                visibility = lerp(1, visibility, _gShadowStrength);
                return _Color * visibility;
            }
            ENDCG
        }
    }
}