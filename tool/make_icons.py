"""Genera le icone del sito e dell'app installata dal logo FreeWay.

Usa il logo disegnato a mano (assets/logo.png) su fondo bianco. Uso, dalla
cartella del progetto:

    python3 tool/make_icons.py

Serve Pillow (`pip install pillow`). `badge()` disegna invece il badge rosso
della barra in alto (`LogoBadge`), se un giorno servisse: richiede il font
delle icone dalla cache di Flutter (`flutter precache`).
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


LOGO = ROOT / "assets" / "logo.png"


def logo_on_white(size: int, *, logo_ratio: float, radius_ratio: float = 0.0) -> Image.Image:
    """Il logo disegnato a mano (assets/logo.png) centrato su un quadrato
    bianco; [logo_ratio] è la frazione del lato occupata dal lato lungo del
    logo, [radius_ratio] arrotonda gli angoli (0 = quadrato pieno)."""
    big = size * SUPERSAMPLE
    logo = Image.open(LOGO).convert("RGBA")
    white = Image.new("RGBA", logo.size, (255, 255, 255, 255))
    logo = Image.alpha_composite(white, logo).convert("RGB")
    # Toglie i margini bianchi attorno al disegno.
    ink = Image.eval(logo.convert("L"), lambda v: 255 if v < 245 else 0)
    box = ink.getbbox()
    if box:
        logo = logo.crop(box)
    scale = big * logo_ratio / max(logo.size)
    logo = logo.resize(
        (round(logo.width * scale), round(logo.height * scale)), Image.LANCZOS
    )
    canvas = Image.new("RGBA", (big, big), (255, 255, 255, 255))
    canvas.paste(logo, ((big - logo.width) // 2, (big - logo.height) // 2))
    if radius_ratio > 0:
        mask = Image.new("L", (big, big), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, big - 1, big - 1), radius=round(big * radius_ratio), fill=255
        )
        canvas.putalpha(mask)
    return canvas.resize((size, size), Image.LANCZOS)


def main() -> None:
    icons = WEB / "icons"
    icons.mkdir(exist_ok=True)
    # Icone normali: logo su un quadrato bianco arrotondato.
    for size in (192, 512):
        logo_on_white(size, logo_ratio=0.84, radius_ratio=RADIUS_RATIO).save(
            icons / f"Icon-{size}.png", optimize=True
        )
    # Maskable: il sistema ritaglia la forma (anche un cerchio), quindi il
    # fondo riempie tutto e il logo resta nella zona sicura centrale.
    for size in (192, 512):
        logo_on_white(size, logo_ratio=0.58).save(
            icons / f"Icon-maskable-{size}.png", optimize=True
        )
    # iOS arrotonda da sé gli angoli e non vuole trasparenze.
    logo_on_white(180, logo_ratio=0.8).convert("RGB").save(
        icons / "apple-touch-icon.png", optimize=True
    )
    logo_on_white(64, logo_ratio=0.9, radius_ratio=0.18).save(
        WEB / "favicon.png", optimize=True
    )
    print("Icone generate in", WEB)


if __name__ == "__main__":
    main()
