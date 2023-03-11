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
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma Shadow_Simple Shadow_PCF_Simple Shadow_PCF_Poisson Shadow_PCSS


            #include "UnityCG.cginc"
            #include "MyShadowUtils.cginc"

            float4 _Color;
            float4x4 _gWorldToShadow;
            sampler2D _gShadowMapTexture;
            float _gShadow_bias;
            float _gShadowStrength;
            float4 _gShadowMapTexture_TexelSize;
            float _gShadowFilterStride;
            float _SampelNumber;
            float _RingNumber;
            float _gLightWidth;


            #define NUM_SAMPLES 50
            #define NUM_RINGS 10


            struct v2f
            {
                float4 shadowCoord : TEXCOORD0;
                float4 pos : SV_POSITION;
            };


            float useShadowMap(sampler2D shadowMap, float3 coords)
            {
                float closestDepth = DecodeFloatRGBA(tex2D(shadowMap, coords.xy));

                float currentDepth = coords.z;

                float shadow = currentDepth - _gShadow_bias > closestDepth ? 0.0 : 1.0;

                return shadow;
            }


            float PCF_PoissonSample(sampler2D shadowMap, float3 coords)
            {
                createPoissonDisk(coords.xy);

                //float curDepth = coords.z;
                float shadow = 0.0;
                float2 offset = _gShadowMapTexture_TexelSize.xy * _gShadowFilterStride;
                for (int i = 0; i < NUM_SAMPLES; i++)
                {
                    float2 poissonCoords = poissonDisk[i] * offset + coords.xy;
                    shadow += useShadowMap(_gShadowMapTexture, float3(poissonCoords.xy, coords.z));
                }
                shadow /= float(NUM_SAMPLES);

                return shadow;
            }


            float PCF3x3(sampler2D shadowMap, float3 coords)
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

            // float PCF3x3_IGN(sampler2D shadowMap, float3 coords, float3 pos)
            // {
            //     float currentDep = coords.z;
            //     float shadow = 0.0;
            //     float2 offset = _gShadowMapTexture_TexelSize.xy * _gShadowFilterStride;
            //
            //     for (int i = -1; i <= 1; i++)
            //         for (int j = -1; j <= 1; j++)
            //         {
            //             float2 nowCoord = float2(i, j) * offset * IGN(pos.xy, 0) + coords.xy;
            //             float pcfDepth = DecodeFloatRGBA(tex2D(shadowMap, nowCoord));
            //             shadow += currentDep - _gShadow_bias > pcfDepth ? 0.0 : 1.0;
            //         }
            //     shadow /= 9.0;
            //     return shadow;
            // }

            float computedBlock(sampler2D shadowMap, float2 uv, float dReciver)
            {
                createPoissonDisk(uv);

                float Stride = _gShadowFilterStride + 5;
                float2 offset = _gShadowMapTexture_TexelSize.xy * Stride;

                int count=0;
                float dBlock=0.0;
                for(int i=0;i<NUM_SAMPLES;i++)
                {
                    float2 nowCoords=poissonDisk[i]*offset+uv;
                    float texDepth=DecodeFloatRGBA(tex2D(_gShadowMapTexture,nowCoords));
                    if(dReciver-_gShadow_bias>texDepth)
                    {
                        dBlock+=texDepth;
                        count+=1;
                    }
                }

                if (count == NUM_SAMPLES)
                {
                    return 2.0;
                }
                return  dBlock/float(count);
            }

            float PCSS(sampler2D shadowMap, float3 coords)
            {
                float dReciver = coords.z;
                float dBlock = computedBlock(shadowMap,coords.xy,dReciver);
                float wPenumbra = (dReciver - dBlock) * _gLightWidth / dBlock;


                float2 offset = _gShadowMapTexture_TexelSize * _gShadowFilterStride * wPenumbra;
                float shadow = 0.0;
                for (int i = 0; i < NUM_SAMPLES; i++)
                {
                    float2 nowCoords = poissonDisk[i] * offset + coords.xy;
                    float texDepth = DecodeFloatRGBA(tex2D(shadowMap, nowCoords));
                    float currentDepth = coords.z;
                    shadow += currentDepth - _gShadow_bias > texDepth ? 0.0 : 1.0;
                }
                shadow /= float(NUM_SAMPLES);
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
                #ifdef Shadow_Simple

                visibility=useShadowMap(_gShadowMapTexture,float4(coord, 1.0))
                
                # elif  Shadow_PCF_Simple
                visibility = PCF3x3(_gShadowMapTexture, float4(coord, 1.0));
                # elif Shadow_PCF_Poisson
                visibility = PCF_PoissonSample(_gShadowMapTexture, float4(coord, 1.0));
                #elif  Shadow_PCSS
                #endif

                //visibility = PCF3x3(_gShadowMapTexture, float4(coord, 1.0));
                //visibility = PCF3x3_IGN(_gShadowMapTexture, i.shadowCoord, i.pos);
                //visibility = PCF_PoissonSample(_gShadowMapTexture, float4(coord, 1.0));
                visibility = PCSS(_gShadowMapTexture, coord);
                visibility = lerp(1, visibility, _gShadowStrength);
                return _Color * visibility;
            }
            ENDCG
        }
    }
}