"""Importa e reempacota os efeitos visuais de terceiros usados pelos Altares do Selo e pelos Elites.

Cada folha vira uma tira HORIZONTAL de quadros QUADRADOS (largura do quadro = altura da imagem),
para o código tirar a largura do quadro da altura. Quadros mais largos que altos (ou o
contrário) são centralizados num quadrado transparente; nenhum pixel é redesenhado, só
reposicionado (modificação permitida pelas duas licenças).

- assets/art/fx/rock/rock_burst.png <- Ninja Adventure FX/Elemental/Rock/SpriteSheet.png
  (CC0, `ninja_adventure`): pedras subindo e estourando em poeira, 14 quadros 30x30;
- assets/art/fx/slash_double/cut_double.png <- Ninja Adventure FX/Attack/CutDouble/SpriteSheet.png
  (CC0, `ninja_adventure`): dois cortes retos cruzando, 5 quadros 32x32 (o SpriteSheet.png
  que já existe nessa pasta é o SlashDoubleCurved, um golpe curvo diferente);
- assets/art/fx/explosion_big/explosion_big.png <- FreeMix fx/explosion.png (`pixelboy_freemix`):
  explosão grande em 16 quadros 118x118;
- assets/art/fx/impact/impact_0.png, impact_1.png, impact_2.png <- FreeMix fx/impact_01..03.png
  (`pixelboy_freemix`): estrelas de impacto brancas, 1 quadro cada, centralizadas em
  115x115, 76x76 e 105x105.

Os pacotes ficam onde os manifestos dizem (`pack_root` de tools/asset_manifest.json e de
tools/pixelboy_freemix_assets.json). Só biblioteca padrão (PNG RGBA 8 bits lido e escrito com
zlib); determinístico. Atualiza só as linhas destes arquivos em assets/asset_index.json (com
`source` = este script, para o tools/sync_assets.py preservá-las).
Uso: python -I tools/import_altar_fx.py
"""
import hashlib
import json
import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"


def pack_root(manifest: str) -> pathlib.Path:
    data = json.loads((ROOT / "tools" / manifest).read_text(encoding="utf-8"))
    return pathlib.Path(data["pack_root"])


NINJA = ("asset_manifest.json", "ninja_adventure")
FREEMIX = ("pixelboy_freemix_assets.json", "pixelboy_freemix")

# (pacote, origem relativa ao pack_root, largura do quadro na origem ou None = imagem inteira, destino)
JOBS = [
    (NINJA, "FX/Elemental/Rock/SpriteSheet.png", 30, "art/fx/rock/rock_burst.png"),
    (NINJA, "FX/Attack/CutDouble/SpriteSheet.png", 32, "art/fx/slash_double/cut_double.png"),
    (FREEMIX, "fx/explosion.png", 118, "art/fx/explosion_big/explosion_big.png"),
    (FREEMIX, "fx/impact_01.png", None, "art/fx/impact/impact_0.png"),
    (FREEMIX, "fx/impact_02.png", None, "art/fx/impact/impact_1.png"),
    (FREEMIX, "fx/impact_03.png", None, "art/fx/impact/impact_2.png"),
]

EMPTY = (0, 0, 0, 0)


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
            raw.extend(px if px[3] else EMPTY)

    def chunk(tag: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def square_strip(img: list, frame_w) -> tuple:
    """Corta em quadros de `frame_w` (None = 1 quadro) e centraliza cada um num quadrado."""
    h, w = len(img), len(img[0])
    fw = frame_w or w
    assert w % fw == 0, f"largura {w} não é múltiplo de {fw}"
    count = w // fw
    side = max(fw, h)
    ox, oy = (side - fw) // 2, (side - h) // 2
    out = [[EMPTY] * (side * count) for _ in range(side)]
    for k in range(count):
        for y in range(h):
            for x in range(fw):
                out[oy + y][k * side + ox + x] = img[y][k * fw + x]
    return out, count, side


def update_index(rows: list) -> None:
    path = ASSETS / "asset_index.json"
    index = json.loads(path.read_text(encoding="utf-8"))
    names = {r["file"] for r in rows}
    index = [row for row in index if row["file"] not in names] + rows
    index.sort(key=lambda item: item["file"])
    path.write_text(json.dumps(index, indent=1, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    rows = []
    for (manifest, license_id), src_rel, frame_w, dst_rel in JOBS:
        src = pack_root(manifest) / src_rel
        if not src.is_file():
            print(f"FALTA {src}")
            return 1
        out, count, side = square_strip(read_png(src), frame_w)
        dst = ASSETS / dst_rel
        write_png(dst, out)
        rows.append({
            "file": dst.relative_to(ROOT).as_posix(),
            "source": "tools/import_altar_fx.py",
            "license_id": license_id,
            "sha256": hashlib.sha256(dst.read_bytes()).hexdigest(),
        })
        print(f"{dst.relative_to(ROOT).as_posix()}  {count} quadro(s) {side}x{side}  <- {src_rel}")
    update_index(rows)
    return 0


if __name__ == "__main__":
    sys.exit(main())
