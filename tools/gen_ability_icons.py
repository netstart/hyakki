"""Gera os ícones das habilidades dos Guardiões em assets/art/ui/ability_icons/.

Obra original do projeto Hyakki (CC0-1.0), desenhada pixel a pixel aqui; nenhuma arte de
terceiros. Só biblioteca padrão (PNG escrito à mão com zlib), sem aleatoriedade: rodar de novo
produz os mesmos bytes. Alfa binário (0 ou 255), seguro para filtro "nearest".

- <id>.png (24x24), 21 ícones (7 heróis x 3 habilidades, IDs de .ai/04-habilidades-dos-guardioes.md):
  mesmo estilo dos ícones de tools/gen_skill_icons.gd (moldura de 3 px com contorno, bisel claro
  no alto/esquerda e escuro embaixo/direita, cantos chanfrados, fundo em degradê diagonal com
  halo central e pontilhado só na transição, brilho de canto, silhueta com contorno escuro de
  1 px e sombra projetada). A moldura de habilidade usa a cor da energia do herói no aro, com
  uma joia no topo e pontas nos cantos; o fundo é um tom que contrasta com essa cor.
- energy_<energia>.png (12x12), 7 glifos da energia de cada herói para a barra do HUD
  (sem moldura, fundo transparente, contorno escuro de 1 px).

Também atualiza as linhas assets/art/ui/ability_icons/* de assets/asset_index.json (hash e origem,
licença hyakki_ability_icons). Depois rode o import do Godot para criar os .import.
Uso: python -I tools/gen_ability_icons.py
"""
import hashlib
import json
import math
import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "art" / "ui" / "ability_icons"

SIZE = 24
INNER = 18  # área do fundo (3 px de moldura de cada lado)
OUTLINE = "0d0812"
GLYPH_OUTLINE = "120a18"

# --- Paleta das silhuetas (letra -> cor), a mesma de gen_skill_icons.gd + pele e tons extras ---
PAL = {
    "K": "120a18", "k": "2c1f33",
    "W": "ffffff", "L": "e4ecf4", "S": "a9b6c8", "D": "66708a", "Z": "3c4258",
    "Y": "fff0a0", "G": "f4b43c", "O": "b06a1c",
    "R": "e8483a", "r": "8e2030",
    "B": "a86c3c", "b": "5e3a22",
    "P": "f6ecd0", "p": "c9ae80",
    "F": "ffe08a", "f": "ff8a2a", "e": "d2402a",
    "T": "fff47a", "t": "ffc42a",
    "V": "c4a0ff", "v": "7a52d8",
    "C": "c8fcff", "c": "52cdf0", "n": "2273b0",
    "A": "d8fff2", "a": "62e4c0", "q": "2a9a8a",
    "M": "ecc4ff", "m": "a858e8", "u": "5c2a90",
    "g": "9ae870", "j": "3a9a4a",
    "H": "ff9cb0", "h": "d04a6a",
    "N": "3a2e4a", "I": "6a7ef0", "i": "3442a0",
    "s": "f6cfa4", "z": "c88a5e",
}

# --- Heróis: cor da energia (spec) e destaque Q/X/E/x, fundo [claro, médio, escuro] ---
HEROES = {
    "aki": {
        "energy": "order_flame", "color": "ffb347",
        "accent": {"Q": "fff6dc", "X": "ffdc9a", "E": "ffb347", "x": "c0601c"},
        "bg": ["b8c4ff", "4048a0", "100c34"],
        "abilities": ["dawn_step", "lantern_wall", "century_flame"],
    },
    "kenta": {
        "energy": "shadow", "color": "8f7cf0",
        "accent": {"Q": "f2eeff", "X": "d0c6ff", "E": "8f7cf0", "x": "4a38a0"},
        "bg": ["9adcd0", "2a6e78", "0a1c26"],
        "abilities": ["shadow_step", "kawarimi", "makibishi"],
    },
    "hana": {
        "energy": "prayer", "color": "9fffc4",
        "accent": {"Q": "f2fff8", "X": "d2ffe4", "E": "9fffc4", "x": "34a872"},
        "bg": ["ffa092", "b4242e", "36060e"],
        "abilities": ["harae", "kekkai", "grandmother_seal"],
    },
    "goro": {
        "energy": "penance", "color": "ffd36b",
        "accent": {"Q": "fffbe6", "X": "fff0b4", "E": "ffd36b", "x": "b07e22"},
        "bg": ["d8acff", "6a3aa8", "1c0a38"],
        "abilities": ["diamond_body", "shakujo", "master_mantra"],
    },
    "rin": {
        "energy": "focus", "color": "ffe08a",
        "accent": {"Q": "fffcec", "X": "fff2c0", "E": "ffe08a", "x": "b8963a"},
        "bg": ["b4f0a4", "3a8a58", "0a2a1a"],
        "abilities": ["hamaya", "hunting_trap", "swallow_leap"],
    },
    "tora": {
        "energy": "forge_heat", "color": "ff7a3a",
        "accent": {"Q": "fff0dc", "X": "ffc490", "E": "ff7a3a", "x": "b03c16"},
        "bg": ["b4c8e0", "44587a", "10182a"],
        "abilities": ["anvil_hammer", "chain_pull", "quench"],
    },
    "yuki": {
        "energy": "oni_blood", "color": "ff4a4a",
        "accent": {"Q": "ffe4e4", "X": "ffa4a4", "E": "ff4a4a", "x": "981a2a"},
        "bg": ["d4a8f0", "5a2c74", "18081e"],
        "abilities": ["oni_claw", "oni_roar", "onikiri_whirl"],
    },
}


# --- Cores e imagem (lista de linhas; None = transparente) ----------------------------------

def rgb(hexstr: str) -> tuple:
    return (int(hexstr[0:2], 16), int(hexstr[2:4], 16), int(hexstr[4:6], 16))


def lerp(a: tuple, b: tuple, t: float) -> tuple:
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def darken(c: tuple, amount: float) -> tuple:
    return tuple(int(round(v * (1.0 - amount))) for v in c)


WHITE = (255, 255, 255)


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


class Canvas:
    """Prancheta de silhueta: desenha com letras da paleta (Q/X/E/x = destaque do herói)."""

    def __init__(self, w: int, h: int, accent: dict) -> None:
        self.w, self.h = w, h
        self.px = blank(w, h)
        self.accent = accent

    def color(self, letter: str) -> tuple:
        if letter in self.accent:
            return rgb(self.accent[letter])
        return rgb(PAL[letter])

    def put(self, x: int, y: int, letter: str) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = self.color(letter)

    def clear(self, x: int, y: int) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = None

    def ascii(self, rows: list, ox: int = 0, oy: int = 0) -> None:
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == ".":
                    continue
                if ch == "_":  # buraco: apaga o que houver embaixo
                    self.clear(ox + x, oy + y)
                    continue
                self.put(ox + x, oy + y, ch)

    def line(self, x0: int, y0: int, x1: int, y1: int, letter: str) -> None:
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(steps + 1):
            t = 0.0 if steps == 0 else i / steps
            self.put(int(round(x0 + (x1 - x0) * t)), int(round(y0 + (y1 - y0) * t)), letter)

    def arc(self, cx: float, cy: float, r: float, a0: float, a1: float, letter: str, step: float = 2.0) -> None:
        """Arco de 1 px (graus; 0 = direita, 90 = baixo)."""
        a = a0
        while a <= a1 + 1e-6:
            rad = math.radians(a)
            self.put(int(round(cx + math.cos(rad) * r)), int(round(cy + math.sin(rad) * r)), letter)
            a += step


def outline(img: list, color: tuple) -> list:
    """Contorno escuro de 1 px (vizinhança de 4) em volta dos opacos; cresce 1 px de cada lado."""
    h, w = len(img), len(img[0])
    out = blank(w + 2, h + 2)
    for y in range(h):
        for x in range(w):
            out[y + 1][x + 1] = img[y][x]
    ring = []
    for y in range(h + 2):
        for x in range(w + 2):
            if out[y][x] is not None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w + 2 and 0 <= ny < h + 2 and out[ny][nx] is not None:
                    ring.append((x, y))
                    break
    for x, y in ring:
        out[y][x] = color
    return trim(out)


def trim(img: list) -> list:
    ys = [y for y, row in enumerate(img) if any(p is not None for p in row)]
    xs = [x for x in range(len(img[0])) if any(row[x] is not None for row in img)]
    if not ys:
        return img
    return [row[xs[0]:xs[-1] + 1] for row in img[ys[0]:ys[-1] + 1]]


# --- Fundo e moldura (mesmo algoritmo de gen_skill_icons.gd) --------------------------------

def background(img: list, bg: list) -> None:
    light, mid, dark = rgb(bg[0]), rgb(bg[1]), rgb(bg[2])
    tones = []
    for i in range(6):
        t = i / 5.0
        tones.append(lerp(dark, mid, t * 2.0) if t < 0.5 else lerp(mid, light, (t - 0.5) * 2.0))
    for y in range(3, 21):
        for x in range(3, 21):
            diag = 1.0 - ((x - 3) * 0.35 + (y - 3) * 0.65) / 17.0
            halo = min(max(1.0 - math.hypot(x + 0.5 - 12.0, y + 0.5 - 12.0) / 9.0, 0.0), 1.0)
            v = min(max(diag * 0.62 + halo * 0.42, 0.0), 1.0) * 4.999
            idx = math.floor(v)
            if v - idx > 0.82 and (x + y) % 2 == 0:
                idx += 1
            img[y][x] = tones[min(max(idx, 0), 5)]
    for i in range(3, 21):
        img[3][i] = darken(img[3][i], 0.35)
        img[i][3] = darken(img[i][3], 0.35)
    for x, y in ((5, 4), (4, 5), (6, 4), (4, 6), (5, 5)):
        img[y][x] = lerp(img[y][x], WHITE, 0.45)


def frame(img: list, hero_color: str) -> None:
    """Moldura de habilidade: aro na cor da energia, cantos chanfrados, joia no topo e na base."""
    base = rgb(hero_color)
    light = lerp(base, WHITE, 0.6)
    mid = base
    dark = darken(base, 0.55)
    inner = darken(base, 0.86)
    out = rgb(OUTLINE)
    chamfer = 2
    for y in range(SIZE):
        for x in range(SIZE):
            ring = min(x, y, SIZE - 1 - x, SIZE - 1 - y)
            if ring > 2:
                continue
            cx = min(x, SIZE - 1 - x)
            cy = min(y, SIZE - 1 - y)
            if cx + cy < chamfer:
                img[y][x] = None
                continue
            if ring == 0 or cx + cy == chamfer:
                img[y][x] = out
            elif ring == 1:
                top_left = (y == 1 or x == 1) and not (y == SIZE - 2 or x == SIZE - 2)
                bottom_right = (y == SIZE - 2 or x == SIZE - 2) and not (y == 1 or x == 1)
                img[y][x] = light if top_left else (dark if bottom_right else mid)
            else:
                img[y][x] = inner
    # Pontas nos cantos (losango claro sobre o aro interno).
    for cx, cy in ((2, 2), (21, 2), (2, 21), (21, 21)):
        img[cy][cx] = light
    # Joia no topo e na base: losango da cor da energia com brilho, presa no aro.
    for x in (11, 12):
        img[0][x] = out
        img[1][x] = WHITE if x == 11 else light
        img[2][x] = mid
        img[21][x] = mid
        img[22][x] = dark
        img[23][x] = out
    for x in (10, 13):
        img[1][x] = dark
        img[2][x] = inner
        img[22][x] = dark
    # Reflexo no aro, canto alto à esquerda.
    img[1][2] = WHITE
    img[2][1] = lerp(light, WHITE, 0.5)


def icon(hero: dict, glyph: list) -> list:
    img = blank(SIZE, SIZE)
    background(img, hero["bg"])
    gh, gw = len(glyph), len(glyph[0])
    ax = 3 + (INNER - gw) // 2
    ay = 3 + (INNER - gh) // 2
    shadow = (5, 0, 13)
    # Sombra projetada (1 px para baixo/direita, 55%) e depois a silhueta; recorte no fundo.
    for y in range(gh):
        for x in range(gw):
            px, py = ax + x + 1, ay + y + 1
            if glyph[y][x] is not None and 3 <= px < 21 and 3 <= py < 21:
                img[py][px] = lerp(img[py][px], shadow, 0.55)
    for y in range(gh):
        for x in range(gw):
            px, py = ax + x, ay + y
            if glyph[y][x] is not None and 3 <= px < 21 and 3 <= py < 21:
                img[py][px] = glyph[y][x]
    frame(img, hero["color"])
    return img


# --- Silhuetas das habilidades (prancheta 16x16 antes do contorno) --------------------------

def dawn_step(c: Canvas) -> None:
    # Katana em investida na diagonal deixando atrás três faixas de aurora.
    c.ascii([
        "..............LW",
        ".............LWS",
        "............LWS.",
        "...........LWS..",
        "..........LWS...",
        ".........LWS....",
        "......G.LWS.....",
        ".......GWS......",
        "......YOG.......",
        ".....PB..G......",
        "....BP..........",
        "...G............",
    ])
    # Faixas paralelas ao golpe, do pálido (perto) ao alaranjado (longe).
    for (x0, y0), cols in (((3, 8), "XEx"), ((2, 13), "Ex"), ((7, 12), "XXEx")):
        for i, col in enumerate(cols):
            c.put(x0 - i, y0 + i, col)


def lantern_wall(c: Canvas) -> None:
    # Anel de luz em volta de uma chōchin acesa.
    for y in range(16):
        for x in range(16):
            d = math.hypot(x + 0.5 - 8.0, y + 0.5 - 8.0)
            if 6.6 <= d < 8.0:
                c.put(x, y, "X" if (x + 0.5 - 8.0) + (y + 0.5 - 8.0) < -2.0 else "E")
    for x, y in ((7, 0), (8, 0), (0, 7), (0, 8), (15, 7), (15, 8), (7, 15), (8, 15)):
        c.put(x, y, "Q")
    c.ascii([
        "..bb..",
        ".bbbb.",
        "fFYYFf",
        "eOOOOe",
        "fYWWYf",
        "fYWYYf",
        "eOOOOe",
        "fFYYFf",
        ".bbbb.",
    ], 5, 3)


def century_flame(c: Canvas) -> None:
    # Coluna de fogo reta (pilar) subindo de um chão em brasa.
    c.ascii([
        "......e.e.......",
        ".....efefe......",
        ".....fYfYf......",
        "....efYWYfe.....",
        ".....fYWYf......",
        "....efYWYfe.....",
        ".....fYWYf......",
        "....efYWYfe.....",
        ".....fYWYf......",
        "....efYWYfe.....",
        ".....fYWYf......",
        "...eefYWYfee....",
        "..EeffYWYffeE...",
        ".xEEeffYffeEEx..",
        "xxEEEeeeeeEEExx.",
        ".xxxxEEEEExxxx..",
    ], 1, 0)


def shadow_step(c: Canvas) -> None:
    # Ninja que se desfaz em fumaça violeta.
    c.ascii([
        ".........uuuu...",
        "........uEuuuu..",
        "........usWsWu..",
        "........uuuuuu..",
        ".........uuuu...",
        ".......uuEuuuuu.",
        "......uuEuuuuuuu",
        "......uEuuuuuuu.",
        ".......uuxxuuu..",
        "......XEuuuuuE..",
        "..QX.XQXEuuEXX..",
        ".QXXEXQQXEEXQXE.",
        ".XXEEXXQXXEXXE..",
        "..EE.EXXEEXEE...",
        "......EE..EE....",
    ])


def kawarimi(c: Canvas) -> None:
    # Tronco-isca com nuvem de fumaça.
    c.ascii([
        "....QQQ.........",
        "..QQQQQQ.XXX....",
        ".QQQXQQQXQQQX...",
        ".XQQQXXQQQQXXX..",
        "..XXEXXEXXXEE...",
        "....EE..EE......",
        "................",
        "..PPPBBBBBBBBB..",
        ".PpppPBBbBBBBBb.",
        ".PpbpPBBBBbBBBb.",
        ".PpppPbBBBBBbBb.",
        "..PPPbbbbbbbbb..",
    ])


def makibishi(c: Canvas) -> None:
    # Três estrepes de ferro espalhadas (uma ponta para cima, três apoiadas), núcleo violeta.
    spike = [
        "...W...",
        "...L...",
        "..WLS..",
        "..LES..",
        ".LLxSD.",
        "LS.S.SD",
        "S..D..D",
    ]
    c.ascii(spike, 0, 1)
    c.ascii(spike, 9, 0)
    c.ascii(spike, 5, 9)


def harae(c: Canvas) -> None:
    # Gohei: bastão com dois shide (papel cortado em raio) e o arco verde da varredura.
    c.arc(8.0, 9.0, 7.6, 135.0, 200.0, "E", 3.0)
    c.arc(8.0, 9.0, 7.6, -20.0, 45.0, "E", 3.0)
    bolt = [
        "..WWWW",
        ".WWWL.",
        ".WWL..",
        "WWWWWW",
        "..WWL.",
        ".WWL..",
        ".WL...",
        "WL....",
    ]
    c.ascii(bolt, 1, 2)
    c.ascii([row[::-1].replace("L", "S") for row in bolt], 9, 2)
    c.ascii(["GG", "YO"] + ["BB"] * 8 + ["Bb"] * 5 + ["bb"], 7, 0)


def kekkai(c: Canvas) -> None:
    # Anel de barreira com quatro ofuda presos nos pontos cardeais.
    for y in range(16):
        for x in range(16):
            d = math.hypot(x + 0.5 - 8.0, y + 0.5 - 8.0)
            if 5.6 <= d < 7.0:
                c.put(x, y, "X" if y < 8 else "E")
    ofuda = ["PPP", "PRP", "PPP", "PRP", "ppp"]
    c.ascii(ofuda, 7, 0)
    c.ascii(ofuda, 7, 11)
    c.ascii(["PPPPp", "PRRPp", "PPPPp"], 0, 7)
    c.ascii(["PPPPp", "PRRPp", "PPPPp"], 11, 7)
    c.ascii([".Q.", "QWQ", ".Q."], 7, 7)


def grandmother_seal(c: Canvas) -> None:
    # Ofuda grande com o selo vermelho da avó carimbado por cima.
    c.ascii([
        "..PPPPPPPPp.....",
        "..PRRRRRRPp.....",
        "..PPPPPPPPp.....",
        "..PPPkPPPPp.....",
        "..PkkkkkkPp.....",
        "..PPkPPkPPp.....",
        "..PkPkkPkPp.....",
        "..PPPkkPPPp.....",
        "..PPkPPkPPp.....",
        "..PPPPrrrrrr....",
        "..PPPrRRRRRRr...",
        "..PPPrRWRRWRr...",
        "..pppRWWWWWWr...",
        ".....rRWRRWRr...",
        ".....rRWWWWRr...",
        "......rrrrrr....",
    ])
    for x, y in ((13, 1), (14, 3), (0, 8), (13, 6), (15, 10)):
        c.put(x, y, "E")
    c.put(14, 2, "X")
    c.put(0, 7, "X")


def diamond_body(c: Canvas) -> None:
    # Punho dourado facetado (brilhos de diamante) com raios de aura.
    c.ascii([
        "...XX.XX.XX.XX..",
        "..XQYGQYGQYGQYG.",
        "..XYWGXYGXWGXYG.",
        "..XYYGXYGXYGXYG.",
        "..OGGOOGOOGOOGO.",
        ".XQYYYYYWYGOXYGx",
        ".XYYYYYYYYGOXYGx",
        "..OGGGGGGGOOGGOx",
        "...XYYYYYWYYYGx.",
        "....OGGGGGGGGOx.",
        ".....XYYYYGOx...",
        ".....XYYYYGOx...",
        ".....xxxxxxxx...",
    ], 0, 2)
    for x, y in ((0, 0), (15, 0), (0, 14), (15, 15), (1, 1), (14, 1)):
        c.put(x, y, "E" if (x, y) in ((0, 0), (15, 0)) else "X")


def shakujo(c: Canvas) -> None:
    # Shakujō: argola pontuda com quatro anéis enfiados; a ponta bate no chão (onda de choque).
    c.ascii([
        ".......YY.......",
        "......YGGO......",
        ".....YG..GO.....",
        "....YG.YO.GO....",
        "....G..YO..O....",
        "...YG..YO..GO...",
        "...G...YO...O...",
        "...G...YO...O...",
        "....G..YO..O....",
        ".....GGYOGG.....",
        ".......Bb.......",
        ".......Bb.......",
        ".......Bb.......",
        "..E....GO....E..",
        ".X.E..EGOE..E.X.",
        "X...E......E...X",
    ])
    ring = [".YY.", "Y..G", "Y..O", ".GO."]
    for x, y in ((0, 3), (1, 7), (12, 3), (11, 7)):
        c.ascii(ring, x, y)


def master_mantra(c: Canvas) -> None:
    # Mão do monge erguida em prece (gasshō de uma mão), rosário no pulso, ondas de mantra.
    for r, col in ((7.6, "E"), (5.9, "X")):
        c.arc(8.0, 7.0, r, 150.0, 210.0, col, 4.0)
        c.arc(8.0, 7.0, r, -30.0, 30.0, col, 4.0)
    c.ascii([
        ".....Ws....",
        ".....szWs..",
        "...Wsszsz..",
        "...szszszWs",
        "...szszszsz",
        "...szszszsz",
        "Ws.sssssssz",
        "ss.sssssssz",
        ".szsssssssz",
        "..sssssssz.",
        "...bObObO..",
        "...OGYYGO..",
        "..OGYGGYGO.",
    ], 3, 1)


def hamaya(c: Canvas) -> None:
    # Flecha sagrada branca com fita vermelha e penas brancas.
    c.line(3, 12, 12, 3, "P")
    c.line(4, 12, 12, 4, "p")
    c.ascii([
        "..LWW",
        "...LW",
        "..SLL",
        ".S..L",
    ], 11, 0)
    c.ascii([
        ".WW....",
        "WLWW...",
        "LW.....",
        ".LW....",
        "..L....",
    ], 0, 10)
    c.ascii(["RR", "Rr", ".rR", "..r"], 5, 9)
    c.put(15, 4, "X")
    c.put(14, 6, "E")
    c.put(9, 0, "E")


def hunting_trap(c: Canvas) -> None:
    # Armadilha de mandíbula aberta com placa-gatilho e corrente.
    c.ascii([
        "...DSLLLLLLSD...",
        "..DLWSWSWSWLLD..",
        ".DL.W.W.W.W..LD.",
        "DSL..........LSD",
        "DS....xEEx....SD",
        "DS....EXXE....SD",
        "DS....xEEx....SD",
        "DSD..........DSD",
        ".DS.S.S.S.S..SD.",
        "..DSSWSWSWSWSD..",
        "...DDSSSSSSDD...",
        ".......DS.......",
        "......D..D......",
        ".......SD.......",
        "......D..D......",
        ".......DD.......",
    ])


def swallow_leap(c: Canvas) -> None:
    # Andorinha saltando para trás e o leque de flechas disparado lá embaixo.
    c.ascii([
        ".......ii.......",
        "Ii....iRRi....iI",
        ".IIi..iWWi..iII.",
        "..IIIiiWWiiIII..",
        "...iiiiWWiiii...",
        "......iWWi......",
        "......iiii......",
        ".....ii..ii.....",
    ])
    for (x0, y0), (dx, dy) in (((5, 10), (-1, 1)), ((8, 10), (0, 1)), ((11, 10), (1, 1))):
        for i in range(3):
            c.put(x0 + dx * i, y0 + dy * i, "E")
        tx, ty = x0 + dx * 3, y0 + dy * 3
        c.put(tx, ty, "W")
        if dx == 0:
            c.put(tx - 1, ty - 1, "Q")
            c.put(tx + 1, ty - 1, "Q")
        else:
            c.put(tx - dx, ty, "Q")
            c.put(tx, ty - dy, "Q")


def anvil_hammer(c: Canvas) -> None:
    # Martelo batendo na bigorna, chuva de fagulhas.
    c.line(9, 6, 15, 0, "B")
    c.line(10, 6, 15, 1, "b")
    c.ascii([
        ".ZDDDDDZ.",
        "ZSLLLLLSD",
        "DLLWLLLSD",
        "DSSSSSSDD",
        ".ZDDDDDZ.",
    ], 4, 4)
    c.ascii([
        "Y.....",
        ".f..Q.",
        "Q.E...",
    ], 0, 6)
    c.ascii(["E", ".", "X"], 14, 6)
    c.ascii([
        "LLLLLLLLLLLLLL..",
        ".SSSSSSSSSSSSD..",
        "...DSSSSSSD.....",
        "....DSSSSD......",
        "...DDSSSSDD.....",
        "..ZZZZZZZZZZ....",
    ], 1, 10)


def chain_pull(c: Canvas) -> None:
    # Corrente girando em espiral com a foice na ponta; tudo puxado para o centro em brasa.
    pts = []
    for a in range(-70, 236, 4):
        rad = math.radians(a)
        r = 7.0 - (a + 70) / 306.0 * 2.4
        p = (int(round(7.5 + math.cos(rad) * r)), int(round(8.5 + math.sin(rad) * r)))
        if not pts or pts[-1] != p:
            pts.append(p)
    for i, (x, y) in enumerate(pts):
        c.put(x, y, "L" if (i // 2) % 2 == 0 else "S")
    c.ascii([
        "..LWWWW",
        ".LSDD.W",
        "LSD....",
        "SD.....",
    ], 9, 0)
    c.ascii([
        "E.....E",
        ".X...X.",
        "...Q...",
        "..QWQ..",
        "...Q...",
        ".X...X.",
        "E.....E",
    ], 4, 5)


def quench(c: Canvas) -> None:
    # Têmpera: lâmina em brasa entrando na água, colunas de vapor subindo dos dois lados.
    c.ascii([
        ".............bb.",
        "............bOb.",
        "...........LSb..",
        "..........WLS...",
        ".........WXE....",
        "........WXEf....",
        ".......WYEf.....",
        "......WYEf......",
        ".....WYEe.......",
        "....WFEe........",
        "....Fe..........",
    ], 0, 1)
    c.ascii([".Q..", "QLQ.", ".L..", "..Q.", ".QLQ", "QLLLQ", "LLSLL", ".SDS."], 0, 3)
    c.ascii(["..Q.", ".QLQ", "..L.", ".Q..", "QLQ.", "LLLQ", "SLLL", ".SS."], 12, 5)
    c.ascii([
        "..CWC......C....",
        ".CcCccCc.CcCc...",
        "cnnccnnnccnnnc..",
        ".nnnnnnnnnnnn...",
    ], 0, 12)


def oni_claw(c: Canvas) -> None:
    # Três garradas vermelhas em curva.
    for k, ox in enumerate((0, 4, 8)):
        pts = [(ox + 7, 0), (ox + 6, 2), (ox + 5, 4), (ox + 4, 6), (ox + 3, 8), (ox + 2, 10), (ox + 1, 12), (ox, 14)]
        for i, (x, y) in enumerate(pts):
            core = "Q" if i < 2 else ("X" if i < 5 else "E")
            c.put(x - 1, y, "x" if i > 5 else "E")
            c.put(x, y, core)
            c.put(x, y + 1, "E" if i < 6 else "x")
            if i < 6:
                c.put(x - 1, y + 1, "E")


def oni_roar(c: Canvas) -> None:
    # Máscara oni rugindo, com ondas do grito dos lados.
    c.ascii([
        "..P.........P...",
        "..PP.......PP...",
        "...Pp.xEx.pP....",
        "...pEEEEEEEp....",
        "..EkkEEEEEkkE...",
        "..EYYkEEEkYYE...",
        "..xYkYxExYkYx...",
        "..xEEExExEEEx...",
        "..EkWkWkWkWkE...",
        "..EkkrrrrrkkE...",
        "..EkWkWkWkWkE...",
        "...xEEEEEEEx....",
        "....xxxxxxx.....",
    ], 1, 1)
    c.arc(8.0, 8.0, 8.0, 160.0, 200.0, "X", 6.0)
    c.arc(8.0, 8.0, 8.0, -20.0, 20.0, "X", 6.0)


def onikiri_whirl(c: Canvas) -> None:
    # Katana com dois cortes em crescente girando em volta (redemoinho vermelho).
    for a0 in (200.0, 20.0):
        for k in range(0, 130, 2):
            a = math.radians(a0 + k)
            t = k / 130.0
            r = 7.4 - t * 1.4
            x = int(round(8.0 + math.cos(a) * r))
            y = int(round(8.0 + math.sin(a) * r))
            c.put(x, y, "Q" if t < 0.15 else ("X" if t < 0.45 else ("E" if t < 0.8 else "x")))
            if 0.1 < t < 0.7:
                xi = int(round(8.0 + math.cos(a) * (r - 1.0)))
                yi = int(round(8.0 + math.sin(a) * (r - 1.0)))
                c.put(xi, yi, "E" if t < 0.4 else "x")
    c.line(5, 11, 12, 4, "L")
    c.line(6, 11, 12, 5, "S")
    c.put(13, 3, "W")
    c.ascii(["G..", ".G.", "..G"], 3, 9)
    c.line(4, 12, 3, 13, "N")


ABILITIES = {
    "dawn_step": dawn_step, "lantern_wall": lantern_wall, "century_flame": century_flame,
    "shadow_step": shadow_step, "kawarimi": kawarimi, "makibishi": makibishi,
    "harae": harae, "kekkai": kekkai, "grandmother_seal": grandmother_seal,
    "diamond_body": diamond_body, "shakujo": shakujo, "master_mantra": master_mantra,
    "hamaya": hamaya, "hunting_trap": hunting_trap, "swallow_leap": swallow_leap,
    "anvil_hammer": anvil_hammer, "chain_pull": chain_pull, "quench": quench,
    "oni_claw": oni_claw, "oni_roar": oni_roar, "onikiri_whirl": onikiri_whirl,
}


# --- Glifos de energia (prancheta 10x10 antes do contorno -> 12x12) -------------------------

ENERGY_ART = {
    "order_flame": [
        "....X.....",
        "....XE....",
        "...XEE....",
        "..XEQEx...",
        "..EQQEx.x.",
        ".XEQWQEEx.",
        ".EQWWQEx..",
        ".EQWWQEx..",
        "..xEEEx...",
        "...xxx....",
    ],
    "shadow": [
        "...XXX....",
        "..XEEx....",
        ".XEx......",
        ".XEx......",
        ".EEx......",
        ".EEx......",
        ".xEEx.....",
        "..xEEEx..Q",
        "...xxEEEx.",
        ".....xxx..",
    ],
    "prayer": [
        "....Q.....",
        "....X.....",
        "...XEX....",
        "...QEE....",
        "..XQEEx...",
        ".XQWEEEx..",
        ".EQEEEEx..",
        ".EEEEEEx..",
        "..xEEEx...",
        "...xxx....",
    ],
    "penance": [
        "..XE..XE..",
        "..Ex..Ex..",
        "XE......XE",
        "Ex......Ex",
        "..........",
        "XE......XE",
        "Ex......Ex",
        "..XE..XE..",
        "..Ex.rR...",
        "......rR..",
    ],
    "focus": [
        "...xxxx...",
        "..xEEEEx..",
        ".xE....Ex.",
        "xE..XX..Ex",
        "xE.XQQX.Ex",
        "xE.XQQX.Ex",
        "xE..XX..Ex",
        ".xE....Ex.",
        "..xEEEEx..",
        "...xxxx...",
    ],
    "forge_heat": [
        "....Q.....",
        ".Q.....X..",
        "...ZZZD...",
        "..ZxEExD..",
        ".ZxEXQEx..",
        ".DEXQWXED.",
        ".ZxEXQXEx.",
        ".DZxEEExD.",
        "..DDZZZD..",
        "..........",
    ],
    "oni_blood": [
        ".P......P.",
        ".Pp....pP.",
        "..p.XE.p..",
        "....XE....",
        "...XQEE...",
        "..XQWEEx..",
        "..EQEEEx..",
        "..EEEEEx..",
        "...xEEx...",
        "....xx....",
    ],
}


def energy_glyph(hero: dict) -> list:
    c = Canvas(10, 10, hero["accent"])
    c.ascii(ENERGY_ART[hero["energy"]])
    img = outline(c.px, rgb(GLYPH_OUTLINE))
    # Centraliza em 12x12.
    out = blank(12, 12)
    oy = (12 - len(img)) // 2
    ox = (12 - len(img[0])) // 2
    for y, row in enumerate(img):
        for x, p in enumerate(row):
            out[oy + y][ox + x] = p
    return out


def build() -> dict:
    """Devolve {nome do arquivo: imagem} sem gravar (para a folha de contato e testes)."""
    out = {}
    for hero in HEROES.values():
        for ab in hero["abilities"]:
            c = Canvas(16, 16, hero["accent"])
            ABILITIES[ab](c)
            glyph = outline(trim(c.px), rgb(GLYPH_OUTLINE))
            out[ab + ".png"] = icon(hero, glyph)
        out["energy_" + hero["energy"] + ".png"] = energy_glyph(hero)
    return out


LICENSE_ID = "hyakki_ability_icons"


def update_index(written: list) -> None:
    path = ROOT / "assets" / "asset_index.json"
    index = json.loads(path.read_text(encoding="utf-8"))
    prefix = OUT.relative_to(ROOT).as_posix() + "/"
    index = [row for row in index if not row["file"].startswith(prefix)]
    for file in written:
        index.append({
            "file": file.relative_to(ROOT).as_posix(),
            "source": "tools/gen_ability_icons.py",
            "license_id": LICENSE_ID,
            "sha256": hashlib.sha256(file.read_bytes()).hexdigest(),
        })
    index.sort(key=lambda item: item["file"])
    path.write_bytes(json.dumps(index, indent=1, ensure_ascii=False).encode("utf-8"))


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    images = build()
    written = []
    for name, img in images.items():
        write_png(OUT / name, img)
        written.append(OUT / name)
    update_index(written)
    print("gen_ability_icons: %d imagens em %s" % (len(images), OUT.relative_to(ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
