using SimpleRP.Runtime.PostProcessing;
using UnityEngine;
using UnityEngine.Rendering;

namespace SimpleRP.Runtime
{
    public partial class CameraRenderer
    {
        private const string BufferName = "Render Camera";

        private static readonly ShaderTagId FirstPassShaderTagId = new ShaderTagId("SRPDefaultUnlit");
        private static readonly ShaderTagId SecondPassShaderTagId = new ShaderTagId("SRPPass2");
        private static readonly ShaderTagId WorldSpaceCameraPos = new ShaderTagId("_WorldSpaceCameraPos");

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

            if (_postFXStack.IsActive)
            {
                _postFXStack.Render(_frameBufferId);
            }

            DrawGizmosAfterPostFX();

            Cleanup();

            Submit();
        }

        private void Setup()
        {
            _context.SetupCameraProperties(_camera);
            CameraClearFlags flags = _camera.clearFlags;

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
            // _buffer.BeginSample(SampleName);
            ExecuteBuffer();
        }

        private void DrawVisibleGeometry()
        {
            var sortingSettings = new SortingSettings(_camera)
            {
                criteria = SortingCriteria.CommonOpaque
            };
            var drawingSettings = new DrawingSettings(FirstPassShaderTagId, sortingSettings);
            drawingSettings.SetShaderPassName(1, SecondPassShaderTagId);
            var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

            _context.DrawRenderers(_cullingResults, ref drawingSettings, ref filteringSettings);
            _context.DrawSkybox(_camera);

            sortingSettings.criteria = SortingCriteria.CommonTransparent;
            drawingSettings.sortingSettings = sortingSettings;
            filteringSettings.renderQueueRange = RenderQueueRange.transparent;

            _context.DrawRenderers(_cullingResults, ref drawingSettings, ref filteringSettings);
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