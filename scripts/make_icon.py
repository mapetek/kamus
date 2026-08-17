#!/usr/bin/env python3
"""Kâmus uygulama ikonunu üretir.

Logo, Türkçe imlasına özgü düzeltme işaretini (şapka) kahraman öge yapar:
krem rengi bir "a" ve üzerinde kehribar bir şapka. Şapka fontun kendi glifi
yerine elle çizilir; böylece küçük boyutlarda kalınlığı kontrol edilebiliyor.

Menü çubuğu için ayrı bir glif üretilmiyor: 18px'te "â" markası okunmuyor
(harfin gözü doluyor, şapka gövdeye karışıyor), bu yüzden orada SF Symbol
`book.fill` kullanılıyor — piksel hinting'i sayesinde net ve template olarak
açık/koyu menü çubuğuna kendiliğinden uyum sağlıyor.

Çıktılar (üretilmiş hâlleriyle repoya işlenir, derleme Python gerektirmez):
    Resources/AppIcon.icns
    Resources/AppIcon-preview.png   (README için)

Kullanım: python3 scripts/make_icon.py
"""

import math
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "Resources"
FONT_PATH = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"

# Renkler
INK_TOP = (30, 42, 90)      # #1E2A5A
INK_BOTTOM = (15, 22, 51)   # #0F1633
CREAM = (245, 239, 227)     # #F5EFE3
AMBER = (232, 163, 61)      # #E8A33D

# macOS Big Sur+ oranları: 1024 tuvalde ortalanmış 824'lük squircle
CANVAS = 1024
PLATE = 824
SUPERELLIPSE_N = 5.0        # Apple'ın squircle'ına yakın üs
SUPERSAMPLE = 4             # kenar yumuşatma için ölçek


def superellipse_mask(size: int, n: float = SUPERELLIPSE_N) -> Image.Image:
    """Squircle maskesi. Her satırın x genişliği analitik hesaplanır, bu yüzden
    yüksek çözünürlükte bile anlıktır; supersampling kenarları yumuşatır."""
    hi = size * SUPERSAMPLE
    mask = Image.new("L", (hi, hi), 0)
    draw = ImageDraw.Draw(mask)
    a = b = hi / 2.0
    for row in range(hi):
        y = (row + 0.5) - b
        t = 1.0 - abs(y / b) ** n
        if t <= 0:
            continue
        half = a * t ** (1.0 / n)
        draw.rectangle([a - half, row, a + half - 1, row], fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def vertical_gradient(size: int, top: tuple, bottom: tuple) -> Image.Image:
    grad = Image.new("RGB", (1, size))
    for y in range(size):
        f = y / max(size - 1, 1)
        grad.putpixel((0, y), tuple(round(top[i] + (bottom[i] - top[i]) * f) for i in range(3)))
    return grad.resize((size, size), Image.BICUBIC)


def draw_circumflex(draw: ImageDraw.ImageDraw, cx: float, apex_y: float,
                    width: float, height: float, thickness: float, color) -> None:
    """Yuvarlatılmış uçlu şapka (ˆ): tepe noktasından iki yana inen iki kalın kol."""
    half = width / 2.0
    left = (cx - half, apex_y + height)
    apex = (cx, apex_y)
    right = (cx + half, apex_y + height)
    draw.line([left, apex, right], fill=color, width=round(thickness), joint="curve")
    # joint="curve" yalnızca köşeyi yuvarlar; uçları da yuvarlatmak için birer daire
    r = thickness / 2.0
    for (px, py) in (left, right):
        draw.ellipse([px - r, py - r, px + r, py + r], fill=color)


def render_mark(size: int, letter_color, accent_color, glyph_scale: float = 0.70) -> Image.Image:
    """'â' markasını verilen tuval boyutunda saydam zemine çizer."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    font_size = round(size * glyph_scale)
    font = ImageFont.truetype(FONT_PATH, font_size)
    bbox = font.getbbox("a")
    a_w, a_h = bbox[2] - bbox[0], bbox[3] - bbox[1]

    # Şapka ölçüleri, "a" genişliğine oranlı. Tipografide düzeltme işareti
    # harften dar ve ona yakın durur; geniş/uzak olursa çatı gibi okunuyor.
    cx_width = a_w * 0.60
    cx_height = a_w * 0.24
    cx_thick = max(size * 0.046, 2.0)
    gap = a_w * 0.12

    group_h = cx_height + gap + a_h
    top = (size - group_h) / 2.0

    apex_y = top + cx_thick / 2.0
    a_x = (size - a_w) / 2.0 - bbox[0]
    a_y = top + cx_height + gap - bbox[1]

    draw.text((a_x, a_y), "a", font=font, fill=letter_color)
    draw_circumflex(draw, size / 2.0, apex_y, cx_width, cx_height, cx_thick, accent_color)
    return img


def build_app_icon(glyph_scale: float = 0.70) -> Image.Image:
    icon = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))

    plate = vertical_gradient(PLATE, INK_TOP, INK_BOTTOM).convert("RGBA")
    plate.putalpha(superellipse_mask(PLATE))

    # Üst kenarda hafif iç parlaklık (macOS'un camsı görünümü)
    sheen = Image.new("RGBA", (PLATE, PLATE), (0, 0, 0, 0))
    sheen_draw = ImageDraw.Draw(sheen)
    for y in range(round(PLATE * 0.42)):
        alpha = round(26 * (1 - y / (PLATE * 0.42)))
        sheen_draw.rectangle([0, y, PLATE, y], fill=(255, 255, 255, alpha))
    sheen.putalpha(Image.composite(sheen.getchannel("A"), Image.new("L", sheen.size, 0),
                                   superellipse_mask(PLATE)))
    plate = Image.alpha_composite(plate, sheen)

    mark = render_mark(PLATE, CREAM, AMBER, glyph_scale=glyph_scale)
    plate = Image.alpha_composite(plate, mark)

    icon.paste(plate, ((CANVAS - PLATE) // 2, (CANVAS - PLATE) // 2), plate)
    return icon


def build_icns(icon: Image.Image, small_icon: Image.Image) -> None:
    """32px ve altındaki temsiller kalınlaştırılmış masterdan üretilir: ince serif
    detaylar o ölçekte kayboluyor ve glif lekeye dönüşüyor."""
    iconset = RESOURCES / "AppIcon.iconset"
    if iconset.exists():
        shutil.rmtree(iconset)
    iconset.mkdir(parents=True)

    def emit(px: int, name: str) -> None:
        master = small_icon if px <= 32 else icon
        master.resize((px, px), Image.LANCZOS).save(iconset / name)

    for base in (16, 32, 128, 256, 512):
        emit(base, f"icon_{base}x{base}.png")
        emit(base * 2, f"icon_{base}x{base}@2x.png")

    subprocess.run(["iconutil", "-c", "icns", str(iconset),
                    "-o", str(RESOURCES / "AppIcon.icns")], check=True)
    shutil.rmtree(iconset)


def main() -> int:
    if not Path(FONT_PATH).exists():
        print(f"Font bulunamadı: {FONT_PATH}", file=sys.stderr)
        return 1
    RESOURCES.mkdir(exist_ok=True)

    icon = build_app_icon()
    icon.save(RESOURCES / "AppIcon-preview.png")
    build_icns(icon, build_app_icon(glyph_scale=0.86))

    print(f"Yazıldı: {RESOURCES/'AppIcon.icns'}, {RESOURCES/'AppIcon-preview.png'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
