"""Confere a arte da Google Play em docs/store/graphics (gerada por tools/make_store_art.gd):
tamanho exato em pixels, canal alfa e limite de bytes de cada espaço da Play Console.
Uso: python -I tools/check_store_graphics.py
"""
import pathlib
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
GRAPHICS = ROOT / "docs" / "store" / "graphics"
MB = 1024 * 1024
# PNG color type: 2 = RGB (24 bits), 6 = RGBA (32 bits).
RULES = [
    # (padrão, largura, altura, tipos de cor aceitos, bytes máximos, mínimo de arquivos)
    ("icon_512.png", 512, 512, {6}, 1 * MB, 1),
    ("launcher/icon_192.png", 192, 192, {6}, 1 * MB, 1),
    ("launcher/adaptive_*_432.png", 432, 432, {6}, 1 * MB, 3),
    ("feature_graphic_*.png", 1024, 500, {2}, 15 * MB, 3),
    # Referência na tela real do jogo (678×305 ×2): não vai para a Play (2,22:1 > 2:1).
    ("screenshots/raw/*/*.png", 1356, 610, {2}, 8 * MB, 16),
    ("screenshots/pt-BR/*.png", 1920, 1080, {2}, 8 * MB, 8),
    ("screenshots/en/*.png", 1920, 1080, {2}, 8 * MB, 8),
    ("tablet/7in/*/*.png", 2560, 1440, {2}, 8 * MB, 8),
    ("tablet/10in/*/*.png", 2560, 1440, {2}, 8 * MB, 8),
]


def png_info(path: pathlib.Path):
    data = path.read_bytes()[:33]
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        return None
    width, height, depth, color = struct.unpack(">IIBB", data[16:26])
    return width, height, depth, color


def main() -> int:
    errors = []
    seen = set()
    for pattern, w, h, colors, limit, minimum in RULES:
        files = sorted(GRAPHICS.glob(pattern))
        if len(files) < minimum:
            errors.append(f"{pattern}: {len(files)} arquivos (mínimo {minimum})")
        for f in files:
            seen.add(f)
            info = png_info(f)
            rel = f.relative_to(GRAPHICS).as_posix()
            if info is None:
                errors.append(f"{rel}: não é PNG")
                continue
            fw, fh, depth, color = info
            size = f.stat().st_size
            if (fw, fh) != (w, h):
                errors.append(f"{rel}: {fw}x{fh} (esperado {w}x{h})")
            if color not in colors or depth != 8:
                errors.append(f"{rel}: tipo de cor {color}/{depth} bits (esperado {sorted(colors)}/8)")
            if size > limit:
                errors.append(f"{rel}: {size} bytes (limite {limit})")
    for f in sorted(GRAPHICS.rglob("*.png")):
        if f not in seen:
            errors.append(f"{f.relative_to(GRAPHICS).as_posix()}: arquivo sem regra")
    for e in errors:
        print("ERRO", e)
    if errors:
        return 1
    print(f"OK arte da loja: {len(seen)} PNGs com tamanho, alfa e peso dentro dos limites da Play")
    return 0


if __name__ == "__main__":
    sys.exit(main())
