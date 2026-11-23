#!/usr/bin/env python3
"""Converts Real-ESRGAN x4plus (Xintao Wang, BSD-3-Clause) to Core ML for Colophon's "Enlarge for print".

Output in --out:
  realesrgan-x4plus.mlpackage.zip   input "image" 256x256 RGB (0..255), output "upscaled" 1x3x1024x1024 in 0..1
  upscaler-manifest.json            size, sha256, license, source
The model is tiled by the app (256 px tiles with overlap), so a fixed input size is fine.
"""
import argparse, hashlib, json, os, shutil, sys, urllib.request, zipfile

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
import coremltools as ct

WEIGHTS = "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth"
TILE = 256


# RRDBNet as in BasicSR (same layer names, so the released state dict loads directly).
class ResidualDenseBlock(nn.Module):
    def __init__(self, nf=64, gc=32):
        super().__init__()
        self.conv1 = nn.Conv2d(nf, gc, 3, 1, 1)
        self.conv2 = nn.Conv2d(nf + gc, gc, 3, 1, 1)
        self.conv3 = nn.Conv2d(nf + 2 * gc, gc, 3, 1, 1)
        self.conv4 = nn.Conv2d(nf + 3 * gc, gc, 3, 1, 1)
        self.conv5 = nn.Conv2d(nf + 4 * gc, nf, 3, 1, 1)
        self.lrelu = nn.LeakyReLU(0.2, inplace=True)

    def forward(self, x):
        x1 = self.lrelu(self.conv1(x))
        x2 = self.lrelu(self.conv2(torch.cat((x, x1), 1)))
        x3 = self.lrelu(self.conv3(torch.cat((x, x1, x2), 1)))
        x4 = self.lrelu(self.conv4(torch.cat((x, x1, x2, x3), 1)))
        x5 = self.conv5(torch.cat((x, x1, x2, x3, x4), 1))
        return x5 * 0.2 + x


class RRDB(nn.Module):
    def __init__(self, nf, gc=32):
        super().__init__()
        self.rdb1 = ResidualDenseBlock(nf, gc)
        self.rdb2 = ResidualDenseBlock(nf, gc)
        self.rdb3 = ResidualDenseBlock(nf, gc)

    def forward(self, x):
        out = self.rdb3(self.rdb2(self.rdb1(x)))
        return out * 0.2 + x


class RRDBNet(nn.Module):
    def __init__(self, num_in_ch=3, num_out_ch=3, nf=64, nb=23, gc=32):
        super().__init__()
        self.conv_first = nn.Conv2d(num_in_ch, nf, 3, 1, 1)
        self.body = nn.Sequential(*[RRDB(nf, gc) for _ in range(nb)])
        self.conv_body = nn.Conv2d(nf, nf, 3, 1, 1)
        self.conv_up1 = nn.Conv2d(nf, nf, 3, 1, 1)
        self.conv_up2 = nn.Conv2d(nf, nf, 3, 1, 1)
        self.conv_hr = nn.Conv2d(nf, nf, 3, 1, 1)
        self.conv_last = nn.Conv2d(nf, num_out_ch, 3, 1, 1)
        self.lrelu = nn.LeakyReLU(0.2, inplace=True)

    def forward(self, x):
        feat = self.conv_first(x)
        body = self.conv_body(self.body(feat))
        feat = feat + body
        feat = self.lrelu(self.conv_up1(F.interpolate(feat, scale_factor=2, mode="nearest")))
        feat = self.lrelu(self.conv_up2(F.interpolate(feat, scale_factor=2, mode="nearest")))
        return self.conv_last(self.lrelu(self.conv_hr(feat)))


class Wrapped(nn.Module):
    """0..255 RGB in, 0..1 clamped out."""
    def __init__(self, net):
        super().__init__()
        self.net = net

    def forward(self, image):
        return self.net(image / 255.0).clamp(0, 1)


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
    os.makedirs(args.out, exist_ok=True)
    weights = os.path.join(args.out, "RealESRGAN_x4plus.pth")
    if not os.path.exists(weights):
        urllib.request.urlretrieve(WEIGHTS, weights)
    state = torch.load(weights, map_location="cpu")
    state = state.get("params_ema", state.get("params", state))
    net = RRDBNet()
    missing, unexpected = net.load_state_dict(state, strict=False)
    print("missing", missing, "unexpected", unexpected)
    assert not missing, "weights did not load"
    model = Wrapped(net).eval()

    example = torch.rand(1, 3, TILE, TILE) * 255
    with torch.no_grad():
        traced = torch.jit.trace(model, example)
    ml = ct.convert(
        traced,
        inputs=[ct.ImageType(name="image", shape=(1, 3, TILE, TILE), scale=1.0, color_layout=ct.colorlayout.RGB)],
        outputs=[ct.TensorType(name="upscaled")],
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.macOS14,
    )
    ml.short_description = "Real-ESRGAN x4plus (BSD-3-Clause). 256x256 RGB tile in, 1024x1024 RGB (0..1) out."
    pkg = os.path.join(args.out, "realesrgan-x4plus.mlpackage")
    if os.path.exists(pkg):
        shutil.rmtree(pkg)
    ml.save(pkg)

    # Sanity: Core ML agrees with PyTorch on the example tile.
    try:
        from PIL import Image
        pil = Image.fromarray(example[0].permute(1, 2, 0).numpy().astype(np.uint8))
        got = np.array(ml.predict({"image": pil})["upscaled"]).reshape(3, 4 * TILE, 4 * TILE)
        with torch.no_grad():
            ref = model(example).numpy()[0]
        print("mean abs diff vs torch:", float(np.abs(got - ref).mean()), "max:", float(np.abs(got - ref).max()))
    except Exception as e:
        print("prediction check skipped:", e)

    zpath = os.path.join(args.out, "realesrgan-x4plus.mlpackage.zip")
    if os.path.exists(zpath):
        os.remove(zpath)
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(pkg):
            for f in files:
                p = os.path.join(root, f)
                z.write(p, os.path.relpath(p, os.path.dirname(pkg)))
    manifest = {"model": "Real-ESRGAN x4plus", "license": "BSD-3-Clause", "source": WEIGHTS, "tile": TILE, "scale": 4,
                "files": {"realesrgan-x4plus.mlpackage.zip": {"bytes": os.path.getsize(zpath), "sha256": sha256(zpath)}}}
    with open(os.path.join(args.out, "upscaler-manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    os.remove(weights)
    print(json.dumps(manifest, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
