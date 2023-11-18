using System;
using UnityEngine;

namespace SimpleRP.Runtime.PostProcessing
{
    [CreateAssetMenu(menuName = "Rendering/Custom Post FX Settings")]
    public class PostFXSettings : ScriptableObject
    {
        [Serializable]
        public struct BloomSettings
        {
            [Range(0, 16)] public int maxIterations;
            [Min(1)] public int downscaleLimit;
            [Min(0f)] public float threshold;
            [Range(0f, 1f)] public float thresholdKnee;

            [Min(0f)] public float intensity;
        }

        [Serializable]
        public struct FogSettings
        {
            [Range(0f, 1f)] public float Density;
            [Range(0f, 1f)] public float Strength;
            public Color Color;
        }

        [SerializeField] private Shader shader = default;
        [NonSerialized] private Material _material;

        [SerializeField] private BloomSettings _bloomSettings = default;
        [SerializeField] private FogSettings _fogSettings = default;
        public BloomSettings Bloom => _bloomSettings;
        public FogSettings Fog => _fogSettings;
        public ToneMappingMode toneMappingMode;

        public Material Material
        {
            get
            {
                if (_material == null && shader != null)
                {
                    _material = new Material(shader);
                    _material.hideFlags = HideFlags.HideAndDontSave;
                }

                return _material;
            }
        }

        public enum FXPass
        {
            BloomCombine,
            BloomHorizontal,
            BloomPrefilterPassFragment,
            BloomVertical,
            Copy,
            ToneMappingACES,
            DepthFog
        }

        public enum ToneMappingMode
        {
            None,
            ACES
        }
    }
}