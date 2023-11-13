using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace SimpleRP.Runtime.PostProcessing
{
    public partial class PostFXStack
    {
        public const string BufferName = "Post FX";

        private CommandBuffer _buffer = new CommandBuffer() { name = BufferName };
        private ScriptableRenderContext _context;
        private Camera _camera;
        private PostFXSettings _settings;
        private bool _useHDR;

        private int _fxSourceId = Shader.PropertyToID("_PostFXSource");
        private int _fxSourceId2 = Shader.PropertyToID("_PostFXSource2");

        private int[] _bloomMipUp;
        private int[] _bloomMipDown;

        private Vector2Int _screenRTSize;

        public PostFXStack()
        {
            _bloomMipUp = new int[_maxBloomPyramidLevels];
            _bloomMipDown = new int[_maxBloomPyramidLevels];

            //Get sequential texture id 
            for (int i = 0; i < _maxBloomPyramidLevels; i++)
            {
                _bloomMipUp[i] = Shader.PropertyToID("_BloomPyramidUp" + i);
                _bloomMipDown[i] = Shader.PropertyToID("_BloomPyramidDown" + i);
            }
        }

        public void Setup(ScriptableRenderContext context, Camera camera, PostFXSettings settings, bool useHDR,
            Vector2Int screenRTSize)
        {
            _context = context;
            _camera = camera;
            _useHDR = useHDR;
            _screenRTSize = screenRTSize;

            //Only GameView(1) and SceneView(2) camera will apply post fx
            if (camera.cameraType <= CameraType.SceneView && camera.CompareTag("MainCamera"))
            {
                _settings = settings;
            }
            else
            {
                _settings = null;
            }

            CheckApplySceneViewState();
        }

        public bool IsActive => _settings != null;

        public void Render(int sourceId)
        {
            if (DoBloom(sourceId))
            {
                _buffer.SetGlobalTexture(_fxSourceId2, _bloomResultRT);
                DoToneMapping(sourceId);
                _buffer.ReleaseTemporaryRT(_bloomResultRT);
            }
            else
            {
                _buffer.SetGlobalFloat(_bloomIntensityId, 0f);
                DoToneMapping(sourceId);
            }

            _context.ExecuteCommandBuffer(_buffer);
            _buffer.Clear();
        }

        private void Draw(RenderTargetIdentifier from, RenderTargetIdentifier to, PostFXSettings.FXPass pass)
        {
            //Set origin texture
            _buffer.SetGlobalTexture(_fxSourceId, from);
            //Then draw to render target
            _buffer.SetRenderTarget(to, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            _buffer.DrawProcedural(Matrix4x4.identity, _settings.Material, (int)pass, MeshTopology.Triangles, 3);
        }

        #region DoBloom

        private const int _maxBloomPyramidLevels = 16;
        private int _bloomPyramidId;
        private int _bloomPrefilterRT = Shader.PropertyToID("_BloomPrefilter");
        private int _bloomPrefilterId = Shader.PropertyToID("_BloomPrefilter");
        private int _bloomParamsId = Shader.PropertyToID("_Params");
        private int _bloomIntensityId = Shader.PropertyToID("_BloomIntensity");
        private int _bloomResultRT = Shader.PropertyToID("_BloomResult");

        private bool DoBloom(int sourceId)
        {
            var bloomSettings = _settings.Bloom;

            //Prefilter
            int width = _camera.pixelWidth >> 1;
            int height = _camera.pixelHeight >> 1;
            var format = _useHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default;

            //Bypass bloom if no need
            if (bloomSettings.maxIterations == 0 || bloomSettings.intensity <= 0 ||
                height < bloomSettings.downscaleLimit * 2 ||
                width < bloomSettings.downscaleLimit * 2)
            {
                return false;
            }

            // _buffer.BeginSample("Bloom");
            //Calu bloom parameters

            int mipCount = bloomSettings.maxIterations;

            float clamp = 65472f;
            float threshold = Mathf.GammaToLinearSpace(bloomSettings.threshold);
            float thresholdKnee = threshold * 0.5f;
            float scatter = Mathf.Lerp(0.05f, 0.95f, 0.7f);
            _buffer.SetGlobalVector(_bloomParamsId, new Vector4(scatter, clamp, threshold, thresholdKnee));
            _buffer.SetGlobalFloat(_bloomIntensityId, bloomSettings.intensity);

            //Prefilter
            for (int i = 0; i < bloomSettings.maxIterations; i++)
            {
                int cw = width >> i;
                int ch = height >> i;
                _buffer.GetTemporaryRT(_bloomMipUp[i], Mathf.Max(1, cw), Mathf.Max(1, ch), 0, FilterMode.Bilinear,
                    format);
                _buffer.GetTemporaryRT(_bloomMipDown[i], Mathf.Max(1, cw), Mathf.Max(1, ch), 0, FilterMode.Bilinear,
                    format);
            }

            Draw(sourceId, _bloomMipDown[0], PostFXSettings.FXPass.BloomPrefilterPassFragment);

            //Downsample
            var lastDown = _bloomMipDown[0];
            for (int i = 1; i < bloomSettings.maxIterations; i++)
            {
                Draw(lastDown, _bloomMipUp[i], PostFXSettings.FXPass.BloomHorizontal);
                Draw(_bloomMipUp[i], _bloomMipDown[i], PostFXSettings.FXPass.BloomVertical);

                lastDown = _bloomMipDown[i];
            }

            //Upsample
            for (int i = bloomSettings.maxIterations - 2; i >= 0; i--)
            {
                var lowMip = (i == mipCount - 2) ? _bloomMipDown[i + 1] : _bloomMipUp[i + 1];
                var highMip = _bloomMipDown[i];
                var dst = _bloomMipUp[i];

                _buffer.SetGlobalTexture(_fxSourceId2, lowMip);
                Draw(highMip, dst, PostFXSettings.FXPass.BloomCombine);

                _bloomResultRT = dst;
            }

            for (int i = 0; i < bloomSettings.maxIterations; i++)
            {
                _buffer.ReleaseTemporaryRT(_bloomMipDown[i]);

                if (_bloomMipUp[i] != _bloomResultRT)
                {
                    _buffer.ReleaseTemporaryRT(_bloomMipUp[i]);
                }
            }

            return true;

            //
            // _buffer.GetTemporaryRT(_bloomPrefilterRT, width, height, 0, FilterMode.Bilinear, format);
            //
            // int fromRT = _bloomPrefilterRT;
            // int toRT = _bloomPyramidId + 1;
            //
            // int i;
            // //Down sample
            // for (i = 0; i < bloomSettings.maxIterations; i++)
            // {
            //     if (height < bloomSettings.downscaleLimit || width < bloomSettings.downscaleLimit)
            //     {
            //         break;
            //     }
            //
            //     int midId = toRT - 1;
            //     _buffer.GetTemporaryRT(midId, width, height, 0, FilterMode.Bilinear, format);
            //     _buffer.GetTemporaryRT(toRT, width, height, 0, FilterMode.Bilinear, format);
            //     Draw(fromRT, midId, PostFXSettings.FXPass.BloomHorizontal);
            //     Draw(midId, toRT, PostFXSettings.FXPass.BloomVertical);
            //     fromRT = toRT;
            //     toRT += 2;
            //     width /= 2;
            //     height /= 2;
            // }
            //
            // //Set intensity when upsampleing when combine
            // _buffer.SetGlobalFloat(_bloomIntensityId, bloomSettings.intensity);
            // if (i > 1)
            // {
            //     _buffer.ReleaseTemporaryRT(fromRT - 1); //Release mid RT(fromId points to last toId)
            //     toRT -= 5;
            //
            //     //Up sample 
            //     for (i -= 1; i > 0; i--)
            //     {
            //         _buffer.SetGlobalTexture(_fxSourceId2, toRT + 1);
            //         Draw(fromRT, toRT, PostFXSettings.FXPass.BloomCombine);
            //         _buffer.ReleaseTemporaryRT(fromRT);
            //         _buffer.ReleaseTemporaryRT(toRT - 1);
            //         fromRT = toRT;
            //         toRT -= 2;
            //     }
            // }
            // else
            // {
            //     _buffer.ReleaseTemporaryRT(_bloomPyramidId);
            // }
            //
            // _buffer.SetGlobalTexture(_fxSourceId2, sourceId);
            // _buffer.GetTemporaryRT(_bloomResultRT, _camera.pixelWidth, _camera.pixelHeight, 0, FilterMode.Bilinear, format);
            // Draw(fromRT, _bloomResultRT, PostFXSettings.FXPass.BloomCombine);
            // _buffer.ReleaseTemporaryRT(fromRT);
            // _buffer.ReleaseTemporaryRT(_bloomPrefilterRT);
            // _buffer.EndSample("Bloom");

            return true;
        }

        #endregion

        #region DoToneMapping

        private void DoToneMapping(int sourceId)
        {
            PostFXSettings.FXPass pass;
            switch (_settings.toneMappingMode)
            {
                case PostFXSettings.ToneMappingMode.None:
                    pass = PostFXSettings.FXPass.Copy;
                    break;
                case PostFXSettings.ToneMappingMode.ACES:
                    pass = PostFXSettings.FXPass.ToneMappingACES;
                    break;
                default:
                    throw new ArgumentOutOfRangeException();
            }

            Draw(sourceId, BuiltinRenderTextureType.CameraTarget, pass);
        }

        #endregion
    }
}