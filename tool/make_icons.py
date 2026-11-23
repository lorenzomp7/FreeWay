"""Genera le icone del sito e dell'app installata dal logo della barra in alto.

Disegna lo stesso badge di `LogoBadge` (lib/widgets/common.dart): quadrato
arrotondato con il gradiente del marchio e l'icona Material `route_rounded`
bianca. Uso, dalla cartella del progetto con Flutter installato:

    python3 tool/make_icons.py

Serve Pillow (`pip install pillow`). Il font delle icone si prende dalla cache
di Flutter (`flutter precache` lo scarica).
"""

from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "web"

# AppPalette.primaryLight -> AppPalette.primary (lib/theme/app_theme.dart).
GRADIENT_START = (0xFF, 0x55, 0x66)
GRADIENT_END = (0xEC, 0x04, 0x14)
ROUTE_ROUNDED = 0xF0377  # Icons.route_rounded

# Proporzioni di LogoBadge: lato 30, raggio 9.6, icona 17.4.
RADIUS_RATIO = 9.6 / 30
GLYPH_RATIO = 17.4 / 30

SUPERSAMPLE = 4


def material_font() -> Path:
    candidates = []
    flutter = shutil.which("flutter")
    if flutter:
        candidates.append(Path(flutter).resolve().parent / "cache")
    candidates.append(Path.home() / "flutter" / "bin" / "cache")
    if os.environ.get("FLUTTER_ROOT"):
        candidates.append(Path(os.environ["FLUTTER_ROOT"]) / "bin" / "cache")
    for cache in candidates:
        font = cache / "artifacts" / "material_fonts" / "MaterialIcons-Regular.otf"
        if font.exists():
            return font
    sys.exit("MaterialIcons-Regular.otf non trovato: esegui `flutter precache`.")


def gradient(size: int) -> Image.Image:
    """Gradiente diagonale dall'angolo in alto a sinistra a quello in basso a destra."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    span = 2 * (size - 1) or 1
    for y in range(size):
        for x in range(size):
            t = (x + y) / span
            px[x, y] = tuple(
                round(a + (b - a) * t) for a, b in zip(GRADIENT_START, GRADIENT_END)
            )
    return img


def badge(size: int, font_path: Path, *, rounded: bool, glyph_ratio: float) -> Image.Image:
    big = size * SUPERSAMPLE
    img = gradient(big).convert("RGBA")
    if rounded:
        mask = Image.new("L", (big, big), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, big - 1, big - 1), radius=round(big * RADIUS_RATIO), fill=255
        )
        img.putalpha(mask)

    glyph_size = round(big * glyph_ratio)
    font = ImageFont.truetype(str(font_path), glyph_size)
    char = chr(ROUTE_ROUNDED)
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    left, top, right, bottom = draw.textbbox((0, 0), char, font=font)
    x = (big - (right - left)) / 2 - left
    y = (big - (bottom - top)) / 2 - top
    draw.text((x, y), char, font=font, fill=(255, 255, 255, 255))
    img = Image.alpha_composite(img, layer)
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    font = material_font()
    icons = WEB / "icons"
    icons.mkdir(exist_ok=True)
    # Icone normali: badge arrotondato come nell'app, su fondo trasparente.
    for size in (192, 512):
        badge(size, font, rounded=True, glyph_ratio=GLYPH_RATIO).save(
            icons / f"Icon-{size}.png", optimize=True
        )
    # Maskable: il sistema ritaglia la forma, quindi il fondo riempie tutto e
    # l'icona resta nella zona sicura (cerchio dell'80% centrale).
    for size in (192, 512):
        badge(size, font, rounded=False, glyph_ratio=0.5).save(
            icons / f"Icon-maskable-{size}.png", optimize=True
        )
    # iOS arrotonda da sé gli angoli e non vuole trasparenze.
    badge(180, font, rounded=False, glyph_ratio=0.58).convert("RGB").save(
        icons / "apple-touch-icon.png", optimize=True
    )
    badge(64, font, rounded=True, glyph_ratio=GLYPH_RATIO).save(
        WEB / "favicon.png", optimize=True
    )
    print("Icone generate in", WEB)


if __name__ == "__main__":
    main()
