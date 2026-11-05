#!/usr/bin/env python3
"""Converts OpenAI CLIP ViT-B/32 (MIT license) to Core ML for Colophon's taste engine.

Outputs, in --out:
  clip-vit-b32-image.mlpackage.zip   image encoder: input "image" (224x224 RGB, 0..255), output "embedding" (1x512, L2-normalized)
  clip-vit-b32-text.mlpackage.zip    text encoder: inputs "input_ids" (1x77 int32), "attention_mask" (1x77 int32), output "embedding"
  clip-tokenizer.zip                 vocab.json + merges.txt for the byte-level BPE tokenizer
  aesthetic-vit-b32.json             LAION linear aesthetic head on ViT-B/32 embeddings (weight[512], bias), when downloadable
  manifest.json                      names, sizes and sha256 of the above
"""
import argparse, hashlib, json, os, shutil, sys, urllib.request, zipfile

import numpy as np
import torch
import coremltools as ct
from transformers import CLIPModel, CLIPTokenizer

MODEL = "openai/clip-vit-base-patch32"
MEAN = [0.48145466, 0.4578275, 0.40821073]
STD = [0.26862954, 0.26130258, 0.27577711]


class ImageEncoder(torch.nn.Module):
    def __init__(self, m):
        super().__init__()
        self.m = m
        self.register_buffer("mean", torch.tensor(MEAN).view(1, 3, 1, 1))
        self.register_buffer("std", torch.tensor(STD).view(1, 3, 1, 1))

    def forward(self, image):
        x = (image - self.mean) / self.std
        f = self.m.get_image_features(pixel_values=x)
        return f / f.norm(dim=-1, keepdim=True)


class TextEncoder(torch.nn.Module):
    def __init__(self, m):
        super().__init__()
        self.m = m

    def forward(self, input_ids, attention_mask):
        f = self.m.get_text_features(input_ids=input_ids, attention_mask=attention_mask)
        return f / f.norm(dim=-1, keepdim=True)


def zip_dir(src, dst):
    if os.path.exists(dst):
        os.remove(dst)
    with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(src):
            for f in files:
                p = os.path.join(root, f)
                z.write(p, os.path.relpath(p, os.path.dirname(src)))


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="build/models")
    args = ap.parse_args()
    out = args.out
    os.makedirs(out, exist_ok=True)
    torch.manual_seed(0)

    model = CLIPModel.from_pretrained(MODEL).eval()
    tokenizer = CLIPTokenizer.from_pretrained(MODEL)

    # Image encoder.
    img = ImageEncoder(model).eval()
    example = torch.rand(1, 3, 224, 224) * 255
    traced = torch.jit.trace(img, example)
    ml_img = ct.convert(
        traced,
        inputs=[ct.ImageType(name="image", shape=(1, 3, 224, 224), scale=1.0, color_layout=ct.colorlayout.RGB)],
        outputs=[ct.TensorType(name="embedding")],
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.macOS14,
    )
    ml_img.short_description = "CLIP ViT-B/32 image encoder (OpenAI, MIT). Input: 224x224 RGB. Output: unit embedding."
    img_path = os.path.join(out, "clip-vit-b32-image.mlpackage")
    if os.path.exists(img_path):
        shutil.rmtree(img_path)
    ml_img.save(img_path)

    # Text encoder.
    txt = TextEncoder(model).eval()
    ids = torch.zeros(1, 77, dtype=torch.int32)
    ids[0, 0] = tokenizer.bos_token_id
    ids[0, 1] = tokenizer.eos_token_id
    mask = torch.zeros(1, 77, dtype=torch.int32)
    mask[0, :2] = 1
    traced_t = torch.jit.trace(txt, (ids, mask))
    ml_txt = ct.convert(
        traced_t,
        inputs=[ct.TensorType(name="input_ids", shape=(1, 77), dtype=np.int32),
                ct.TensorType(name="attention_mask", shape=(1, 77), dtype=np.int32)],
        outputs=[ct.TensorType(name="embedding")],
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.macOS14,
    )
    ml_txt.short_description = "CLIP ViT-B/32 text encoder (OpenAI, MIT). Inputs: 77 token ids + mask. Output: unit embedding."
    txt_path = os.path.join(out, "clip-vit-b32-text.mlpackage")
    if os.path.exists(txt_path):
        shutil.rmtree(txt_path)
    ml_txt.save(txt_path)

    # Sanity: the converted models agree with PyTorch on a sample.
    with torch.no_grad():
        ref_i = img(example).numpy()[0]
        ref_t = txt(ids, mask).numpy()[0]
    try:
        from PIL import Image
        pil = Image.fromarray(example[0].permute(1, 2, 0).numpy().astype(np.uint8))
        got_i = np.array(ml_img.predict({"image": pil})["embedding"]).reshape(-1)
        got_t = np.array(ml_txt.predict({"input_ids": ids.numpy(), "attention_mask": mask.numpy()})["embedding"]).reshape(-1)
        print("image cosine vs torch:", float(np.dot(ref_i, got_i) / (np.linalg.norm(ref_i) * np.linalg.norm(got_i))))
        print("text cosine vs torch:", float(np.dot(ref_t, got_t) / (np.linalg.norm(ref_t) * np.linalg.norm(got_t))))
    except Exception as e:  # prediction needs macOS; conversion still counts
        print("prediction check skipped:", e)

    zip_dir(img_path, os.path.join(out, "clip-vit-b32-image.mlpackage.zip"))
    zip_dir(txt_path, os.path.join(out, "clip-vit-b32-text.mlpackage.zip"))

    # Tokenizer files.
    tok_dir = os.path.join(out, "clip-tokenizer")
    os.makedirs(tok_dir, exist_ok=True)
    tokenizer.save_vocabulary(tok_dir)
    for f in os.listdir(tok_dir):
        if f not in ("vocab.json", "merges.txt"):
            os.remove(os.path.join(tok_dir, f))
    zip_dir(tok_dir, os.path.join(out, "clip-tokenizer.zip"))
    # Reference tokens so the Swift tokenizer can be checked against the real one.
    probes = ["a photo of a cat", "A moody, foggy literary novel cover.", "Grace Under Glass", "“Quiet” Hours — a memoir",
              "neon-lit cyberpunk thriller, hard-edged type", "cozy mystery with a teapot"]
    ref = {p: tokenizer(p, padding="max_length", max_length=77, truncation=True)["input_ids"] for p in probes}
    with open(os.path.join(out, "tokenizer-reference.json"), "w") as f:
        json.dump(ref, f)

    # LAION aesthetic head (MIT): a linear layer on ViT-B/32 embeddings.
    try:
        url = "https://github.com/LAION-AI/aesthetic-predictor/raw/main/sa_0_4_vit_b_32_linear.pth"
        tmp = os.path.join(out, "aesthetic.pth")
        urllib.request.urlretrieve(url, tmp)
        state = torch.load(tmp, map_location="cpu")
        w = state["weight"].reshape(-1).tolist()
        b = float(state["bias"].reshape(-1)[0])
        with open(os.path.join(out, "aesthetic-vit-b32.json"), "w") as f:
            json.dump({"model": "ViT-B/32", "weight": w, "bias": b, "source": url, "license": "MIT"}, f)
        os.remove(tmp)
    except Exception as e:
        print("aesthetic head skipped:", e)

    manifest = {"model": MODEL, "license": "MIT", "files": {}}
    for f in sorted(os.listdir(out)):
        p = os.path.join(out, f)
        if os.path.isfile(p) and f != "manifest.json":
            manifest["files"][f] = {"bytes": os.path.getsize(p), "sha256": sha256(p)}
    with open(os.path.join(out, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    sys.exit(main())
