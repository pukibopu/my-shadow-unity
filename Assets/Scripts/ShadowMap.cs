using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

public enum ShadowResolution
{
    Low=512,
    Medium=1024,
    High=2048
}
public class ShadowMap : MonoBehaviour
{
    [SerializeField] private ShadowResolution _resolution = ShadowResolution.Medium;

    [FormerlySerializedAs("_shadowBias")] [SerializeField, Range(0, 1)] private float shadowBias = 0.0001f;
    [FormerlySerializedAs("_shadowStrength")] [Range(0, 1)] public float shadowStrength = 1.0f;
    [SerializeField,Range(0, 10)]
    private float shadowFilterStride = 1.0f;
    
    private Shader _shadowMakerShader;
    private GameObject _lightCameraObj;
    private RenderTexture _shadowMapRt;
    private Camera _lightCamera;
    // Start is called before the first frame update

    private void OnEnable()
    {
        Clean();
        CreateCamera();
    }

    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        Matrix4x4 projectionMatrix = GL.GetGPUProjectionMatrix(_lightCamera.projectionMatrix, false);
        Shader.SetGlobalMatrix("_gWorldToShadow", projectionMatrix * _lightCamera.worldToCameraMatrix);
        
        Shader.SetGlobalFloat("_gShadowStrength", shadowStrength);
        Shader.SetGlobalFloat("_gShadow_bias", shadowBias);
        Shader.SetGlobalFloat("_gShadowFilterStride", shadowFilterStride);
        
        Shader.SetGlobalTexture("_gShadowMapTexture", _shadowMapRt);
        
        
    }
    
    void Clean()
    {
        for (int i = 0; i < transform.childCount; i++)
        {
            DestroyImmediate(transform.GetChild(0).gameObject);
        }
        RenderTexture.ReleaseTemporary(_shadowMapRt);
    }

    private void CreateCamera()
    {
        _lightCameraObj = new GameObject("Directional Light Cam");
        _lightCameraObj.transform.parent = transform;
        _lightCameraObj.transform.localPosition=Vector3.zero;
        _lightCameraObj.transform.localScale=Vector3.zero;
        _lightCameraObj.transform.localEulerAngles=Vector3.zero;

        _lightCamera = _lightCameraObj.AddComponent<Camera>();
        _lightCamera.backgroundColor=Color.white;
        _lightCamera.clearFlags = CameraClearFlags.SolidColor;
        _lightCamera.orthographic = true;
        _lightCamera.orthographicSize = 10f;
        _lightCamera.nearClipPlane = 0.3f;
        _lightCamera.farClipPlane = 100;
        _lightCamera.cullingMask = 1;
        _lightCamera.targetTexture = CreateRenderTexture(_lightCamera);


        if (_shadowMakerShader==null)
        {
            _shadowMakerShader=Shader.Find("Custom/ShadowMaker");
        }

        _lightCamera.SetReplacementShader(_shadowMakerShader, "");
    }

    private RenderTexture CreateRenderTexture(Camera cam)
    {
        if (_shadowMapRt)
        {
            RenderTexture.ReleaseTemporary(_shadowMapRt);
            _shadowMapRt = null;
        }

        RenderTextureFormat textureFormatRt = RenderTextureFormat.ARGB32;
        if (!SystemInfo.SupportsRenderTextureFormat(textureFormatRt))
        {
            textureFormatRt = RenderTextureFormat.Default;
        }

        var resolution = (int)_resolution;

        _shadowMapRt = RenderTexture.GetTemporary(resolution, resolution, 64, textureFormatRt);
        _shadowMapRt.hideFlags = HideFlags.DontSave;
        
        Shader.SetGlobalTexture("_gShadowMapTexture",_shadowMapRt);
        return _shadowMapRt;

    }
}
