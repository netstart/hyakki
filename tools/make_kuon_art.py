#!/usr/bin/env python3
"""Arte da Kuon (8a guardia, 久遠): folha de sprites 64x112 (dir4, 4 quadros x 7 linhas de 16x16)
e retrato 38x38 em assets/art/actors/heroes/kuon/.

Derivada do Ninja Adventure Asset Pack (pixel-boy & AAA, CC0; entrada `ninja_adventure` em
licenses/registry.json):
  Actor/Character/SorcererBlack/SpriteSheet.png  corpo: todo quadro recolorido (cabelo prateado,
                                                 menpo de osso, manto indigo, lenco violeta,
                                                 fogo de alma nas maos, olhos violeta);
  Actor/Character/SorcererBlack/Faceset.png      retrato: recolorido, com franja, mecha longa,
                                                 menpo gravado e uma hitodama desenhados aqui.
Sem aleatoriedade, so Pillow: rodar de novo produz os mesmos bytes. Tambem troca as linhas
desses dois arquivos em assets/asset_index.json (origem e SHA-256).

Uso (precisa do Pillow, que fica no site-packages do usuario; os PNGs do pack sao dados):
  python -E -P tools/make_kuon_art.py [--pack "<Ninja Adventure - Asset Pack>"] [--out <pasta>]
Com --out grava so os PNGs na pasta pedida (sem tocar no indice).
"""
import argparse
import hashlib
import json
import os
import sys
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LICENSE_ID = "ninja_adventure"
OUT_REL = "assets/art/actors/heroes/kuon"
PACK = "C:/src/assets/ninja-adventure/pack/Ninja Adventure - Asset Pack"
SRC_SHEET = "Actor/Character/SorcererBlack/SpriteSheet.png"
SRC_FACE = "Actor/Character/SorcererBlack/Faceset.png"


def hx(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


CLEAR = (0, 0, 0, 0)
OUT = hx("141b1b")

# ---------------------------------------------------------------- Kuon palette
K = {
    "out": OUT,
    "hairH": hx("f4f6fb"),   # sheen
    "hairL": hx("dfe2ea"),   # silver
    "hairS": hx("8e93ab"),   # steel shadow (neutral, not Yuki's lavender)
    "hairD": hx("4d5166"),
    "skinL": hx("f6d2b6"),
    "skinS": hx("d49c8c"),
    "maskL": hx("ece4cc"),   # bone menpo
    "maskS": hx("aea489"),
    "maskK": hx("6f6656"),   # engraving
    "robe": hx("33316e"),    # midnight indigo
    "robeD": hx("22204a"),
    "robeL": hx("4c4996"),
    "gold": hx("c99a3a"),
    "goldL": hx("f2d27a"),
    "vio": hx("9b5cf0"),     # scarf / soul
    "vioD": hx("5d2e9e"),
    "vioL": hx("d9b8ff"),
    "eye": hx("c58bff"),
    "eyeW": hx("f6ecff"),
    "glow": hx("e3b8e6"),    # skin lit by the eyes
}

# SorcererBlack sprite indices (by colour)
S_OUT, S_ROBE, S_HAIRS, S_COLLAR, S_HAIRL, S_SKINS, S_BAND, S_SKINL, S_BANDL = (
    hx("141b1b"), hx("4e484a"), hx("8f3e56"), hx("5f7160"), hx("e0394c"),
    hx("cf736d"), hx("9ba7aa"), hx("f2ad7d"), hx("e3f1f5"))
HAIRISH = {S_HAIRS, S_HAIRL, S_BAND, S_BANDL}
SKIN = {S_SKINL, S_SKINS}


def flood(px, w, h, seeds, allowed):
    seen = set()
    q = deque(s for s in seeds if px[s] in allowed)
    seen.update(q)
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if 0 <= n[0] < w and 0 <= n[1] < h and n not in seen and px[n] in allowed:
                seen.add(n)
                q.append(n)
    return seen


def recolor_frame(fr, col, row):
    """Recolor one 16x16 SorcererBlack frame into Kuon."""
    w, h = fr.size
    src = fr.load()
    px = {(x, y): src[x, y] for x in range(w) for y in range(h)}
    out = fr.copy()
    o = out.load()
    # hair = everything hair-coloured connected to the top of the head
    top = min((y for (x, y), c in px.items() if c in HAIRISH), default=0)
    seeds = [(x, y) for (x, y), c in px.items() if c in HAIRISH and y <= top + 2]
    hair = flood(px, w, h, seeds, HAIRISH)
    # eyes = red pixels (not hair) touching skin horizontally
    eyes = set()
    for (x, y), c in px.items():
        if c == S_HAIRL and (x, y) not in hair:
            if px.get((x - 1, y)) in SKIN or px.get((x + 1, y)) in SKIN:
                eyes.add((x, y))
    eye_row = max((y for _, y in eyes), default=None)
    face_seed = [(x + dx, y + dy) for (x, y) in eyes for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
    face = flood(px, w, h, face_seed, SKIN)
    collar_top = set()
    for x in range(w):
        for y in range(h):
            if px[(x, y)] == S_COLLAR:
                if px.get((x, y - 1)) != S_COLLAR:
                    collar_top.add((x, y))
    for (x, y), c in px.items():
        if c[3] == 0:
            continue
        if (x, y) in eyes:
            n = K["eye"]
        elif (x, y) in hair:
            n = {S_HAIRL: K["hairL"], S_HAIRS: K["hairS"], S_BAND: K["vio"], S_BANDL: K["vioL"]}[c]
        elif c in SKIN and (x, y) not in face and eye_row is not None:
            n = K["vioL"] if c == S_SKINL else K["vio"]        # hands hold soul fire
        elif c in SKIN:
            if eye_row is not None and y > eye_row and y <= eye_row + 3:
                n = K["maskL"] if c == S_SKINL else K["maskS"]
            elif eye_row is not None and y > eye_row + 3:
                n = K["vio"] if c == S_SKINS else K["vioL"]   # neck -> scarf / hand -> soul fire
            else:
                n = K["skinL"] if c == S_SKINL else K["skinS"]
        elif c == S_ROBE:
            n = K["robe"]
        elif c == S_COLLAR:
            n = K["gold"] if (x, y) in collar_top else K["robeL"]
        elif c in (S_HAIRL, S_BANDL, S_BAND, S_HAIRS):   # chest jewel etc.
            n = {S_HAIRL: K["vio"], S_BANDL: K["goldL"], S_BAND: K["gold"], S_HAIRS: K["vioD"]}[c]
        else:
            n = c
        o[x, y] = n
    # ribbon knot: the little tail behind the head on side views turns violet
    if col in (2, 3):
        for (x, y) in hair:
            back = x >= 12 if col == 2 else x <= 3
            if back and y <= top + 3 and px[(x, y)] in (S_HAIRS, S_HAIRL):
                o[x, y] = K["vio"] if px[(x, y)] == S_HAIRS else K["vioL"]
    # hair sheen: light hair pixel with outline/empty directly above
    for (x, y) in hair:
        if px[(x, y)] == S_HAIRL and px.get((x, y - 1), CLEAR) in (S_OUT, CLEAR) and y <= top + 4:
            o[x, y] = K["hairH"]
    # menpo engraving: the old mouth pixels (skin shadow 2 rows under eyes, centre) -> teeth line
    if eye_row is not None:
        for (x, y), c in px.items():
            ex = [e[0] for e in eyes]
            if c == S_SKINS and y == eye_row + 2 and (x, y) in face and min(ex) < x < max(ex):
                o[x, y] = K["maskK"]
        # eye glow: the skin pixel right under each eye goes violet-lit
        for (x, y) in eyes:
            if px.get((x, y + 1)) == S_OUT:
                pass
    return out


def kuon_sheet(pack: str):
    src = Image.open(os.path.join(pack, SRC_SHEET)).convert("RGBA")
    out = Image.new("RGBA", src.size, CLEAR)
    for row in range(src.height // 16):
        for col in range(4):
            fr = src.crop((col * 16, row * 16, col * 16 + 16, row * 16 + 16))
            out.paste(recolor_frame(fr, col, row), (col * 16, row * 16))
    return out


# ---------------------------------------------------------------- Kuon faceset
F_ROBED, F_ROBE, F_HAIRS, F_COLLAR, F_HAIRL, F_SKINS, F_ORN, F_SKINL, F_ORNL = (
    hx("3b3643"), hx("4e484a"), hx("8f3e56"), hx("5f7160"), hx("e0394c"),
    hx("cf736d"), hx("9ba7aa"), hx("f2ad7d"), hx("e3f1f5"))

FACE_KEY = {
    "0": "out", "h": "hairS", "H": "hairL", "W": "hairH", "s": "skinS", "S": "skinL",
    "d": "vioD", "E": "eye", "w": "eyeW", "v": "vio", "L": "vioL", "g": "glow",
    "M": "maskL", "m": "maskS", "k": "maskK", "G": "gold", "Y": "goldL", "r": "robe", "R": "robeD",
    "i": "robeL",
}

# window x=8..22, rows 18..32: eyes, nose bridge of the menpo, engraved jaw
FACE_X, FACE_Y = 8, 18
FACE_MAP = [
    "s0SSSSSSSSSSS0s",
    "sS0000SSS0000Ss",
    "sS0wEdSSSdEw0Ss",
    "sSSEEdSSSdEESSs",
    "sSSvEvkMkvEvSSs",
    "0kkkkkMMMkkkkk0",
    "mMWWMMMMMMMMMmm",
    "mMWvMMMMMMMvmmm",
    "mMvMMMkkkMMMvmm",
    "mMMMMMmMmMMmmmm",
    "0mMMMMMMMMMMmm0",
    "000mMMMMMMMm000",
    "00000mmmmm00000",
    "..0000000000vv.",
]

BANGS_MAP = [
    "HHH.....HHH",
    "hHH.....HHh",
    ".hH.....Hh.",
    "..h.....h..",
]
SHEEN = [(5, 14), (5, 15), (4, 16), (4, 17), (4, 18), (4, 19), (5, 20), (5, 21),
         (26, 12), (26, 13), (27, 14), (27, 15), (27, 16), (26, 17),
         (12, 9), (13, 9), (14, 9), (17, 9), (18, 9), (19, 9)]

# long silver lock falling over the left shoulder
LOCK_X, LOCK_Y = 1, 27
LOCK_MAP = [
    "..0HHh0",
    "..0HHh0",
    "..0WHh0",
    "..0HHh0",
    ".0HHh0.",
    ".0HHh0.",
    ".0WHh0.",
    ".0HHh0.",
    "0HHh0..",
    "0HHh0..",
    "0Hh0...",
]

# hitodama (soul flame) in the top-left corner
WISP_X, WISP_Y = 1, 1
WISP_MAP = [
    "....d..",
    "...dv..",
    "..dvv..",
    ".dvLvd.",
    "dvLwLvd",
    "dvLwLvd",
    ".dvLvd.",
    "..ddd..",
]


def stamp(img, x0, y0, rows, key=FACE_KEY):
    p = img.load()
    for dy, line in enumerate(rows):
        for dx, ch in enumerate(line):
            if ch != ".":
                p[x0 + dx, y0 + dy] = K[key[ch]]


def kuon_face(pack: str):
    src = Image.open(os.path.join(pack, SRC_FACE)).convert("RGBA")
    w, h = src.size
    sp = src.load()
    out = src.copy()
    o = out.load()
    for y in range(h):
        for x in range(w):
            c = sp[x, y]
            if c == F_ROBED:
                n = K["robeD"]
            elif c == F_ROBE:
                n = K["robe"]
            elif c == F_HAIRS:
                n = K["hairS"] if y < 31 else K["vioD"]
            elif c == F_HAIRL:
                n = K["hairL"] if y < 31 else K["vio"]
            elif c == F_SKINS:
                n = K["skinS"] if y < 31 else K["vio"]
            elif c == F_SKINL:
                n = K["skinL"] if y < 31 else K["vioL"]
            elif c == F_COLLAR:
                n = K["robeL"]
            elif c == F_ORN:
                n = K["vio"] if y < 12 else K["gold"]
            elif c == F_ORNL:
                n = K["vioL"] if y < 12 else K["goldL"]
            else:
                n = c
            o[x, y] = n
    # sheen on the silver hair: light pixels with dark above
    for y in range(1, h):
        for x in range(w):
            if sp[x, y] == F_HAIRL and y < 31 and sp[x, y - 1] in (OUT, F_ROBED):
                o[x, y] = K["hairH"]
    # forehead: only the row right under the bangs stays in shadow
    for y in range(15, 18):
        for x in range(8, 23):
            if sp[x, y] == F_SKINS and sp[x, y - 1] != OUT:
                o[x, y] = K["skinL"]
    # bangs: two pointed locks over the forehead, parted in the middle
    stamp(out, 9, 13, BANGS_MAP)
    # anime sheen streaks along the long hair
    for (x, y) in SHEEN:
        if sp[x, y] in (F_HAIRL, F_HAIRS):
            o[x, y] = K["hairH"] if sp[x, y] == F_HAIRL else K["hairL"]
    stamp(out, FACE_X, FACE_Y, FACE_MAP)
    stamp(out, LOCK_X, LOCK_Y, LOCK_MAP)
    stamp(out, WISP_X, WISP_Y, WISP_MAP)
    return out


def update_index(paths: list) -> None:
    """Troca no assets/asset_index.json as linhas destes arquivos (origem e SHA-256)."""
    index_path = os.path.join(ROOT, "assets", "asset_index.json")
    with open(index_path, encoding="utf-8") as f:
        index = json.load(f)
    rows = []
    for p in paths:
        with open(p, "rb") as f:
            digest = hashlib.sha256(f.read()).hexdigest()
        rows.append({"file": os.path.relpath(p, ROOT).replace(os.sep, "/"),
                     "source": "tools/make_kuon_art.py", "license_id": LICENSE_ID, "sha256": digest})
    names = {r["file"] for r in rows}
    index = sorted([row for row in index if row["file"] not in names] + rows, key=lambda row: row["file"])
    with open(index_path, "w", encoding="utf-8") as f:
        f.write(json.dumps(index, indent=1, ensure_ascii=False))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack", default=PACK, help="pasta 'Ninja Adventure - Asset Pack'")
    ap.add_argument("--out", default=None, help="grava so os PNGs nesta pasta (sem indice)")
    a = ap.parse_args()
    out = a.out or os.path.join(ROOT, OUT_REL)
    os.makedirs(out, exist_ok=True)
    paths = []
    for name, img in (("SpriteSheet.png", kuon_sheet(a.pack)), ("Faceset.png", kuon_face(a.pack))):
        p = os.path.join(out, name)
        img.save(p)
        paths.append(p)
        print(f"{p}  {img.width}x{img.height}")
    if not a.out:
        update_index(paths)
    return 0


if __name__ == "__main__":
    sys.exit(main())
