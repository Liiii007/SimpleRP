using SimpleRP.Runtime.PostProcessing;
using UnityEngine;
using UnityEngine.Rendering;

namespace SimpleRP.Runtime
{
    public enum PipelineType
    {
        Forward, Deferred
    }
    
    [CreateAssetMenu(menuName = "Rendering/Custom Render Pipeline")]
    public class SimpleRenderPipelineAsset : RenderPipelineAsset
    {
        [SerializeField] private PostFXSettings postFXSettings = default;
        [SerializeField] private bool allowHDR = true;
        [SerializeField] [Range(0.1f, 2f)] private float renderScale = 1f;
        [SerializeField] private PipelineType pipelineType = PipelineType.Forward;

        protected override RenderPipeline CreatePipeline()
        {
            SimpleRenderPipelineParameter.PostFXSettings = postFXSettings;
            SimpleRenderPipelineParameter.AllowHDR = allowHDR;
            SimpleRenderPipelineParameter.RenderScale = renderScale;
            SimpleRenderPipelineParameter.PipelineType = pipelineType;

            return new SimpleRenderPipeline();
        }
    }
}