using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace SimpleRP.Runtime
{
    public partial class CameraRenderer
    {
        private const string BufferName = "Render Camera";

        private static readonly ShaderTagId FirstPassShaderTagId = new ShaderTagId("SRPDefaultForward");
        private static readonly ShaderTagId DeferredFirstPassShaderTagId = new ShaderTagId("SRPDefaultDeferred");
        private static readonly ShaderTagId SecondPassShaderTagId = new ShaderTagId("SRPPass2");
        private static readonly ShaderTagId WorldSpaceCameraPos = new ShaderTagId("_WorldSpaceCameraPos");
        private static readonly int InverseVPMatrix = Shader.PropertyToID("_InverseVPMatrix");

        private Camera _camera;
        private ScriptableRenderContext _context;
        private readonly CommandBuffer _buffer = new CommandBuffer { name = BufferName };
        private CullingResults _cullingResults;

        private PostProcessing.PostFXStack _postFXStack = new PostProcessing.PostFXStack();
        private static int _frameBufferId = Shader.PropertyToID("_CameraFrameBuffer");
        private bool _useHDR;
        private bool _useRenderScale;
        private static bool AllowHDR => SimpleRenderPipelineParameter.AllowHDR;
        private static float RenderScale => Mathf.Clamp(SimpleRenderPipelineParameter.RenderScale, 0.1f, 2f);

        private Vector2Int ScreenRTSize =>
            new((int)(_camera.pixelWidth * RenderScale), (int)(_camera.pixelHeight * RenderScale));

        public void Render(ScriptableRenderContext context, Camera camera)
        {
            _context = context;
            _camera = camera;
            _useHDR = camera.allowHDR && AllowHDR;

            _useRenderScale = RenderScale < 0.99f || RenderScale > 1.01f;

            PrepareBuffer();
            PrepareForSceneWindow();
            if (!Cull())
            {
                return;
            }

            _postFXStack.Setup(context, camera, SimpleRenderPipelineParameter.PostFXSettings, _useHDR, ScreenRTSize);
            Setup();
            DrawVisibleGeometry();
            DrawUnsupportedShaders();

            DrawGizmosBeforePostFX();

            if (SimpleRenderPipelineParameter.PipelineType == PipelineType.Deferred)
            {
                if (_postFXStack.IsActive)
                {
                    BlitToCameraDeferred(new RenderTargetIdentifier(_frameBufferId));
                    _postFXStack.Render(_frameBufferId);
                }
                else
                {
                    BlitToCameraDeferred(new(BuiltinRenderTextureType.CurrentActive));
                }
            }
            else
            {
                if (_postFXStack.IsActive)
                {
                    _postFXStack.Render(_frameBufferId);
                }
            }


            DrawGizmosAfterPostFX();

            Cleanup();

            Submit();
        }


        private void Setup()
        {
            _context.SetupCameraProperties(_camera);
            CameraClearFlags flags = _camera.clearFlags;

            switch (SimpleRenderPipelineParameter.PipelineType)
            {
                case PipelineType.Forward:
                    SetupForward(flags);
                    break;
                case PipelineType.Deferred:
                    SetupDeferred(flags);
                    break;
                default:
                    throw new ArgumentOutOfRangeException();
            }

            // _buffer.BeginSample(SampleName);
            ExecuteBuffer();
        }

        RenderTargetIdentifier[] deferredRTs;
        RenderTargetIdentifier deferredDepthRT;
        int deferredDepthRTID;
        int[] deferredRTIDs;

        private void SetupDeferred(CameraClearFlags flags)
        {
            if (deferredRTIDs == null)
            {
                deferredRTIDs = new int[2];
                deferredRTs = new RenderTargetIdentifier[2];

                deferredRTIDs[0] = Shader.PropertyToID("_GBuffer0");
                deferredRTIDs[1] = Shader.PropertyToID("_GBuffer1");
                deferredDepthRTID = Shader.PropertyToID("_GBufferDepth");

                deferredRTs[0] = new RenderTargetIdentifier(deferredRTIDs[0]);
                deferredRTs[1] = new RenderTargetIdentifier(deferredRTIDs[1]);
                deferredDepthRT = new RenderTargetIdentifier(deferredDepthRTID);
            }

            //0:Albedo.xyz + metallic
            //1:normal.xyz + roughness
            //Depth: depth 32bit single float

            //Get Temporary G-Buffer here
            _buffer.GetTemporaryRT(deferredRTIDs[0], ScreenRTSize.x, ScreenRTSize.y, 0, FilterMode.Point,
                RenderTextureFormat.ARGBHalf);

            _buffer.GetTemporaryRT(deferredRTIDs[1], ScreenRTSize.x, ScreenRTSize.y, 0, FilterMode.Point,
                RenderTextureFormat.ARGBHalf);

            _buffer.GetTemporaryRT(deferredDepthRTID, ScreenRTSize.x, ScreenRTSize.y, 0, FilterMode.Point,
                RenderTextureFormat.RFloat);

            _buffer.SetRenderTarget(deferredRTs, deferredDepthRTID);
        }

        private void SetupForward(CameraClearFlags flags)
        {
            if (_postFXStack.IsActive)
            {
                //To prevent random result
                if (flags > CameraClearFlags.Color)
                {
                    //Left skybox(1) or color(2) flag here
                    flags = CameraClearFlags.Color;
                }

                //Set render target here
                _buffer.GetTemporaryRT(
                    _frameBufferId,
                    ScreenRTSize.x,
                    ScreenRTSize.y,
                    32,
                    FilterMode.Bilinear,
                    _useHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default);

                _buffer.SetRenderTarget(_frameBufferId,
                    RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            }

            _buffer.ClearRenderTarget(flags <= CameraClearFlags.Depth, flags <= CameraClearFlags.Color,
                flags == CameraClearFlags.Color ? _camera.backgroundColor.linear : Color.clear);
        }

        private void DrawVisibleGeometry()
        {
            var sortingSettings = new SortingSettings(_camera)
            {
                criteria = SortingCriteria.CommonOpaque
            };

            var drawingSettings = new DrawingSettings();
            if (SimpleRenderPipelineParameter.PipelineType == PipelineType.Deferred)
            {
                //Draw opaque
                drawingSettings.SetShaderPassName(0, DeferredFirstPassShaderTagId);

                var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

                _context.DrawRenderers(_cullingResults, ref drawingSettings, ref filteringSettings);
            }
            else
            {
                //Draw opaque
                drawingSettings.SetShaderPassName(0, FirstPassShaderTagId);
                drawingSettings.SetShaderPassName(1, SecondPassShaderTagId);

                var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

                _context.DrawRenderers(_cullingResults, ref drawingSettings, ref filteringSettings);
                _context.DrawSkybox(_camera);

                //Draw transparent
                sortingSettings.criteria = SortingCriteria.CommonTransparent;
                drawingSettings.sortingSettings = sortingSettings;
                filteringSettings.renderQueueRange = RenderQueueRange.transparent;

                _context.DrawRenderers(_cullingResults, ref drawingSettings, ref filteringSettings);
            }
        }

        private void BlitToCameraDeferred(RenderTargetIdentifier target)
        {
            //Pass inverse VP matrix to shader
            Matrix4x4 proj = GL.GetGPUProjectionMatrix(_camera.projectionMatrix, false);
            Matrix4x4 vp = proj * _camera.worldToCameraMatrix;
            _buffer.SetGlobalMatrix(InverseVPMatrix, vp.inverse);
            
            _buffer.SetGlobalTexture(deferredRTIDs[0], deferredRTs[0]);
            _buffer.SetGlobalTexture(deferredRTIDs[1], deferredRTs[1]);
            _buffer.SetGlobalTexture(deferredDepthRTID, deferredDepthRT);
            _buffer.SetRenderTarget(target);
            _buffer.DrawProcedural(Matrix4x4.identity, DeferredPostProcessMaterial, 0, MeshTopology.Triangles, 3);

            _buffer.ReleaseTemporaryRT(deferredRTIDs[0]);
            _buffer.ReleaseTemporaryRT(deferredRTIDs[1]);
            _buffer.ReleaseTemporaryRT(deferredDepthRTID);
        }

        private Material _material;

        public Material DeferredPostProcessMaterial
        {
            get
            {
                if (_material == null)
                {
                    Shader deferredPostShader = Shader.Find("Hidden/Custom RP/Deferred Post Process");
                    _material = new Material(deferredPostShader);
                    _material.hideFlags = HideFlags.HideAndDontSave;
                }

                return _material;
            }
        }


        private void Submit()
        {
            // _buffer.EndSample(SampleName);
            ExecuteBuffer();
            _context.Submit();
        }

        private void ExecuteBuffer()
        {
            _context.ExecuteCommandBuffer(_buffer);
            _buffer.Clear();
        }

        private bool Cull()
        {
            if (_camera.TryGetCullingParameters(out var p))
            {
                _cullingResults = _context.Cull(ref p);
                return true;
            }

            return false;
        }

        private void Cleanup()
        {
            if (_postFXStack.IsActive)
            {
                _buffer.ReleaseTemporaryRT(_frameBufferId);
            }
        }
    }
}