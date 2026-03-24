# ThermalGen — Executive Summary

## What It Does

ThermalGen translates ordinary **RGB (visible light) images into thermal infrared images**. Given a photo, it synthesizes a plausible corresponding thermal image as if captured by a thermal camera. This is the core capability: RGB → Thermal.

---

## How It Works (Architecture)

The model is a **latent diffusion system** built in three stages:

```
RGB Image
    │
    ▼
[RGB KL-VAE Encoder]  ──►  RGB latent (4ch)
                                │  (concatenated or cross-attended)
Random Noise (z)  ──────────────►  [SiT Transformer]  ──►  Thermal latent (4ch)
                                │                              │
Dataset class label (y) ────────►                        [Thermal KL-VAE Decoder]
                                                               │
                                                               ▼
                                                        Thermal Image (1ch)
```

1. **RGB KL-VAE** (Stable Diffusion VAE, frozen pretrained): encodes the input RGB image into a 4-channel latent at 1/8 resolution.
2. **SiT Transformer** (Scalable interpolant Transformer): a flow-matching diffusion backbone that denoises a random latent guided by the RGB latent. The RGB conditioning is injected via **concatenation** into each transformer block.
3. **Thermal KL-VAE** (custom-trained, 1-channel): decodes the output thermal latent back to pixel space as a grayscale thermal image.

The diffusion process uses **linear flow matching** (ODE path, velocity prediction) — a modern, faster alternative to DDPM.

---

## Inputs

| Input | Type | Notes |
|---|---|---|
| `RGB` | Tensor `[B, 3, H, W]`, float32 in `[-1, 1]` | Must be divisible by 16; typically resized to 256×256 |
| `dataset_idx` | Long tensor `[B]` | Integer class label (0–22) identifying which thermal sensor/dataset style to match. `1000` = unconditional |

---

## Key Parameters

| Parameter | Default (ThermalGen-XL-2) | Meaning |
|---|---|---|
| `arch` | `L` (also `XL`, `B`, `S`) | Transformer size. L = 24 layers, 1024 hidden, 16 heads |
| `patch_size` | `2` | Latent patch size for the SiT backbone |
| `cfg_scale` | `1.0` (train) / `2.0` (generate) | Classifier-free guidance strength. `1.0` = off, `>1.0` = stronger adherence to dataset style |
| `thermal_normalizer` | `0.95941` | Scales thermal VAE latents during encode/decode |
| `RGB_normalizer` | `0.18215` | Scales RGB VAE latents (matches SD VAE convention) |
| `injection_method` | `concat` | How RGB latent is fused into SiT — concatenation to each token |
| `transport_config` | `Linear / velocity` | Flow path type — ODE with velocity prediction |
| `num_classes` | `1000` | Class embedding table size (matches dataset indices 0–22, +null class) |

---

## Outputs

| Output | Type | Notes |
|---|---|---|
| `Pred_Thermal` | Tensor `[B, C, H, W]`, float32 in `[-1, 1]` | C = number of output channels from thermal VAE (typically 1 or 3 depending on VAE config). Cropped to match input spatial size |

In the demo, output is renormalized to `[0, 1]` and saved as a standard image (PNG).

---

## Dataset Labels (the `dataset_idx` conditioning)

The model was trained on **16 RGB-thermal paired datasets** spanning day/night, aerial, pedestrian, and driving scenes (KAIST, FLIR, LLVIP, AVIID, Boson, Freiburg, MSRS, etc.). Each gets a unique integer index (0–22). Passing a specific index steers the output toward that sensor's thermal style.

---

## Next Technical Steps

1. **Run inference** on your own imagery using `thermalgen_demo.py` — swap in your image, choose a `dataset_idx` matching your desired thermal domain.
2. **Tune `cfg_scale`** (try 2–4) to strengthen domain-conditional output quality.
3. **Fine-tune** on domain-specific RGB-thermal pairs by adding a new dataset entry with its own index to the config.
4. **Custom thermal VAE**: if you need a different output resolution or channel count, the `vae_config` block in the YAML is the entry point.
5. **Scale up**: swap `arch: L` → `arch: XL` for more capacity (28 layers, 1152 hidden) at higher compute cost.
