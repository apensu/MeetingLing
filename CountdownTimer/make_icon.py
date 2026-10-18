#!/usr/bin/env python3
# 把 ice_cream.ico 转成 macOS 的 AppIcon.icns（含 Retina 各档尺寸）
import os
from PIL import Image

ICO = "/Users/suyx2/Documents/My/delphi/ice_cream.ico"
HERE = os.path.dirname(os.path.abspath(__file__))
ICONSET = os.path.join(HERE, "AppIcon.iconset")
ICNS = os.path.join(HERE, "AppIcon.icns")

os.makedirs(ICONSET, exist_ok=True)

img = Image.open(ICO)
# 若 ico 内含多帧，取分辨率最高的一帧
if getattr(img, "n_frames", 1) > 1:
    best = img
    best_px = 0
    for i in range(img.n_frames):
        img.seek(i)
        w, h = img.size
        if w * h > best_px:
            best_px = w * h
            best = img.copy()
    img = best
img = img.convert("RGBA")

base = img.resize((1024, 1024), Image.LANCZOS)

sizes = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}
for name, size in sizes.items():
    base.resize((size, size), Image.LANCZOS).save(os.path.join(ICONSET, name), "PNG")

os.system(f'iconutil -c icns "{ICONSET}" -o "{ICNS}"')
print("已生成:", ICNS)
print("大小:", os.path.getsize(ICNS), "字节")
