"""Monta a tira Idle.png (respiração em 4 quadros) dos chefes intermediários que só têm um
quadro parado (Sprite.png da FreeMix, de pixel-boy e AAA).

Cada quadro tem o tamanho do original. A parte de baixo (40% da altura) fica parada no chão
e a de cima é achatada em 0, 1, 2 e 1 px, tirando linhas espalhadas e descendo o resto: um
"respirar" sem misturar cores (pixel art limpa, alfa intacto). É uma modificação permitida
pela licença do pack (`pixelboy_freemix` em licenses/registry.json): as linhas do índice
continuam com essa licença.

Só biblioteca padrão (PNG RGBA 8 bits lido e escrito com zlib); determinístico.
Rode depois do tools/sync_assets.py, que copia os Sprite.png.
Uso: python -I tools/make_midboss_idle.py
"""
import hashlib
import json
import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
LICENSE_ID = "pixelboy_freemix"
STAGES = ("yomi", "dunes")
SQUASH = (0, 1, 2, 1)
FIXED_BOTTOM = 0.4


def read_png(path: pathlib.Path) -> list:
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    pos, idat, w = 8, b"", 0
    while pos < len(data):
        size = struct.unpack(">I", data[pos:pos + 4])[0]
        tag, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + size]
        if tag == b"IHDR":
            w, h, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
            assert depth == 8 and ctype == 6 and interlace == 0, f"{path}: só PNG RGBA 8 bits"
        elif tag == b"IDAT":
            idat += body
        pos += 12 + size
    raw = zlib.decompress(idat)
    stride = w * 4
    rows, prev = [], bytearray(stride)
    for y in range(len(raw) // (stride + 1)):
        f = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - 4] if i >= 4 else 0
            b = prev[i]
            c = prev[i - 4] if i >= 4 else 0
            if f == 1:
                line[i] = (line[i] + a) & 0xFF
            elif f == 2:
                line[i] = (line[i] + b) & 0xFF
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 0xFF
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 0xFF
        rows.append([tuple(line[x * 4:x * 4 + 4]) for x in range(w)])
        prev = line
    return rows


def write_png(path: pathlib.Path, img: list) -> None:
    h, w = len(img), len(img[0])
    raw = bytearray()
    for row in img:
        raw.append(0)
        for px in row:
            raw.extend(px)

    def chunk(tag: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def squash(img: list, px: int) -> list:
    h, w = len(img), len(img[0])
    if px == 0:
        return [list(r) for r in img]
    cut = int(h * (1.0 - FIXED_BOTTOM))
    top = [y for y in range(h) if any(p[3] for p in img[y])]
    first = top[0] if top else 0
    # Linhas a remover: espalhadas por igual entre o topo do desenho e o corte.
    span = max(1, cut - first)
    drop = {first + int(span * (k + 1) / (px + 1)) for k in range(px)}
    upper = [img[y] for y in range(cut) if y not in drop]
    empty = [(0, 0, 0, 0)] * w
    return [list(empty) for _ in range(cut - len(upper))] + [list(r) for r in upper] + [list(img[y]) for y in range(cut, h)]


def strip(frames: list) -> list:
    return [sum((f[y] for f in frames), []) for y in range(len(frames[0]))]


def update_index(written: list) -> None:
    path = ROOT / "assets" / "asset_index.json"
    index = json.loads(path.read_text(encoding="utf-8"))
    names = {f.relative_to(ROOT).as_posix() for f in written}
    index = [row for row in index if row["file"] not in names]
    for file in written:
        index.append({
            "file": file.relative_to(ROOT).as_posix(),
            "source": "tools/make_midboss_idle.py",
            "license_id": LICENSE_ID,
            "sha256": hashlib.sha256(file.read_bytes()).hexdigest(),
        })
    index.sort(key=lambda item: item["file"])
    path.write_text(json.dumps(index, indent=1, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    written = []
    for stage in STAGES:
        folder = ROOT / "assets" / "art" / "midbosses" / stage
        src = folder / "Sprite.png"
        if not src.exists():
            print(f"FALTA {src.relative_to(ROOT).as_posix()} (rode tools/sync_assets.py antes)")
            return 1
        img = read_png(src)
        out = folder / "Idle.png"
        write_png(out, strip([squash(img, s) for s in SQUASH]))
        written.append(out)
        print(f"{out.relative_to(ROOT).as_posix()}  {len(SQUASH)} quadros de {len(img[0])}x{len(img)}")
    update_index(written)
    return 0


if __name__ == "__main__":
    sys.exit(main())
