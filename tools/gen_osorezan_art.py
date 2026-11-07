"""Gera o tileset de decoração de Osorezan (恐山) em assets/art/tilesets/osorezan.png e a
descrição dos sprites em osorezan_sprites.json (mesmo formato de data/biomes.json "sprites":
nome -> ["osorezan", x, y, w, h] em tiles de 16 px).

Obra original do projeto Hyakki, liberada em CC0-1.0 (entrada `hyakki_osorezan_art` em
licenses/registry.json). Só biblioteca padrão (PNG escrito à mão com zlib), sem
aleatoriedade fora de sementes fixas: rodar de novo produz os mesmos bytes. Cores da paleta do
Ninja Adventure (Palette.png, CC0) com contorno escuro de 1 px (#141b1b) e luz do alto à
esquerda, como os tilesets do pacote; alfa binário (0 ou 255), seguro para filtro "nearest".

Peças (de pé, com âncora embaixo, salvo as "flat", que deitam no chão):
- kazaguruma_a/_b (+ _spin: 2º quadro girado 45°), kazaguruma_pile (+ _spin): cata-ventos;
- cairn_s/_m/_l: pilhas de pedras (tsumi-ishi) de 3 tamanhos;
- sotoba_a/_b: tábuas sotoba (uma e um feixe inclinado);
- jizo_a/_b: Jizō de pedra com babador vermelho (com e sem gorro);
- lantern_old: lanterna de pedra (tōrō) gasta, com musgo e lasca;
- dead_pine / dead_tree_bare: pinheiro morto e árvore seca (32x32);
- volcanic_a/_b/_c: rochas vulcânicas cinza com poros;
- sanzu_torii: torii de madeira cinza da travessia do Sanzu (32x32);
- flat: sulfur_vent, sulfur_crust, sulfur_patch (32x16), sai_pebbles_a/_b, sai_pebbles_c (32x16),
  water_ripple (anéis na água, transparente);
- chão (16x16, opacos e emendáveis, para "materials"): ground_ash_a/_b, ground_sulfur,
  ground_pebbles, ground_water.

Também atualiza (só com --update-index) as linhas desta licença em assets/asset_index.json.
A descrição dos sprites (as linhas de data/biomes.json "sprites") só é escrita com --sprites
<arquivo>, fora de assets/. Depois rode o import do Godot.
Uso: python -I tools/gen_osorezan_art.py [--root <repo>] [--out <pasta>] [--sprites <json>] [--update-index]
"""
import argparse
import hashlib
import json
import math
import pathlib
import random
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
LICENSE_ID = "hyakki_osorezan_art"
TILESET = "osorezan"
T = 16  # tile


def hx(s: str) -> tuple:
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


# Paleta do Ninja Adventure (Palette.png).
OUTLINE = hx("141b1b")
# Pedra fria (a mesma rampa das rochas cinza de nature.png).
ST = [hx("345a52"), hx("5f7160"), hx("8d977f"), hx("abc2bc"), hx("f2eaf1")]
# Cinza vulcânico quente (cinza de enxofre): do escuro ao claro.
VG = [hx("3b3643"), hx("4e484a"), hx("67615f"), hx("88827c"), hx("aaa298"), hx("cdc5b6")]  # cinza neutro (meios-tons fora da paleta)
ASH = [hx("9a938a"), hx("b2aa9e"), hx("bfb7aa"), hx("d4ccbe")]  # chão de cinza (2 tons fora da paleta)
SULF = [hx("a8a129"), hx("f1c471"), hx("ffe18d"), hx("fce2ca")]
RED = [hx("8f3e56"), hx("e0394c"), hx("ef9597")]
RED2 = [hx("965340"), hx("d14b34"), hx("e46d3a")]
YEL = [hx("a8a129"), hx("f1c471"), hx("ffe18d")]
BLU = [hx("2d697b"), hx("548789"), hx("79b8ce")]
WHITE = [hx("b8dce5"), hx("f2eaf1"), hx("ffffff")]
WOOD = [hx("4e484a"), hx("816855"), hx("90775e"), hx("b3957f"), hx("d2b37d")]  # madeira gasta
PALE = [hx("695953"), hx("8e8a80"), hx("b4ae9e"), hx("d6d0c0"), hx("eee8da")]  # tábua sotoba desbotada (cinza)
BARK = [hx("3b3643"), hx("4e484a"), hx("695953"), hx("816855")]
MOSS = [hx("345a52"), hx("56864c"), hx("74a334")]
WATER = [hx("1e2a3a"), hx("2b3550"), hx("4a5270"), hx("2d697b"), hx("548789"), hx("79b8ce")]
INK = hx("3b3643")
VIOLET = [hx("543c52"), hx("a5608b"), hx("d3a2c0")]


# --- Tela de pixels --------------------------------------------------------------------

def blank(w: int, h: int) -> list:
    return [[None] * w for _ in range(h)]


def put(img, x, y, c) -> None:
    if 0 <= y < len(img) and 0 <= x < len(img[0]) and c is not None:
        img[y][x] = c


def clear(img, x, y) -> None:
    if 0 <= y < len(img) and 0 <= x < len(img[0]):
        img[y][x] = None


def get(img, x, y):
    if 0 <= y < len(img) and 0 <= x < len(img[0]):
        return img[y][x]
    return None


def rect(img, x0, y0, x1, y1, c) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(img, x, y, c)


def line(img, x0, y0, x1, y1, c) -> None:
    steps = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(steps + 1):
        t = 0.0 if steps == 0 else i / steps
        put(img, int(round(x0 + (x1 - x0) * t)), int(round(y0 + (y1 - y0) * t)), c)


def outlined(img, color=OUTLINE) -> list:
    """Contorno de 1 px (vizinhança de 4) em volta do que é opaco."""
    h, w = len(img), len(img[0])
    out = [list(r) for r in img]
    for y in range(h):
        for x in range(w):
            if img[y][x] is not None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if get(img, x + dx, y + dy) is not None:
                    out[y][x] = color
                    break
    return out


def over(dst, src, ox=0, oy=0) -> None:
    for y, row in enumerate(src):
        for x, c in enumerate(row):
            if c is not None:
                put(dst, x + ox, y + oy, c)


def stamp(img, rows, x0, y0, pal) -> None:
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch in pal:
                put(img, x0 + dx, y0 + dy, pal[ch])


def blob(img, cx, cy, rx, ry, ramp, light=(-0.55, -0.85), rim=True, dither=True) -> None:
    """Elipse cheia com sombreamento em faixas pela rampa (luz do alto à esquerda); a borda
    de baixo e da direita escurece; pontilhado só na transição entre faixas."""
    lx, ly = light
    norm = math.hypot(lx, ly)
    lx, ly = lx / norm, ly / norm
    n = len(ramp)
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            nx = (x + 0.5 - cx) / rx
            ny = (y + 0.5 - cy) / ry
            d = nx * nx + ny * ny
            if d > 1.0:
                continue
            nz = math.sqrt(max(0.0, 1.0 - d))
            v = 0.5 + 0.5 * (-(nx * lx + ny * ly) * 0.8 + nz * 0.45)
            if rim and d > 0.72 and (nx * 0.4 + ny) > 0.2:
                v -= 0.25
            v = min(max(v, 0.0), 0.999) * n
            idx = int(v)
            if dither and v - idx > 0.85 and (x + y) % 2 == 0:
                idx += 1
            put(img, x, y, ramp[min(max(idx, 0), n - 1)])


def cell(wt: int, ht: int) -> list:
    return blank(wt * T, ht * T)


# --- Peças -------------------------------------------------------------------------------

def pinwheel(img, cx: float, cy: float, r: float, colors: list, angle: float) -> None:
    """Cata-vento de 4 pás: cada pá é um triângulo enrolado (o raio cresce com o ângulo
    dentro do setor), alternando duas cores, cada uma com tom claro (frente) e escuro."""
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > r:
                continue
            a = (math.degrees(math.atan2(dy, dx)) - angle) % 360.0
            blade = int(a // 90.0)
            rel = (a % 90.0) / 90.0
            reach = r * (0.25 + 0.75 * rel)
            if d > reach or rel > 0.97:
                continue
            ramp = colors[blade % 2]
            tone = 2 if rel > 0.55 else 1
            if d > reach - 1.0 and rel < 0.55:
                tone = 0
            put(img, x, y, ramp[tone])
    put(img, int(cx), int(cy), YEL[2])


def stick(img, x, y0, y1) -> None:
    for y in range(y0, y1 + 1):
        put(img, x, y, WOOD[2] if y % 5 else WOOD[1])


def pebble_base(img, cx, by) -> None:
    blob(img, cx - 2, by - 1.5, 2.4, 1.6, ST[1:], dither=False)
    blob(img, cx + 2, by - 1.2, 2.0, 1.4, ST[1:], dither=False)
    blob(img, cx, by - 3.0, 1.8, 1.3, ST[1:], dither=False)


def kazaguruma(colors, angle) -> list:
    img = cell(1, 2)
    stick(img, 7, 9, 28)
    pebble_base(img, 7.5, 31)
    pinwheel(img, 7.5, 8.5, 6.0, colors, angle)
    return outlined(img)


def kazaguruma_pile(angle) -> list:
    """Pilha de pedras com três cata-ventos pequenos (32x32)."""
    img = cell(2, 2)
    for i, (sx, top, cols) in enumerate(((9, 9, [RED, WHITE]), (16, 5, [YEL, RED]), (23, 11, [BLU, WHITE]))):
        stick(img, sx, top + 3, 26)
    blob(img, 16, 28, 11, 3.6, VG[1:], dither=True)
    blob(img, 11, 25.5, 5, 2.4, VG[2:])
    blob(img, 20, 25, 5.5, 2.5, VG[2:])
    blob(img, 15.5, 22.5, 4, 2.0, VG[2:])
    blob(img, 16, 20.5, 2.6, 1.4, VG[3:])
    for sx, top, cols in ((9, 9, [RED, WHITE]), (16, 5, [YEL, RED]), (23, 11, [BLU, WHITE])):
        pinwheel(img, sx + 0.5, top + 0.5, 4.2, cols, angle + sx * 7)
    return outlined(img)


def cairn(stones: list, wt: int, ht: int) -> list:
    """Pilha de pedras achatadas (rx, ry, dx) de baixo para cima."""
    img = cell(wt, ht)
    w, h = wt * T, ht * T
    cx = w / 2.0
    y = h - 1.5
    rng = random.Random(len(stones) * 31 + wt)
    for k, (rx, ry, dx) in enumerate(stones):
        y -= ry
        ramp = ST[0:4] if (k + len(stones)) % 3 else VG[1:5]
        blob(img, cx + dx, y, rx, ry, ramp)
        y -= ry * 0.55
    img = outlined(img)
    # Pontinho de musgo/líquen no alto de algumas pedras.
    for yy in range(h):
        for xx in range(w):
            if img[yy][xx] in (ST[3], VG[5]) and rng.random() < 0.06:
                img[yy][xx] = ST[4]
    return img


def sotoba_plank(img, x0, y0, height, w=5, tilt=0) -> None:
    """Tábua sotoba: topo em gorin (ponta + entalhes dos 5 elementos), madeira gasta e
    linhas de escrita a nanquim já desbotadas."""
    for j in range(height):
        x = x0 + (tilt * j) // height
        y = y0 + j
        for i in range(w):
            c = PALE[3] if i == 0 else (PALE[1] if i == w - 1 else PALE[2])
            put(img, x + i, y, c)
    # Ponta (gorin: cinco degraus dos elementos) e entalhes laterais.
    for i in range(w):
        if i != w // 2:
            clear(img, x0 + i, y0)
    for i in (0, w - 1):
        clear(img, x0 + i, y0 + 1)
    for ny in (y0 + 4, y0 + 6, y0 + 8):
        clear(img, x0, ny)
        clear(img, x0 + w - 1, ny)
    # Escrita: colunas de "kanji" a nanquim (traço, ponto, traço duplo) já desbotados.
    rng = random.Random(x0 * 13 + y0)
    j = 10
    while j < height - 4:
        x = x0 + (tilt * j) // height + 1
        glyph = rng.choice(([(1, 0), (2, 0), (1, 1), (2, 2)], [(1, 0), (1, 1), (2, 1), (1, 2)],
                            [(1, 0), (2, 0), (1, 2), (2, 2)], [(2, 0), (1, 1), (2, 1), (2, 2)]))
        for gx, gy in glyph:
            if gx < w - 1:
                put(img, x + gx - (1 if w <= 4 else 0), y0 + j + gy, INK if rng.random() < 0.8 else PALE[0])
        j += 4
    # Base enterrada mais escura.
    for j in range(height - 2, height):
        x = x0 + (tilt * j) // height
        for i in range(w):
            put(img, x + i, y0 + j, PALE[1] if i else PALE[2])


def sotoba_a() -> list:
    img = cell(1, 2)
    sotoba_plank(img, 5, 3, 28, 6)
    return outlined(img)


def sotoba_b() -> list:
    img = cell(1, 2)
    sotoba_plank(img, 1, 7, 23, 4, 2)
    sotoba_plank(img, 10, 9, 21, 4, -1)
    sotoba_plank(img, 5, 4, 27, 5)
    return outlined(img)


JIZO = [
    "....hhhhh....",
    "...hHHHHhh...",
    "..hHHHHhhhh..",
    "..hhhhhhhhh..",
    "...sSSSSss...",
    "...SSSSSss...",
    "...SoSSoss...",
    "...SSSSSss...",
    "....sssss....",
    "..rRRRRRRrr..",
    "..rRRRRRRrr..",
    "...rRRRRrr...",
    "..SSrrrrrsS..",
    "..SSSsSsssS..",
    ".SSSSsSssssS.",
    ".SSSSSssssss.",
    ".SSSSSssssss.",
    ".ssSSSssssss.",
    "..ssssssssd..",
    "pPPPPPPPPPPpp",
    "pppppppppppdd",
]


def jizo(hat: bool, tall: bool) -> list:
    img = cell(1, 2 if tall else 1)
    pal = {"S": ST[3], "s": ST[2], "d": ST[1], "o": ST[1], "R": RED[1], "r": RED[0],
           "H": RED[2], "h": RED[1], "P": ST[2], "p": ST[1]}
    rows = JIZO if hat else ["............."] * 4 + JIZO[4:]
    if not tall:
        rows = rows[4:9] + rows[9:12] + rows[14:]  # Jizō pequeno: sem gorro e mais baixo
    h = len(rows)
    y0 = (len(img) - 1) - h
    stamp(img, rows, 1, y0, pal)
    if not hat and tall:
        # Cabeça raspada arredondada no lugar do gorro.
        blob(img, 7.0, y0 + 5.5, 3.6, 3.0, ST[1:4], dither=False)
        stamp(img, ["SoSSoss"], 4, y0 + 6, pal)
    img = outlined(img)
    return img


def lantern_old() -> list:
    """Tōrō de pedra gasto: base, haste, caixa de fogo vazia, telhado lascado e musgo."""
    img = cell(1, 2)
    rows = [
        "......SS......",
        ".....sSSs.....",
        "...SSSSSSSs...",
        ".SSSSSSSSSSss.",
        "sssssssssssssd",
        "..dSSSSSSSsd..",
        "..dS.oooo.sd..",
        "..dS.oVVo.sd..",
        "..dS.oooo.sd..",
        "..dSSSSSSSsd..",
        ".ssssssssssss.",
        "....SSSSsd....",
        "....SSSsSd....",
        "....SSSssd....",
        "....SSSssd....",
        "....SSsssd....",
        "....SSsssd....",
        "...sssssssd...",
        "..SSSSSSSssd..",
        ".ssssssssssdd.",
        ".dddddddddddd.",
    ]
    pal = {"S": ST[3], "s": ST[2], "d": ST[1], "o": VG[0], "V": VIOLET[0]}
    y0 = len(img) - 1 - len(rows)
    stamp(img, rows, 1, y0, pal)
    # Lasca no canto do telhado e musgo.
    put(img, 13, y0 + 4, None)
    put(img, 14, y0 + 4, None)
    for x, y in ((2, 3), (3, 3), (4, 2), (2, 4), (3, 4), (10, 10), (11, 10), (5, 17), (4, 18), (3, 18), (11, 19)):
        put(img, 1 + x, y0 + y, MOSS[1] if (x + y) % 3 else MOSS[2])
    # Rachadura na haste.
    for x, y in ((7, 12), (6, 13), (7, 14), (7, 15)):
        put(img, 1 + x, y0 + y, ST[1])
    return outlined(img)


def branch(img, x0, y0, ang, length, width, ramp, rng, depth) -> None:
    """Galho recursivo (árvore morta): segmentos com espessura caindo."""
    x, y = x0, y0
    for i in range(int(length)):
        x += math.cos(ang)
        y += math.sin(ang)
        ang += rng.uniform(-0.18, 0.18)
        wv = max(1, int(round(width * (1.0 - i / (length * 1.3)))))
        for k in range(wv):
            px = int(round(x)) + k - wv // 2
            put(img, px, int(round(y)), ramp[2] if k == 0 and wv > 1 else ramp[1])
            if wv > 2 and k == wv - 1:
                put(img, px, int(round(y)), ramp[0])
    if depth > 0:
        for s in (-1, 1):
            if rng.random() < 0.85:
                branch(img, x, y, ang + s * rng.uniform(0.45, 0.8), length * rng.uniform(0.5, 0.7),
                       max(1, width - 1), ramp, rng, depth - 1)


def dead_pine() -> list:
    """Pinheiro morto retorcido (32x32) com poucos tufos escuros de agulhas."""
    img = cell(2, 2)
    rng = random.Random(77)
    # Tronco: sobe torto da base.
    x = 15.0
    for y in range(30, 6, -1):
        x += math.sin(y * 0.35) * 0.35
        wv = 4 if y > 22 else (3 if y > 13 else 2)
        for k in range(wv):
            c = BARK[3] if k == 0 else (BARK[0] if k == wv - 1 else BARK[2])
            put(img, int(round(x)) + k - wv // 2, y, c)
    # Raízes.
    for dx, dy in ((-3, 30), (-4, 31), (3, 30), (4, 31), (-2, 31), (2, 31)):
        put(img, 15 + dx, dy, BARK[1])
    # Galhos em camadas (o pinheiro tem galhos quase horizontais).
    for (y, side, ln) in ((11, -1, 9), (13, 1, 10), (17, -1, 11), (19, 1, 9), (23, -1, 7), (8, 1, 6)):
        branch(img, 15 + side, y, math.pi * (1.06 if side < 0 else -0.06), ln, 2, BARK, rng, 1)
    # Restos de agulhas: tufos pequenos verde-escuros nas pontas.
    for cx, cy in ((6, 10), (25, 12), (5, 16), (26, 18), (9, 22), (20, 6)):
        blob(img, cx, cy, 2.6, 1.4, [hx("2b3a33"), MOSS[0], MOSS[1]], dither=False)
    return outlined(img)


def dead_tree_bare() -> list:
    img = cell(2, 2)
    rng = random.Random(1234)
    for y in range(31, 18, -1):
        for k in range(4):
            put(img, 14 + k, y, BARK[3] if k == 0 else (BARK[1] if k == 3 else BARK[2]))
    put(img, 13, 31, BARK[1])
    put(img, 18, 31, BARK[1])
    branch(img, 15.5, 19, -math.pi / 2 - 0.5, 11, 3, BARK, rng, 2)
    branch(img, 16.5, 19, -math.pi / 2 + 0.45, 12, 3, BARK, rng, 2)
    branch(img, 16, 20, -math.pi / 2, 9, 2, BARK, rng, 1)
    return outlined(img)


def volcanic(wt, ht, blobs, seed) -> list:
    img = cell(wt, ht)
    rng = random.Random(seed)
    for cx, cy, rx, ry in blobs:
        blob(img, cx, cy, rx, ry, VG[1:])
    # Poros (vesículas) e cristais de enxofre nas frestas.
    h, w = len(img), len(img[0])
    for y in range(h):
        for x in range(w):
            c = img[y][x]
            if c in (VG[3], VG[4]) and rng.random() < 0.07:
                img[y][x] = VG[1]
                put(img, x + 1, y + 1, VG[4]) if get(img, x + 1, y + 1) is not None else None
            elif c == VG[2] and rng.random() < 0.025:
                img[y][x] = SULF[1]
    return outlined(img)


def sanzu_torii() -> list:
    """Torii de madeira gasta (cinza) da travessia do Sanzu, com shimenawa podre."""
    img = cell(2, 2)
    # Kasagi (viga de cima, pontas curvas) e nuki.
    rows = [
        "WW..........................WW",
        "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
        ".wwwwwwwwwwwwwwwwwwwwwwwwwwww.",
        "..dddddddddddddddddddddddddd..",
    ]
    pal = {"W": WOOD[3], "w": WOOD[2], "d": WOOD[1]}
    stamp(img, rows, 1, 2, pal)
    rect(img, 4, 9, 27, 10, WOOD[2])
    rect(img, 4, 11, 27, 11, WOOD[1])
    # Gakuzuka (placa do meio).
    rect(img, 14, 6, 17, 8, WOOD[2])
    put(img, 15, 7, INK)
    put(img, 16, 7, INK)
    # Pilares.
    for x0 in (7, 22):
        rect(img, x0, 6, x0 + 2, 29, WOOD[2])
        rect(img, x0, 6, x0, 29, WOOD[3])
        rect(img, x0 + 2, 6, x0 + 2, 29, WOOD[1])
        rect(img, x0 - 1, 28, x0 + 3, 30, ST[2])
        rect(img, x0 - 1, 30, x0 + 3, 30, ST[1])
    # Corda de palha caída entre os pilares, com dois shide de papel.
    for x in range(10, 22):
        y = 13 + int(round(2.2 * math.sin(math.pi * (x - 10) / 11)))
        put(img, x, y, YEL[0])
        put(img, x, y + 1, WOOD[1])
    for sx in (13, 18):
        stamp(img, ["P", "PP", ".P", "PP"], sx, 16, {"P": WHITE[1]})
    # Musgo na base e lasca.
    for x, y in ((7, 27), (8, 26), (22, 27), (24, 26), (8, 29)):
        put(img, x, y, MOSS[1])
    return outlined(img)


# --- Peças planas (decalques do chão) -----------------------------------------------------

def sulfur_vent() -> list:
    img = cell(1, 1)
    blob(img, 8, 9, 7, 4.5, [SULF[0], SULF[1], SULF[2], SULF[3]], rim=False)
    blob(img, 8, 9.5, 3.0, 1.8, [VG[0], VG[1]], light=(0.5, 0.8), rim=False, dither=False)
    for x, y in ((3, 8), (13, 10), (5, 12), (11, 6)):
        put(img, x, y, SULF[0])
    put(img, 7, 9, VG[0])
    put(img, 9, 8, SULF[3])
    return outlined(img, SULF[0])


def sulfur_crust() -> list:
    img = cell(1, 1)
    rng = random.Random(9)
    for cx, cy, rx, ry in ((6, 8, 5, 3.2), (10, 10, 4.5, 2.8), (8, 6, 3, 2)):
        blob(img, cx, cy, rx, ry, SULF[1:], rim=False)
    for _ in range(6):
        put(img, rng.randint(3, 12), rng.randint(5, 12), SULF[0])
    return outlined(img, SULF[0])


def sulfur_patch() -> list:
    img = cell(2, 1)
    rng = random.Random(10)
    for cx, cy, rx, ry in ((9, 8, 7, 3.6), (20, 9, 8, 3.4), (15, 6, 4, 2), (26, 7, 3, 2)):
        blob(img, cx, cy, rx, ry, SULF[1:], rim=False)
    for _ in range(14):
        put(img, rng.randint(3, 28), rng.randint(5, 11), SULF[0])
    blob(img, 21, 9, 2.0, 1.2, [VG[0], VG[1]], light=(0.5, 0.8), rim=False, dither=False)
    return outlined(img, SULF[0])


def pebbles(wt: int, count: int, seed: int) -> list:
    """Seixos do Sai-no-Kawara: pedrinhas lisas e claras, cada uma com sombra no chão."""
    img = cell(wt, 1)
    rng = random.Random(seed)
    w = wt * T
    placed = []
    for _ in range(count * 6):
        if len(placed) >= count:
            break
        rx = rng.uniform(2.0, 3.0)
        ry = rx * rng.uniform(0.6, 0.8)
        cx = rng.uniform(rx + 2, w - rx - 2)
        cy = rng.uniform(ry + 3, T - ry - 3)
        if any(math.hypot(cx - px, cy - py) < rx + prx + 1.2 for px, py, prx in placed):
            continue
        placed.append((cx, cy, rx))
    for cx, cy, rx in placed:
        ramp = ST[1:] if rng.random() < 0.6 else [VG[2], VG[3], VG[4], ASH[3]]
        sub = blank(w, T)
        blob(sub, cx, cy, rx, rx * 0.72, ramp, dither=False)
        sub = outlined(sub)
        # Sombra curta embaixo à direita.
        for y in range(T):
            for x in range(w):
                if sub[y][x] is not None and get(sub, x, y + 1) is None and get(img, x + 1, y + 1) is None:
                    put(img, x + 1, y + 1, VG[0])
        over(img, sub)
    return img


def water_ripple() -> list:
    img = cell(1, 1)
    for r, c in ((6.5, WATER[4]), (3.6, WATER[5])):
        for a in range(0, 360, 4):
            if 200 <= a <= 340 or a <= 20:
                x = 8 + math.cos(math.radians(a)) * r
                y = 8 + math.sin(math.radians(a)) * r * 0.45
                put(img, int(round(x)), int(round(y)), c)
    put(img, 8, 8, WHITE[1])
    return img


# --- Chão (tiles opacos emendáveis) ------------------------------------------------------

def ground(base: list, speck: list, seed: int, density: float) -> list:
    """Chão calmo e emendável: tom base com manchas grandes e suaves do 2º tom (ruído
    periódico em 16 px, sem pontilhado) e grãos soltos de 1-2 px."""
    rng = random.Random(seed)
    img = blank(T, T)
    for y in range(T):
        for x in range(T):
            v = (math.sin(TAU16 * x + seed) * math.cos(TAU16 * y + seed * 0.7)
                 + 0.6 * math.sin(TAU16 * (x - y) * 2 + seed * 1.3)) / 1.6
            img[y][x] = base[1] if v > 0.35 else base[0]
    for _ in range(int(density * T * T)):
        x, y = rng.randrange(T), rng.randrange(T)
        c = rng.choice(speck)
        img[y][x] = c
        if rng.random() < 0.4:
            img[y][(x + 1) % T] = c
    return img


TAU16 = 2.0 * math.pi / 16.0


def ground_pebbles() -> list:
    """Margem de seixos: pedrinhas sem contorno preto (como os chãos do pacote), só com a
    sombra de 1 px embaixo, sobre a cinza."""
    img = ground([ASH[1], ASH[2]], [ASH[0]], 5, 0.03)
    rng = random.Random(44)
    for cx, cy, rx in ((3.5, 3.5, 2.2), (10.5, 2.5, 1.6), (13.0, 9.0, 2.4), (6.0, 10.5, 1.8), (1.0, 13.5, 1.5),
                       (9.5, 14.0, 1.4), (14.5, 14.5, 1.3), (7.5, 6.0, 1.2)):
        ry = rx * 0.7
        for y in range(int(cy - ry - 1), int(cy + ry + 3)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy - 1.0) / ry
                if nx * nx + ny * ny <= 1.0:
                    img[y % T][x % T] = ASH[0]
        sub = blank(T, T)
        blob(sub, cx, cy, rx, ry, [ST[1], ST[2], ST[3], ASH[3]] if rng.random() < 0.6 else VG[2:6], dither=False)
        for y in range(T):
            for x in range(T):
                if sub[y][x] is not None:
                    img[y][x] = sub[y][x]
    return img


def ground_water() -> list:
    """Água negra do Sanzu: faixas horizontais suaves (emendáveis) e poucos brilhos."""
    img = blank(T, T)
    for y in range(T):
        for x in range(T):
            v = math.sin(TAU16 * (y * 2 + 2.0 * math.sin(TAU16 * x))) + 0.4 * math.sin(TAU16 * x * 3)
            img[y][x] = WATER[1] if v > 0.85 else WATER[0]
    for x, y in ((3, 4), (4, 4), (11, 11), (12, 11)):
        img[y][x] = WATER[2]
    return img


# --- Montagem da folha ---------------------------------------------------------------------

def layout() -> list:
    """(nome, tx, ty, imagem, extra) com tx/ty em tiles."""
    items = []

    def add(name, tx, ty, img, **extra):
        items.append((name, tx, ty, img, extra))

    # Linha 0-1: peças altas (16x32 e 32x32).
    add("kazaguruma_a", 0, 0, kazaguruma([RED, WHITE], 0.0), sway=True)
    add("kazaguruma_a_spin", 1, 0, kazaguruma([RED, WHITE], 45.0), frame_of="kazaguruma_a")
    add("kazaguruma_b", 2, 0, kazaguruma([RED2, YEL], 20.0), sway=True)
    add("kazaguruma_b_spin", 3, 0, kazaguruma([RED2, YEL], 65.0), frame_of="kazaguruma_b")
    add("kazaguruma_pile", 4, 0, kazaguruma_pile(0.0), sway=True)
    add("kazaguruma_pile_spin", 6, 0, kazaguruma_pile(45.0), frame_of="kazaguruma_pile")
    add("cairn_l", 8, 0, cairn([(6.5, 2.6, 0), (5.5, 2.3, 1), (4.8, 2.1, -1), (4.0, 1.9, 0.5), (3.2, 1.7, -0.5),
                               (2.6, 1.5, 0.5), (1.8, 1.3, 0)], 1, 2))
    add("sotoba_a", 9, 0, sotoba_a())
    add("sotoba_b", 10, 0, sotoba_b())
    add("jizo_a", 11, 0, jizo(True, True))
    add("jizo_c", 12, 0, jizo(False, True))
    add("lantern_old", 13, 0, lantern_old())
    add("dead_pine", 14, 0, dead_pine())
    add("dead_tree_bare", 16, 0, dead_tree_bare())
    add("sanzu_torii", 18, 0, sanzu_torii())
    add("volcanic_a", 20, 0, volcanic(2, 2, [(15, 22, 12, 8), (9, 18, 6, 5), (21, 16, 6, 5.5)], 3))
    # Linha 2: peças de 16x16 e planas.
    add("cairn_s", 0, 2, cairn([(5.5, 2.4, 0), (4.0, 2.0, 1), (2.6, 1.6, -0.5)], 1, 1))
    add("cairn_m", 1, 2, cairn([(6.0, 2.2, 0), (4.6, 1.9, -1), (3.6, 1.7, 0.5), (2.4, 1.4, 0)], 1, 1))
    add("jizo_b", 2, 2, jizo(False, False))
    add("volcanic_b", 3, 2, volcanic(1, 1, [(8, 10, 6.5, 4.5), (6, 8, 3.5, 3)], 4))
    add("volcanic_c", 4, 2, volcanic(1, 1, [(6, 11, 3.6, 2.6), (11, 12, 2.4, 1.8)], 5))
    add("sulfur_vent", 5, 2, sulfur_vent(), flat=True)
    add("sulfur_crust", 6, 2, sulfur_crust(), flat=True)
    add("sulfur_patch", 7, 2, sulfur_patch(), flat=True)
    add("sai_pebbles_a", 9, 2, pebbles(1, 4, 21), flat=True)
    add("sai_pebbles_b", 10, 2, pebbles(1, 3, 22), flat=True)
    add("sai_pebbles_c", 11, 2, pebbles(2, 7, 23), flat=True)
    add("water_ripple", 13, 2, water_ripple(), flat=True)
    # Linha 3: chão.
    add("ground_ash_a", 0, 3, ground([ASH[1], ASH[2]], [ASH[0], ASH[3]], 1, 0.05), ground=True)
    add("ground_ash_b", 1, 3, ground([ASH[1], ASH[0]], [VG[3], ASH[2]], 2, 0.05), ground=True)
    add("ground_sulfur", 2, 3, ground([ASH[2], hx("d8cc96")], [SULF[1], SULF[0]], 3, 0.06), ground=True)
    add("ground_pebbles", 3, 3, ground_pebbles(), ground=True)
    add("ground_water", 4, 3, ground_water(), ground=True)
    return items


SHEET_TILES = (22, 4)


def build() -> tuple:
    w, h = SHEET_TILES[0] * T, SHEET_TILES[1] * T
    sheet = blank(w, h)
    sprites = {}
    meta = {}
    for name, tx, ty, img, extra in layout():
        ih, iw = len(img), len(img[0])
        assert iw % T == 0 and ih % T == 0, name
        over(sheet, img, tx * T, ty * T)
        sprites[name] = [TILESET, tx, ty, iw // T, ih // T]
        if extra:
            meta[name] = extra
    return sheet, sprites, meta


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


def update_index(written: list, root: pathlib.Path) -> None:
    path = root / "assets" / "asset_index.json"
    index = json.loads(path.read_text(encoding="utf-8"))
    names = {f.relative_to(root).as_posix() for f in written}
    index = [row for row in index if row.get("license_id") != LICENSE_ID and row["file"] not in names]
    for file in written:
        index.append({"file": file.relative_to(root).as_posix(), "source": "tools/gen_osorezan_art.py",
                      "license_id": LICENSE_ID, "sha256": hashlib.sha256(file.read_bytes()).hexdigest()})
    index.sort(key=lambda item: item["file"])
    path.write_bytes(json.dumps(index, indent=1, ensure_ascii=False).encode("utf-8"))


def main() -> int:
    global ROOT
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=None)
    ap.add_argument("--out", default=None, help="pasta de saída (padrão: <root>/assets/art/tilesets)")
    ap.add_argument("--sprites", default=None, help="onde escrever a descrição dos sprites (json)")
    ap.add_argument("--update-index", action="store_true")
    args = ap.parse_args()
    if args.root:
        ROOT = pathlib.Path(args.root).resolve()
    out = pathlib.Path(args.out) if args.out else ROOT / "assets" / "art" / "tilesets"
    out.mkdir(parents=True, exist_ok=True)
    sheet, sprites, meta = build()
    png = out / f"{TILESET}.png"
    write_png(png, sheet)
    if args.sprites:
        pathlib.Path(args.sprites).write_text(json.dumps({"sprites": sprites, "meta": meta}, indent=1,
                                                         ensure_ascii=False) + "\n", encoding="utf-8")
    if args.update_index:
        update_index([png], ROOT)
    print(f"{png}: {len(sprites)} sprites, {len(sheet[0])}x{len(sheet)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
