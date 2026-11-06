"""Gera a arte procedural dos Altares do Selo (封印の祭壇) e dos Elites em assets/art/altar/.

Obra original do projeto Hyakki, liberada em CC0-1.0 (entrada `hyakki_altar_art` em
licenses/registry.json). Só biblioteca padrão (PNG escrito à mão com zlib), sem
aleatoriedade: rodar de novo produz os mesmos bytes. Cores da paleta do Ninja Adventure
(Palette.png, CC0), as mesmas das estátuas de pedra e do torii; alfa binário (0 ou 255),
seguro para filtro "nearest". Cada peça é desenhada numa camada própria com contorno escuro de
1 px (o estilo do Ninja Adventure) e as camadas são empilhadas de trás para a frente.

- altar.png: tira de 3 quadros 40x40 (120x40), âncora no centro de baixo, vista 3/4 de cima:
  0 = DORMENTE (altar de pedra com telhado, corda shimenawa, dois shide de papel em zigue-zague
  e o selo 封 entalhado na frente em violeta apagado), 1 = ATIVO (o selo brilha ciano/branco,
  rachaduras acesas na pedra e faíscas), 2 = GASTO (pedra mais cinza, rachada, canto do telhado
  quebrado, corda rompida caída, papel no chão, sem brilho);
- rune_circle.png: círculo de runas 96x96 para o chão (anéis concêntricos, 8 marcas de
  ideograma entre os anéis, octograma interno), branco e cinza-claro para o código tingir;
- rune_marks.png: tira de 4 runas 12x12 (brancas, para tingir);
- ofuda.png: tira de 4 quadros 6x10, talismã de papel com marcas vermelhas em inclinações
  diferentes (estilhaços quando o selo estoura);
- affix_icons.png: tira de 8 ícones 14x14 brancos com contorno escuro de 1 px, na ordem
  raijin (raio), kitsunebi (fogo de raposa), kagero (olho de miragem), iwa (rocha),
  kasumi (névoa em espiral), kongo (diamante), yomi (gota com caveira), kaze (rajada);
- elite_crest.png: brasão 24x24 do banner de Elite (moldura dourada em losango, fundo
  vermelho e o kanji 強 em branco).

Também atualiza só as linhas desta licença em assets/asset_index.json (hash e origem).
Depois rode o import do Godot para criar os .import.
Uso: python -I tools/gen_altar_art.py
"""
import hashlib
import json
import math
import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "art" / "altar"
LICENSE_ID = "hyakki_altar_art"
TAU = 2.0 * math.pi

# Paleta do Ninja Adventure (subconjunto; a pedra é a mesma rampa das estátuas de house.png).
OUTLINE = (0x14, 0x1B, 0x1B)
STONE_HI = (0xFC, 0xE2, 0xCA)
STONE_L = (0xEE, 0xCF, 0x9B)
STONE_M = (0xD2, 0xB3, 0x7D)
STONE_S = (0xC8, 0x96, 0x6B)
STONE_D = (0xBD, 0x79, 0x59)
STONE_DD = (0x96, 0x53, 0x40)
ROPE_L = (0xF4, 0xDC, 0x8C)
ROPE_M = (0xD8, 0xB0, 0x5C)
ROPE_D = (0xA0, 0x74, 0x34)
PAPER = (0xF2, 0xEA, 0xF1)
PAPER_S = (0xB4, 0xB8, 0xC8)
VERMILION = (0xD1, 0x4B, 0x34)
DEEP_RED = (0x8E, 0x20, 0x30)
SEAL_DIM = (0x6A, 0x5C, 0xA8)
SEAL_DIM_D = (0x4A, 0x52, 0x70)
SKY = (0x79, 0xB8, 0xCE)
CYAN = (0x71, 0xDD, 0xEE)
FOAM = (0x8F, 0xEF, 0xF1)
WHITE = (0xF2, 0xEA, 0xF1)
PURE = (0xFF, 0xFF, 0xFF)
LIGHT = (0xC8, 0xC8, 0xD2)  # segundo tom das peças tingíveis
GOLD_HI = (0xFF, 0xF0, 0xA0)
GOLD = (0xF4, 0xB4, 0x3C)
GOLD_D = (0xB0, 0x6A, 0x1C)
GOLD_DD = (0x6A, 0x3A, 0x10)
CREST_RED = (0xC8, 0x30, 0x2C)
CREST_RED_D = (0x7A, 0x14, 0x22)

ALTAR = 40


# --- Tela de pixels (listas de linhas; None = transparente) ----------------------------

def blank(w: int, h: int) -> list:
    return [[None] * w for _ in range(h)]


def put(img: list, x: int, y: int, c) -> None:
    if 0 <= y < len(img) and 0 <= x < len(img[0]):
        img[y][x] = c


def rect(img: list, x0: int, y0: int, x1: int, y1: int, c) -> None:
    """Retângulo cheio, extremos inclusos."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(img, x, y, c)


def stamp(img: list, rows: list, x0: int, y0: int, colors: dict) -> None:
    """Desenha um mapa de caracteres; '.' e ' ' são transparentes."""
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch in colors:
                put(img, x0 + dx, y0 + dy, colors[ch])


def outlined(img: list, color=OUTLINE, diagonal: bool = False) -> list:
    """Cópia com contorno de 1 px em volta do que é opaco."""
    h, w = len(img), len(img[0])
    out = [list(r) for r in img]
    dirs = ((1, 0), (-1, 0), (0, 1), (0, -1))
    if diagonal:
        dirs += ((1, 1), (-1, 1), (1, -1), (-1, -1))
    for y in range(h):
        for x in range(w):
            if img[y][x] is not None:
                continue
            for dx, dy in dirs:
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and img[ny][nx] is not None:
                    out[y][x] = color
                    break
    return out


def over(dst: list, src: list, ox: int = 0, oy: int = 0) -> None:
    for y, row in enumerate(src):
        for x, c in enumerate(row):
            if c is not None:
                put(dst, x + ox, y + oy, c)


def recolor(img: list, fn) -> list:
    return [[None if c is None else fn(c) for c in row] for row in img]


def strip(frames: list) -> list:
    return [sum((f[y] for f in frames), []) for y in range(len(frames[0]))]


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


# --- Altar ------------------------------------------------------------------------------

# Selo 封 (圭 + 寸) entalhado no painel da frente do altar, 8x9.
SEAL = [
    ".X....X.",
    "XXX...X.",
    ".X..XXXX",
    "XXX...X.",
    "....X.X.",
    ".X....X.",
    "XXX...X.",
    ".X...XX.",
    "XXX.....",
]
SEAL_X, SEAL_Y = 16, 16
# Painel rebaixado onde o selo fica (inclusivo).
PANEL = (15, 15, 24, 26)

# Rachaduras finas da pedra, saindo do painel para as bordas (acendem no estado ATIVO).
CRACKS_FACE = [
    [(14, 17), (13, 18), (13, 19)],
    [(25, 20), (26, 21), (26, 22)],
    [(14, 25), (13, 26)],
    [(25, 15), (26, 14)],
]
CRACKS_BASE = [
    [(16, 28), (15, 29), (15, 30)],
    [(24, 28), (25, 29)],
]
# Fenda grande do altar gasto: atravessa o monólito de cima a baixo e entra na laje.
SPLIT = [(21, 10), (21, 11), (20, 12), (20, 13), (21, 14), (21, 15), (20, 16), (19, 17), (19, 18), (20, 19),
         (20, 20), (21, 21), (21, 22), (20, 23), (20, 24), (21, 25), (21, 26), (22, 27), (22, 28), (23, 29),
         (23, 30)]
CRACKS_SPENT = [
    [(14, 17), (13, 18), (13, 19), (14, 20)],
    [(25, 21), (26, 22)],
    [(8, 35), (9, 36), (9, 37)],
    [(31, 31), (32, 32), (31, 33)],
]


def slab(x0: int, x1: int, top0: int, top1: int, front1: int, spent: bool) -> list:
    """Laje de pedra vista de cima em 3/4: face de cima clara e frente mais escura."""
    img = blank(ALTAR, ALTAR)
    rect(img, x0, top0, x1, top1, STONE_L)
    rect(img, x0 + 1, top0, x1 - 1, top0, STONE_HI)
    rect(img, x0, top1 + 1, x1, front1, STONE_M)
    rect(img, x0, front1, x1, front1, STONE_S)
    rect(img, x1 - 1, top1 + 1, x1, front1, STONE_S)
    rect(img, x0, top1 + 1, x0, front1 - 1, STONE_L)
    # Juntas dos blocos na frente da laje.
    for x in range(x0 + 7, x1 - 3, 9):
        rect(img, x, top1 + 2, x, front1 - 1, STONE_D)
    # Cantos de cima chanfrados.
    img[top0][x0] = None
    img[top0][x1] = None
    if spent:
        img[front1][x0] = None
        img[front1][x0 + 1] = None
    return outlined(img)


def roof(spent: bool) -> list:
    """Telhado de quatro águas em pedra (kasa) com beiral e a joia hōju no topo."""
    img = blank(ALTAR, ALTAR)
    for i, y in enumerate(range(3, 8)):
        x0, x1 = 13 - i, 26 + i
        for x in range(x0, x1 + 1):
            # Água da esquerda clara, da direita na sombra, cumeeira mais clara.
            c = STONE_L if x < 20 else STONE_M
            if y == 3:
                c = STONE_HI if x < 20 else STONE_L
            if x in (x0, x0 + 1) and y > 3:
                c = STONE_S
            if x in (x1, x1 - 1) and y > 3:
                c = STONE_D
            img[y][x] = c
    rect(img, 7, 8, 32, 8, STONE_M)
    rect(img, 7, 9, 32, 9, STONE_D)
    img[8][7] = STONE_S
    img[8][32] = STONE_S
    img[9][7] = None
    img[9][32] = None
    # Telhas na frente do beiral.
    for x in range(10, 31, 3):
        img[8][x] = STONE_S
    if not spent:
        stamp(img, [".XX.", "XHXX", "XXXS"], 18, 0, {"X": STONE_M, "H": STONE_HI, "S": STONE_S})
    else:
        # Canto direito do telhado quebrado (a joia caiu: fica no chão, em rubble()).
        for y, x0 in ((5, 28), (6, 27), (7, 28), (8, 26), (9, 25)):
            for x in range(x0, 33):
                img[y][x] = None
        for x, y in ((27, 5), (26, 6), (27, 7), (25, 8), (24, 9)):
            img[y][x] = STONE_DD
        img[2][19] = STONE_S
        img[2][20] = STONE_S
    return outlined(img)


def seal_pixels() -> set:
    return {(SEAL_X + dx, SEAL_Y + dy) for dy, row in enumerate(SEAL) for dx, ch in enumerate(row) if ch == "X"}


def grow(pixels: set) -> set:
    return {(x + ox, y + oy) for x, y in pixels for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1))} - pixels


def monolith(state: int) -> list:
    img = blank(ALTAR, ALTAR)
    rect(img, 12, 10, 27, 27, STONE_M)
    rect(img, 12, 10, 27, 10, STONE_D)       # sombra do beiral
    rect(img, 12, 11, 12, 27, STONE_L)       # quina iluminada
    rect(img, 13, 11, 13, 27, STONE_HI)
    rect(img, 25, 11, 26, 27, STONE_S)       # lado na sombra
    rect(img, 27, 11, 27, 27, STONE_D)
    # Painel rebaixado: sombra no alto/esquerda, beirada clara embaixo/direita.
    px0, py0, px1, py1 = PANEL
    fill = {0: STONE_S, 1: SEAL_DIM_D, 2: STONE_D}[state]
    rect(img, px0, py0, px1, py1, fill)
    rect(img, px0, py0, px1, py0, STONE_DD if state != 1 else SKY)
    rect(img, px0, py0, px0, py1, STONE_DD if state != 1 else SKY)
    rect(img, px0 + 1, py1, px1, py1, STONE_L)
    rect(img, px1, py0 + 1, px1, py1, STONE_L)
    glyph = seal_pixels()
    if state == 0:
        for x, y in glyph:
            img[y][x] = SEAL_DIM
        for x, y in glyph:
            if (x, y + 1) not in glyph and y + 1 < py1:
                img[y + 1][x] = SEAL_DIM_D
    elif state == 1:
        ring1 = grow(glyph)
        ring2 = grow(ring1 | glyph) - glyph
        for x, y in ring2:
            if px0 < x < px1 and py0 < y < py1 and (x + y) % 2 == 0:
                img[y][x] = SKY
        for x, y in ring1:
            if px0 < x < px1 and py0 < y < py1:
                img[y][x] = CYAN
        for x, y in glyph:
            img[y][x] = PURE
        for crack in CRACKS_FACE:
            for i, (x, y) in enumerate(crack):
                img[y][x] = FOAM if i == 0 else CYAN
    else:
        # Selo apagado: só restam riscos escuros onde estava o glifo.
        for x, y in glyph:
            if (x + y) % 3:
                img[y][x] = STONE_DD
        for crack in CRACKS_SPENT[:2]:
            for x, y in crack:
                img[y][x] = OUTLINE
        for x, y in SPLIT:
            if 10 <= y <= 27:
                img[y][x] = OUTLINE
                if img[y][x + 1] is not None and (x + 1, y) not in SPLIT:
                    img[y][x + 1] = STONE_DD
    return outlined(img)


def rope(spent: bool) -> list:
    """Shimenawa: corda torcida de 3 px, um pouco caída no meio, com nós nas pontas."""
    img = blank(ALTAR, ALTAR)

    def sag(x: int) -> int:
        return 11 + (1 if 15 <= x <= 24 else 0)

    def segment(x0: int, x1: int) -> None:
        for x in range(x0, x1 + 1):
            y0 = sag(x)
            for k in range(3):
                t = (x + k) % 3
                img[y0 + k][x] = ROPE_L if t == 0 else ROPE_M if t == 1 else ROPE_D
            img[y0 + 2][x] = ROPE_D if (x % 3) else ROPE_M

    knot = {"X": ROPE_M, "L": ROPE_L, "D": ROPE_D}
    stamp(img, ["LX", "XD", "X.", "D."], 9, 11, knot)
    stamp(img, ["XL", "DX", ".X", ".D"], 29, 11, knot)
    if not spent:
        segment(11, 28)
    else:
        # Rompida no meio: a metade da esquerda caiu e pende até a laje.
        segment(22, 28)
        stamp(img, ["L", "X", "D"], 21, 13, knot)
        for i, y in enumerate(range(15, 26)):
            x = 11 + min(2, i // 4)
            img[y][x] = ROPE_L if i % 3 == 0 else ROPE_M if i % 3 == 1 else ROPE_D
            img[y][x + 1] = ROPE_D if i % 3 else ROPE_M
    return outlined(img)


# Shide: papel dobrado em zigue-zague, 2 px de largura e 3 colunas de deslocamento.
SHIDE = [
    "PS.",
    "PS.",
    ".PS",
    ".PS",
    "PS.",
    "PS.",
    ".PS",
    ".P.",
]


def shide(x: int, y: int, mirror: bool = False) -> list:
    img = blank(ALTAR, ALTAR)
    rows = [r[::-1] for r in SHIDE] if mirror else SHIDE
    stamp(img, rows, x, y, {"P": PAPER, "S": PAPER_S})
    return outlined(img)


def fallen_paper() -> list:
    img = blank(ALTAR, ALTAR)
    stamp(img, ["PPS.PP", ".PSPPS"], 5, 32, {"P": PAPER, "S": PAPER_S})
    return outlined(img)


def rubble() -> list:
    img = blank(ALTAR, ALTAR)
    stamp(img, [".LM", "LMS", "MSD"], 33, 33, {"L": STONE_L, "M": STONE_M, "S": STONE_S, "D": STONE_D})
    stamp(img, ["LM", "MS"], 29, 37, {"L": STONE_L, "M": STONE_M, "S": STONE_S})
    stamp(img, [".XX.", "XHXX", "XXXS"], 1, 36, {"X": STONE_M, "H": STONE_HI, "S": STONE_S})
    return outlined(img)


def sparks() -> list:
    img = blank(ALTAR, ALTAR)
    for x, y, big in ((7, 13, True), (32, 11, False), (34, 19, True), (5, 22, False), (24, 1, False),
                      (14, 1, False)):
        img[y][x] = PURE
        if big:
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                img[y + oy][x + ox] = CYAN
    return img


def weather(c: tuple) -> tuple:
    """Pedra gasta: puxa 38% para um cinza quente (o selo morreu)."""
    if c == OUTLINE:
        return c
    g = (c[0] * 0.3 + c[1] * 0.5 + c[2] * 0.2)
    gray = (g * 0.92, g * 0.9, g * 0.88)
    return tuple(int(round(a * 0.62 + b * 0.38)) for a, b in zip(c, gray))


def altar_frame(state: int) -> list:
    spent = state == 2
    img = blank(ALTAR, ALTAR)
    lower = slab(3, 36, 30, 34, 38, spent)
    if spent:
        for crack in CRACKS_SPENT[2:]:
            for x, y in crack:
                lower[y][x] = OUTLINE
    over(img, lower)
    upper = slab(7, 32, 26, 27, 31, spent)
    for crack in CRACKS_BASE:
        for i, (x, y) in enumerate(crack):
            if state == 1:
                upper[y][x] = FOAM if i == 0 else CYAN
            elif state == 2:
                upper[y][x] = OUTLINE
    if spent:
        for x, y in SPLIT:
            if y >= 28:
                upper[y][x] = OUTLINE
    over(img, upper)
    over(img, monolith(state))
    over(img, roof(spent))
    over(img, rope(spent))
    if not spent:
        # No estado ativo o papel balança (desce 1 px e o da direita vira).
        over(img, shide(12, 14 + (1 if state == 1 else 0)))
        over(img, shide(25, 14, mirror=state != 1))
    else:
        over(img, shide(25, 14, mirror=True))
        over(img, fallen_paper())
        over(img, rubble())
    if state == 1:
        over(img, sparks())
    if spent:
        img = recolor(img, weather)
    return img


# --- Círculo de runas e runas soltas -----------------------------------------------------

# Oito "ideogramas" 7x7 (desenho próprio, inspirado em kanji de selo).
GLYPHS7 = [
    ["..X....", "XXXXXXX", "..X.X..", ".XXXXX.", "..X.X..", "XXXXXXX", "..X...."],
    ["X.X.X.X", "XXXXXXX", "...X...", ".XXXXX.", ".X.X.X.", ".XXXXX.", "...X..."],
    ["XXX.XXX", "X.X.X.X", "XXX.XXX", "...X...", "XXXXXXX", "..X.X..", ".X...X."],
    ["...X...", "XXXXXXX", "X.....X", "..XXX..", "..X.X..", "..XXX..", "XXXXXXX"],
    [".X...X.", "XXX.XXX", ".X...X.", "XXXXXXX", "...X...", "..X.X..", ".X...X."],
    ["XXXXXXX", "...X...", ".XXXXX.", ".X.X.X.", ".XXXXX.", "...X...", "XXXXXXX"],
    ["X..X..X", ".X.X.X.", "..XXX..", "XXXXXXX", "..XXX..", ".X.X.X.", "X..X..X"],
    [".XXXXX.", ".X...X.", ".XXXXX.", "...X...", "XXXXXXX", "X..X..X", "..XXX.."],
]

# Quatro runas 10x10 para as marcas de progresso (desenho próprio).
RUNES10 = [
    ["....XX....", "XXXXXXXXXX", "....XX....", ".XXXXXXXX.", ".X..XX..X.", ".XXXXXXXX.",
     "....XX....", "XXXXXXXXXX", "....XX....", "....XX...."],
    ["XX..XX..XX", "XXXXXXXXXX", "....XX....", "XXXXXXXXXX", "X...XX...X", "X.XXXXXX.X",
     "X...XX...X", "XXXXXXXXXX", "...X..X...", "XXX....XXX"],
    ["..XX..XX..", "XXXXXXXXXX", "..XX..XX..", "..XXXXXX..", "......XX..", "XXXXXXXXXX",
     "...XX.....", "..XX..XX..", ".XX....XX.", "XX......XX"],
    ["XXXXXXXXXX", "X...XX...X", "X.XXXXXX.X", "X...XX...X", "X..XXXX..X", "X.XX..XX.X",
     "X...XX...X", "X.XXXXXX.X", "X...XX...X", "XXXXXXXXXX"],
]

CIRCLE = 96


def ring(img: list, r: float, c, width: float = 1.0) -> None:
    cx = cy = (CIRCLE - 1) / 2.0
    for y in range(CIRCLE):
        for x in range(CIRCLE):
            d = math.hypot(x - cx, y - cy)
            if abs(d - r) <= width / 2.0:
                img[y][x] = c


def line(img: list, x0: float, y0: float, x1: float, y1: float, c) -> None:
    steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(steps + 1):
        t = i / steps
        put(img, int(round(x0 + (x1 - x0) * t)), int(round(y0 + (y1 - y0) * t)), c)


def rune_circle() -> list:
    img = blank(CIRCLE, CIRCLE)
    c = (CIRCLE - 1) / 2.0
    ring(img, 46.6, PURE, 1.0)
    ring(img, 44.2, LIGHT, 0.9)
    ring(img, 30.0, PURE, 1.0)
    ring(img, 27.8, LIGHT, 0.9)
    ring(img, 12.0, PURE, 1.0)
    # Marcas finas entre os anéis externos (como a escala de um relógio de sol).
    for k in range(48):
        a = TAU * k / 48.0
        if k % 6 == 3:
            continue
        r0, r1 = (31.8, 34.0) if k % 2 == 0 else (31.8, 32.8)
        line(img, c + r0 * math.cos(a), c + r0 * math.sin(a), c + r1 * math.cos(a), c + r1 * math.sin(a), LIGHT)
    # Octograma: dois quadrados girados inscritos no anel interno.
    for off in (0.0, TAU / 8.0):
        pts = [(c + 27.3 * math.cos(off + TAU * k / 4.0 - TAU / 8.0), c + 27.3 * math.sin(off + TAU * k / 4.0 - TAU / 8.0))
               for k in range(4)]
        for k in range(4):
            line(img, *pts[k], *pts[(k + 1) % 4], LIGHT)
    # Raios curtos do anel do centro até o octograma.
    for k in range(8):
        a = TAU * k / 8.0 + TAU / 16.0
        line(img, c + 13.5 * math.cos(a), c + 13.5 * math.sin(a), c + 19.0 * math.cos(a), c + 19.0 * math.sin(a), PURE)
    # Oito ideogramas no meio da faixa externa, nos vãos da escala.
    for k in range(8):
        a = TAU * (k + 0.5) / 8.0 - TAU / 4.0
        gx = int(round(c + 38.6 * math.cos(a) - 3.0))
        gy = int(round(c + 38.6 * math.sin(a) - 3.0))
        for y in range(-1, 8):
            for x in range(-1, 8):
                put(img, gx + x, gy + y, None)
        stamp(img, GLYPHS7[k], gx, gy, {"X": PURE})
    # Ponto central.
    stamp(img, [".X.", "XXX", ".X."], int(c) - 1 + 1, int(c) - 1 + 1, {"X": PURE})
    return img


def rune_marks() -> list:
    frames = []
    for g in RUNES10:
        img = blank(12, 12)
        stamp(img, g, 1, 1, {"X": PURE})
        frames.append(img)
    return strip(frames)


# --- Ofuda --------------------------------------------------------------------------------

OFUDA = [
    # Em pé.
    ["OOOOOO", "OPPPPO", "OPRRPO", "OPPRPO", "OPRRPO", "OPPRPO", "OPRPPO", "OPRRPO", "OPPPPO", "OOOOOO"],
    # Inclinado para a direita (cisalhamento de 1 px a cada 4 linhas).
    ["..OOOO", ".OPPPO", ".OPRRO", "OPPRPO", "OPRRPO", "OPPRPO", "OPRPO.", "OPRRO.", "OPPPO.", "OOOO.."],
    # Dobrado (a ponta de baixo vira e mostra o verso).
    ["OOOOOO", "OPPPPO", "OPRRPO", "OPPRPO", "OPRRPO", "OPPRPO", "OPRPPO", "OSSSSO", "OOSSOO", "..OO.."],
    # Inclinado para a esquerda.
    ["OOOO..", "OPPPO.", "ORRPO.", "OPRPPO", "OPRRPO", "OPRPPO", ".OPRPO", ".ORRPO", ".OPPPO", "..OOOO"],
]


def ofuda() -> list:
    frames = []
    for rows in OFUDA:
        img = blank(6, 10)
        stamp(img, rows, 0, 0, {"O": OUTLINE, "P": PAPER, "R": VERMILION, "S": PAPER_S})
        frames.append(img)
    return strip(frames)


# --- Ícones dos afixos (12x12 desenhados + contorno = 14x14) -----------------------------

AFFIX_ICONS = {
    "raijin": [
        "......WWWW..",
        ".....WWWL...",
        "....WWWL....",
        "...WWWL.....",
        "..WWWWWWWW..",
        "..LLLWWWL...",
        "....WWWL....",
        "...WWWL.....",
        "..WWL.......",
        "..WL........",
        ".WL.........",
        ".W..........",
    ],
    "kitsunebi": [
        "......W.....",
        ".....WW.....",
        "....WWW..W..",
        "....WWWW.WW.",
        "...WWWWWWWW.",
        "..WWWLLWWWW.",
        "..WWLLLLWWW.",
        ".WWWL..LWWW.",
        ".WWWL..LWWW.",
        ".WWWWLLWWWW.",
        "..WWWWWWWW..",
        "....WWWW....",
    ],
    "kagero": [
        "............",
        "...WWWWWW...",
        ".WWWWWWWWWW.",
        "WWWW....WWWW",
        "WWW..WW..WWW",
        "WWWW....WWWW",
        ".WWWWWWWWWW.",
        "...WWWWWW...",
        "............",
        ".WW...WW...W",
        "W..WWW..WWW.",
        "............",
    ],
    "iwa": [
        "....WWWW....",
        "...WWWWWW...",
        "..WWWWWLWW..",
        ".WWWWWLWWWW.",
        ".WWWWLLWWWL.",
        "WWWWWLWWWWLL",
        "WWLLWWWWWLLL",
        "WWWLLWWWLLLL",
        "WWWWLLWLLLLL",
        ".WWWWWLLLLL.",
        "..WWWLLLLL..",
        "............",
    ],
    "kasumi": [
        "............",
        "...WWWWWW...",
        "..W......W..",
        ".W..WWWW..W.",
        ".W.W....W.W.",
        ".W.W.WW.W.W.",
        ".W.W..W.W.W.",
        "..W..WW..W..",
        "...W....W...",
        "WWWWWWWW..WW",
        "............",
        "WW..WWWWWWWW",
    ],
    "kongo": [
        "..WWWWWWWW..",
        ".WLWWLLWWLW.",
        "WWLLWLLWLLWW",
        "WWWWWWWWWWWW",
        ".WWLWWWWLWW.",
        "..WWLWWLWW..",
        "...WWLLWW...",
        "....WWWW....",
        ".....WW.....",
        "............",
        "............",
        "............",
    ],
    "yomi": [
        ".....W......",
        ".....WW.....",
        "....WWW.....",
        "...WWWWW....",
        "..WWWWWWW...",
        ".WWWWWWWWW..",
        ".WW..W..WW..",
        ".WW..W..WW..",
        ".WWWWLWWWW..",
        "..WWWWWWW...",
        "...W.W.W....",
        "..........W.",
    ],
    "kaze": [
        "........WW..",
        ".......W..W.",
        "WWWWWWWW..W.",
        ".........W..",
        "............",
        "WWWWWWWWWWW.",
        "............",
        "..WWWWWWWWW.",
        "..........W.",
        "......W..W..",
        ".......WW...",
        "............",
    ],
}
AFFIX_ORDER = ["raijin", "kitsunebi", "kagero", "iwa", "kasumi", "kongo", "yomi", "kaze"]


def affix_icons() -> list:
    frames = []
    for name in AFFIX_ORDER:
        img = blank(14, 14)
        stamp(img, AFFIX_ICONS[name], 1, 1, {"W": PURE, "L": LIGHT})
        frames.append(outlined(img))
    return strip(frames)


# --- Brasão do Elite ------------------------------------------------------------------------

KYO = [  # 強, 11x11
    "XXXX..X....",
    "...X.X..X..",
    "...XXXXXXX.",
    "XXXX.......",
    "X....XXXXX.",
    "XXXX.X.X.X.",
    "...X.XXXXX.",
    "...X...X...",
    "...X.XXXXXX",
    "...X...X..X",
    ".XX..XXXXXX",
]


def elite_crest() -> list:
    n = 24
    img = blank(n, n)
    c = (n - 1) / 2.0
    for y in range(n):
        for x in range(n):
            d = abs(x - c) + abs(y - c)  # losango
            if d <= 11.5:
                if d > 9.5:
                    # Aro dourado com bisel: claro em cima/esquerda, escuro embaixo/direita.
                    up = (x - c) + (y - c) < 0
                    img[y][x] = GOLD_HI if up and d > 10.5 else GOLD if up or d <= 10.5 else GOLD_D
                elif d > 8.5:
                    img[y][x] = GOLD_DD
                else:
                    img[y][x] = CREST_RED if (x - c) + (y - c) < 3 else CREST_RED_D
    # Pontas douradas nos quatro vértices.
    for x, y in ((11, 0), (12, 0), (11, 23), (12, 23), (0, 11), (0, 12), (23, 11), (23, 12)):
        img[y][x] = GOLD_HI if y < 12 and x < 12 or (y == 0) else GOLD_D
    # Sombra do kanji (1 px abaixo à direita) e o kanji.
    stamp(img, KYO, 7, 7, {"X": CREST_RED_D})
    stamp(img, KYO, 6, 6, {"X": WHITE})
    return outlined(img, OUTLINE)


# --- Saída -----------------------------------------------------------------------------------

def build() -> dict:
    return {
        "altar.png": strip([altar_frame(s) for s in range(3)]),
        "rune_circle.png": rune_circle(),
        "rune_marks.png": rune_marks(),
        "ofuda.png": ofuda(),
        "affix_icons.png": affix_icons(),
        "elite_crest.png": elite_crest(),
    }


def update_index(written: list) -> None:
    path = ROOT / "assets" / "asset_index.json"
    index = json.loads(path.read_text(encoding="utf-8"))
    names = {f.relative_to(ROOT).as_posix() for f in written}
    index = [row for row in index if row.get("license_id") != LICENSE_ID and row["file"] not in names]
    for file in written:
        index.append({
            "file": file.relative_to(ROOT).as_posix(),
            "source": "tools/gen_altar_art.py",
            "license_id": LICENSE_ID,
            "sha256": hashlib.sha256(file.read_bytes()).hexdigest(),
        })
    index.sort(key=lambda item: item["file"])
    path.write_text(json.dumps(index, indent=1, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for name, img in build().items():
        path = OUT / name
        write_png(path, img)
        written.append(path)
        print(f"{path.relative_to(ROOT).as_posix()}  {len(img[0])}x{len(img)}")
    update_index(written)
    print(f"{len(written)} arquivos gerados")
    return 0


if __name__ == "__main__":
    sys.exit(main())
