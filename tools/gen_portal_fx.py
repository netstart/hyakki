"""Gera a arte procedural do portal para o 隠世 (Kakuriyo) em assets/art/fx/portal/.

Obra original do projeto Hyakki, liberada em CC0-1.0 (entrada `hyakki_portal_fx` em
licenses/registry.json). Só biblioteca padrão (PNG escrito à mão com zlib), sem
aleatoriedade: rodar de novo produz os mesmos bytes. Cores tiradas da paleta do Ninja
Adventure (Palette.png, CC0) para casar com o resto da arte; alfa binário (0 ou 255),
seguro para filtro "nearest".

- portal_loop.png: vórtice de 3 braços girando, 12 quadros 32x32 em tira (loop perfeito:
  o quadro 12 seria igual ao 0), centro escuro, aro claro com contorno de 1 px e faíscas
  que espiralam para dentro;
- portal_open.png: abertura, 8 quadros 32x32 em tira (ponto de luz que cresce até o
  tamanho do loop; tocar ao contrário serve de fechamento);
- torii.png: moldura de torii vermelho 48x48 (1 quadro), com o vão central de 26 px para
  o portal passar por trás.

Também atualiza só as linhas desta licença em assets/asset_index.json (hash e origem).
Depois rode o import do Godot para criar os .import.
Uso: python -I tools/gen_portal_fx.py
"""
import hashlib
import json
import math
import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "art" / "fx" / "portal"
LICENSE_ID = "hyakki_portal_fx"
TAU = 2.0 * math.pi
FRAME = 32
LOOP_FRAMES = 12
OPEN_FRAMES = 8
ARMS = 3

# Paleta do Ninja Adventure (subconjunto).
OUTLINE = (0x14, 0x1B, 0x1B)
VOID = (0x3B, 0x36, 0x43)
DEEP = (0x54, 0x3C, 0x52)
NIGHT = (0x4A, 0x52, 0x70)
TEAL = (0x2D, 0x69, 0x7B)
VIOLET = (0xA5, 0x60, 0x8B)
LILAC = (0xD3, 0xA2, 0xC0)
SKY = (0x79, 0xB8, 0xCE)
CYAN = (0x71, 0xDD, 0xEE)
FOAM = (0x8F, 0xEF, 0xF1)
WHITE = (0xF2, 0xEA, 0xF1)
VERMILION = (0xD1, 0x4B, 0x34)
ORANGE = (0xE4, 0x6D, 0x3A)
SHADE = (0x96, 0x53, 0x40)
WOOD = (0x4E, 0x48, 0x4A)


def blank(w: int, h: int) -> list:
    return [[None] * w for _ in range(h)]


def write_png(path: pathlib.Path, img: list) -> None:
    h, w = len(img), len(img[0])
    raw = bytearray()
    for row in img:
        raw.append(0)
        for px in row:
            raw.extend((0, 0, 0, 0) if px is None else (px[0], px[1], px[2], 255))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def outline(img: list) -> None:
    """Contorno escuro de 1 px em volta de tudo que é opaco (o estilo do Ninja Adventure)."""
    h, w = len(img), len(img[0])
    edge = []
    for y in range(h):
        for x in range(w):
            if img[y][x] is not None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and img[ny][nx] not in (None, OUTLINE):
                    edge.append((x, y))
                    break
    for x, y in edge:
        img[y][x] = OUTLINE


def vortex(phase: float, radius: float, flash: float = 0.0) -> list:
    """Um quadro do vórtice. phase em voltas de braço (0..1), radius em px, flash 0..1."""
    img = blank(FRAME, FRAME)
    c = (FRAME - 1) / 2.0
    if radius < 1.0:
        img[int(c)][int(c)] = WHITE
        return img
    for y in range(FRAME):
        for x in range(FRAME):
            dx, dy = x - c, y - c
            d = math.hypot(dx, dy)
            r = d / radius
            if r > 1.0:
                continue
            theta = math.atan2(dy, dx)
            # Braços em espiral: torcem para dentro e giram com a fase (período = 1 braço).
            s = math.sin(ARMS * theta + 9.0 * r - TAU * phase)
            if r > 0.86:
                # Aro: claro, com brilho que corre pela borda no mesmo período do loop.
                glint = math.sin(theta * 2.0 - TAU * phase * 2.0)
                img[y][x] = WHITE if glint > 0.82 else FOAM if glint > -0.2 else CYAN
            elif r < 0.2:
                img[y][x] = OUTLINE if r < 0.12 else VOID
            elif s > 0.55:
                img[y][x] = WHITE if r < 0.45 and s > 0.9 else CYAN if r > 0.5 else LILAC
            elif s > 0.1:
                img[y][x] = SKY if r > 0.55 else VIOLET
            elif s > -0.45:
                img[y][x] = TEAL if r > 0.55 else DEEP
            else:
                img[y][x] = NIGHT if r > 0.4 else VOID
            if flash > 0.0 and r < flash:
                img[y][x] = WHITE if r < flash * 0.6 else FOAM
    # Faíscas: 6 pontos que espiralam do lado de fora para o aro durante o loop.
    for k in range(6):
        t = (phase + k / 6.0) % 1.0
        ang = TAU * (k / 6.0) + TAU * t * 0.5
        dist = radius * (1.45 - 0.5 * t)
        sx, sy = int(round(c + math.cos(ang) * dist)), int(round(c + math.sin(ang) * dist))
        if radius >= 10.0 and 0 <= sx < FRAME and 0 <= sy < FRAME and img[sy][sx] is None:
            img[sy][sx] = WHITE if t < 0.5 else CYAN
    outline(img)
    return img


def strip(frames: list) -> list:
    out = []
    for y in range(FRAME):
        row = []
        for f in frames:
            row.extend(f[y])
        out.append(row)
    return out


def torii() -> list:
    w = h = 48
    img = blank(w, h)

    def rect(x0: int, y0: int, x1: int, y1: int, col: tuple) -> None:
        for y in range(max(0, y0), min(h, y1 + 1)):
            for x in range(max(0, x0), min(w, x1 + 1)):
                img[y][x] = col

    # Kasagi (viga de cima) com as pontas curvadas para cima e o shimaki escuro por cima.
    rect(3, 6, 44, 8, VERMILION)
    rect(3, 8, 44, 8, SHADE)
    rect(1, 4, 4, 6, VERMILION)
    rect(43, 4, 46, 6, VERMILION)
    rect(1, 3, 2, 4, VERMILION)
    rect(45, 3, 46, 4, VERMILION)
    rect(2, 2, 45, 3, WOOD)
    rect(5, 4, 42, 5, ORANGE)
    # Nuki (viga de baixo) e gakuzuka (placa do meio).
    rect(5, 14, 42, 16, VERMILION)
    rect(5, 16, 42, 16, SHADE)
    rect(21, 9, 26, 13, VERMILION)
    rect(22, 10, 25, 12, WOOD)
    # Pilares (hashira) com luz à esquerda e sombra à direita, base preta (kamaki).
    for x0 in (8, 37):
        rect(x0, 9, x0 + 2, 43, VERMILION)
        rect(x0, 9, x0, 43, ORANGE)
        rect(x0 + 2, 9, x0 + 2, 43, SHADE)
        rect(x0 - 1, 41, x0 + 3, 45, WOOD)
    outline(img)
    return img


def update_index(written: list) -> None:
    path = ROOT / "assets" / "asset_index.json"
    index = json.loads(path.read_text(encoding="utf-8"))
    index = [row for row in index if row.get("license_id") != LICENSE_ID]
    for file in written:
        index.append({
            "file": file.relative_to(ROOT).as_posix(),
            "source": "tools/gen_portal_fx.py",
            "license_id": LICENSE_ID,
            "sha256": hashlib.sha256(file.read_bytes()).hexdigest(),
        })
    index.sort(key=lambda item: item["file"])
    path.write_text(json.dumps(index, indent=1, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    full = FRAME / 2.0 - 2.0
    jobs = {
        "portal_loop.png": strip([vortex(f / LOOP_FRAMES, full) for f in range(LOOP_FRAMES)]),
        "portal_open.png": strip([
            # Fase escolhida para o último quadro da abertura emendar no quadro 0 do loop.
            vortex(((f - OPEN_FRAMES) / LOOP_FRAMES) % 1.0, full * ((f + 1) / OPEN_FRAMES) ** 0.8,
                   flash=max(0.0, 0.9 - f / (OPEN_FRAMES - 1)))
            for f in range(OPEN_FRAMES)]),
        "torii.png": torii(),
    }
    written = []
    for name, img in jobs.items():
        path = OUT / name
        write_png(path, img)
        written.append(path)
        print(f"{path.relative_to(ROOT).as_posix()}  {len(img[0])}x{len(img)}")
    update_index(written)
    print(f"{len(written)} arquivos gerados")
    return 0


if __name__ == "__main__":
    sys.exit(main())
