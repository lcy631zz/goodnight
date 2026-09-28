# -*- coding: utf-8 -*-
"""Generate goodnight app icons - fully local & deterministic (no AI watermark).

Redesigned to kill the "AI-generated" feel:
  - FLAT & BOLD: only 2 colors (indigo bg + white emblem), no soft glow, no sparkles.
  - ONE dominant element: a white chat bubble with a crescent-moon cutout
    (negative space) -> reads as "night forum / goodnight chat" at a glance.
  - Strong silhouette that still reads at 60x60px.

Outputs under ../assets/icon/:
  icon.png                        1024 preview (square)
  icon_rounded_preview.png        1024 preview (squircle, how it looks on a phone)
  android_res/mipmap-*/ic_launcher.png             legacy icons (48/72/96/144/192)
  android_res/mipmap-*/ic_launcher_foreground.png  adaptive foreground (108..432)
  android_res/drawable/ic_launcher_background.xml  adaptive gradient bg
  android_res/mipmap-anydpi-v26/ic_launcher.xml    adaptive icon descriptor
"""
import os
from PIL import Image, ImageDraw, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "icon")
RES = os.path.join(OUT, "android_res")

BG_TOP = (59, 111, 224)   # #3B6FE0
BG_BOT = (46, 89, 199)    # #2E59C7  subtle deeper indigo (flat, not a glow)
WHITE = (255, 255, 255)

M = 4          # supersample factor (design space is 1024)
DEF = 1024


def sc(canvas, v):
    return v * canvas / DEF


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def make_bg(canvas):
    # 两色扁平竖向渐变（保持 bold，不是发光）
    gw = 64
    g = Image.new("RGB", (gw, gw))
    px = g.load()
    for y in range(gw):
        for x in range(gw):
            t = y / (gw - 1)
            px[x, y] = lerp(BG_TOP, BG_BOT, t)
    return g.resize((canvas, canvas), Image.BICUBIC).convert("RGBA")


def make_emblem(canvas):
    em = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))

    # --- dominant element: white chat bubble (rounded rect + tail) ---
    bx0, by0, bx1, by1 = sc(canvas, 286), sc(canvas, 300), sc(canvas, 774), sc(canvas, 700)
    rad = sc(canvas, 140)
    tail = [(sc(canvas, 356), sc(canvas, 672)),
            (sc(canvas, 288), sc(canvas, 866)),
            (sc(canvas, 502), sc(canvas, 694))]
    bub = Image.new("L", (canvas, canvas), 0)
    bd = ImageDraw.Draw(bub)
    bd.rounded_rectangle([bx0, by0, bx1, by1], radius=rad, fill=255)
    bd.polygon(tail, fill=255)
    em.paste(WHITE + (255,), (0, 0), bub)

    # --- crescent moon carved as a hole (background shows through) ---
    # sits centered inside the bubble with a clean margin on every side
    moon = Image.new("L", (canvas, canvas), 0)
    md = ImageDraw.Draw(moon)
    ox, oy, ro = sc(canvas, 552), sc(canvas, 500), sc(canvas, 138)
    kx, ky, rk = sc(canvas, 618), sc(canvas, 462), sc(canvas, 130)
    md.ellipse([ox - ro, oy - ro, ox + ro, oy + ro], fill=255)
    md.ellipse([kx - rk, ky - rk, kx + rk, ky + rk], fill=0)
    a = ImageChops.subtract(em.split()[3], moon)
    em.putalpha(a)
    return em


def rounded(img, ratio=0.225):
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, w - 1, h - 1], radius=int(w * ratio), fill=255)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def main():
    os.makedirs(RES, exist_ok=True)
    canvas = DEF * M
    full = make_bg(canvas)
    emblem = make_emblem(canvas)
    full.alpha_composite(emblem)

    preview = full.resize((1024, 1024), Image.LANCZOS)
    preview.convert("RGB").save(os.path.join(OUT, "icon.png"))
    rmask = rounded(preview, 0.225)
    bg = Image.new("RGB", (1024, 1024), (246, 246, 250))
    bg.paste(rmask, (0, 0), rmask)
    bg.save(os.path.join(OUT, "icon_rounded_preview.png"))

    for d, s in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        p = os.path.join(RES, "mipmap-" + d)
        os.makedirs(p, exist_ok=True)
        full.resize((s, s), Image.LANCZOS).convert("RGB").save(
            os.path.join(p, "ic_launcher.png"))

    # adaptive foreground: emblem scaled to ~88% and centered so it stays inside
    # Android's 66dp-of-108dp safe zone (aggressive launcher masks won't clip it)
    fg_canvas = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    inner = int(canvas * 0.88)
    small = emblem.resize((inner, inner), Image.LANCZOS)
    off = (canvas - inner) // 2
    fg_canvas.paste(small, (off, off), small)
    for d, s in {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}.items():
        p = os.path.join(RES, "mipmap-" + d)
        os.makedirs(p, exist_ok=True)
        fg_canvas.resize((s, s), Image.LANCZOS).save(
            os.path.join(p, "ic_launcher_foreground.png"))

    os.makedirs(os.path.join(RES, "drawable"), exist_ok=True)
    with open(os.path.join(RES, "drawable", "ic_launcher_background.xml"), "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n'
                '    <gradient android:type="linear" android:angle="135"\n'
                '        android:startColor="#3B6FE0" android:endColor="#2E59C7"/>\n'
                '</shape>\n')

    os.makedirs(os.path.join(RES, "mipmap-anydpi-v26"), exist_ok=True)
    with open(os.path.join(RES, "mipmap-anydpi-v26", "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@drawable/ic_launcher_background"/>\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '</adaptive-icon>\n')

    print("done ->", OUT)


if __name__ == "__main__":
    main()
