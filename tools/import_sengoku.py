#!/usr/bin/env python3
"""Importador do Sengoku Pixel Pack (willYEE, CC0; https://willyee.itch.io/sengoku-pixel-pack)
para o Hyakki: arte dos chefes, dos guardioes e dos Elites dos altares.

Para cada saida da TABELA gera:
  Idle.png     tira horizontal de quadros iguais (layout "strip" do jogo), pes na ultima
               linha, alfa binario (0/255), cores so da paleta original do personagem;
  Faceset.png  retrato 38x38 com fundo transparente (chefes e guardioes).

Sem --out grava no jogo: assets/art/bosses/<id>/, assets/art/midbosses/<fase>/ e
assets/art/elites/<id>/ (so Idle.png), e atualiza as linhas desses arquivos em
assets/asset_index.json (licenca willyee_sengoku). Com --out grava tudo em <out>/<id>/.

Uso (rode fora da pasta do pack; os arquivos do pack sao dados, nao codigo; precisa do Pillow):
  python -E -P tools/import_sengoku.py --pack <Sengoku_Pixel_Pack> [--out <pasta>]
         [--game C:/src/hyakki] [--preview preview.png] [--anim id1,id2]
         [--method box_pal] [--methods-sheet methods.png]

Deterministico: sem aleatoriedade, paletas ordenadas, so operacoes do Pillow.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LICENSE_ID = "willyee_sengoku"

# ---------------------------------------------------------------------------------------------
# TABELA: (id_saida, grupo, personagem do pack, altura-alvo em px, opcoes)
#   altura-alvo = altura opaca do quadro de repouso (quadro 0 da tira de saida). Personagens
#   muito largos levam altura menor para o tamanho aparente casar com os outros do grupo.
#   opcoes:
#     anim   "move" (padrao), "idle" ou "idle+move"
#     face   (x, y, lado) do quadrado do rosto em px do pack, relativo ao canto superior
#            esquerdo da caixa opaca do quadro de repouso; sem isso, automatico (topo)
#     center "feet" (padrao: frame centrado nos pes do quadro de repouso) ou "box"
#     flip   espelha os quadros (personagem que olha para a direita passa a olhar para a esquerda)
#     recolor receita de RECOLOR aplicada aos quadros do pack antes de tudo (cor por cor,
#            deterministica); a paleta da saida passa a ser a recolorida
#     grow   deixa ampliar (altura-alvo maior que a do pack)
#     method metodo de reducao/ampliacao so desta saida (ex.: "nearest" para ampliar sem borrar)
#     soulfire chamas de alma violetas sobre o contorno de cima, diferentes em cada quadro
#   faces_left: para que lado o desenho original olha (True = esquerda), para data/*.json.
# ---------------------------------------------------------------------------------------------
BOSS, GUARD, ELITE = "chefe", "guardiao", "elite"
DEST = {BOSS: "assets/art/bosses", GUARD: "assets/art/midbosses", ELITE: "assets/art/elites"}
# Guardioes ficam na pasta da fase deles (assets/art/midbosses/<fase>/, como o Kincho em secret/).
GUARD_DIR = {"onikuma": "village", "nuppeppo": "bamboo", "onmoraki": "temple", "onibi": "dunes",
             "yomi_hebi": "yomi", "datsueba": "osorezan"}

TABLE = [
    # chefes (alvo ~80)
    ("tanuki",           BOSS,  "jp_mob_bakeneko",       80, {"face": (8, 0, 26)}),
    ("kappa_elder",      BOSS,  "jp_mob_kappa_v_blue",   76, {"face": (0, 0, 26)}),
    ("bamboo_ancestral", BOSS,  "jp_mob_kamaitachi",     62, {"face": (0, 0, 22)}),
    ("kitsune_nine",     BOSS,  "jp_boss_tamamo",        64, {"face": (0, 42, 44)}),
    ("tengu_crow_king",  BOSS,  "jp_boss_daitengu",      84, {"face": (70, 6, 46)}),
    ("faceless_monk",    BOSS,  "jp_mob_rokurokubi",     80, {"face": (0, 0, 19)}),
    ("stone_cyclops",    BOSS,  "jp_mob_nurikabe",       80, {"face": (8, 10, 56)}),
    ("ash_dragon",       BOSS,  "jp_boss_kiyohime",      84, {"face": (44, 0, 44)}),
    ("red_oni",          BOSS,  "jp_boss_shutendoji",    86, {"face": (48, 0, 52)}),
    ("kuroe",            BOSS,  "jp_mob_umibozu",        72, {"face": (4, 0, 46)}),
    ("izanami",          BOSS,  "jp_mob_yukionna",       80, {"face": (10, 0, 24)}),
    ("shinigami",        BOSS,  "jp_mob_gashadokuro",    80, {"face": (8, 0, 22)}),
    # Osorezan: samurai fantasma (o heroi prateado em azul espectral, virado para a esquerda) e a
    # Gashadokuro gigante (o esqueleto do Shinigami 1,5x, ossos marfim e fogo de alma violeta).
    ("masakado",         BOSS,  "jp_hero_samurai_v_silver", 80, {"anim": "walk", "flip": True,
                                                              "recolor": "spectral", "face": (6, 0, 24)}),
    ("gashadokuro",      BOSS,  "jp_mob_gashadokuro",   104, {"grow": True, "method": "nearest", "recolor": "ivory_soul",
                                                              "soulfire": True, "face": (8, 0, 22)}),
    # guardioes (alvo ~62)
    ("onikuma",          GUARD, "jp_mob_kasaobake",      62, {"face": (0, 14, 25)}),
    ("nuppeppo",         GUARD, "jp_mob_ittan",          34, {"face": (0, 4, 40)}),
    ("onmoraki",         GUARD, "jp_mob_jorogumo",       44, {"face": (44, 0, 22)}),
    ("onibi",            GUARD, "jp_mob_chochin",        60, {"face": (0, 4, 44)}),
    ("yomi_hebi",        GUARD, "jp_boss_orochi",        60, {"face": (36, 0, 40)}),
    # Datsue-ba: o gaki do pack (velha curvada, magra, de trapo) com pele cinza de velha e olhos rubros.
    ("datsueba",         GUARD, "jp_mob_gaki",           66, {"recolor": "hag", "face": (8, 0, 30)}),
    # elites (alvo ~36)
    ("kappa_young",      ELITE, "jp_mob_kappa",          36, {"face": (0, 0, 26)}),
    ("tengu_crow",       ELITE, "jp_mob_tengu",          36, {"face": (8, 6, 26)}),
    ("oni_small",        ELITE, "jp_mob_oni",            38, {"face": (4, 0, 22)}),
    ("kitsune_minor",    ELITE, "jp_mob_kitsune_v_silver", 34, {"face": (14, 0, 26)}),
    ("tsuchigumo",       ELITE, "jp_mob_jorogumo",       28, {"face": (44, 0, 22)}),
    ("lantern_obake",    ELITE, "jp_mob_chochin_v_purple", 36, {"face": (0, 4, 44)}),
    ("bakeneko",         ELITE, "jp_mob_bakeneko",       38, {"face": (8, 0, 26)}),
    ("hyakume",          ELITE, "jp_mob_hitotsume",      38, {"face": (18, 0, 28)}),
    ("skeleton_peasant", ELITE, "jp_mob_gashadokuro",    38, {"face": (8, 0, 22)}),
    ("yurei",            ELITE, "jp_mob_yukionna",       38, {"face": (10, 0, 24)}),
    ("shade_ghost",      ELITE, "jp_mob_ittan",          22, {"face": (0, 4, 40)}),
]

# Para que lado o desenho do pack olha (conferido nas tiras): True = esquerda.
FACES_LEFT = {
    "jp_mob_bakeneko": True, "jp_mob_kappa_v_blue": True, "jp_mob_kamaitachi": True,
    "jp_boss_tamamo": True, "jp_boss_daitengu": True, "jp_mob_rokurokubi": True,
    "jp_mob_nurikabe": True, "jp_boss_kiyohime": True, "jp_boss_shutendoji": True,
    "jp_mob_umibozu": True, "jp_mob_yukionna": True, "jp_mob_gashadokuro": True,
    "jp_mob_kasaobake": True, "jp_mob_ittan": True, "jp_mob_jorogumo": True,
    "jp_mob_chochin": True, "jp_boss_orochi": True, "jp_mob_kappa": True,
    "jp_mob_tengu": True, "jp_mob_oni": True, "jp_mob_kitsune_v_silver": True,
    "jp_mob_chochin_v_purple": True, "jp_mob_hitotsume": True, "jp_mob_gaki": True,
    "jp_hero_samurai_v_silver": False,
}


# --------------------------------------------------------------------------- recolor


def _lum(c: tuple) -> float:
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def _ramp(ramp: list, t: float) -> tuple:
    """Cor da rampa (lista de RGB, escuro -> claro) na posicao t em [0, 1], sem misturar cores."""
    i = min(len(ramp) - 1, max(0, int(t * len(ramp))))
    return ramp[i]


# Rampas das receitas (escuro -> claro).
GHOST = [(18, 22, 44), (40, 52, 92), (70, 92, 142), (112, 140, 190), (164, 192, 228), (214, 232, 248),
         (244, 250, 255)]
GHOST_RED = [(70, 18, 40), (150, 34, 62), (226, 74, 96), (255, 150, 160)]
HAG_SKIN = [(40, 30, 40), (78, 62, 70), (116, 98, 102), (152, 136, 132), (190, 176, 164), (224, 214, 200)]
IVORY = [(120, 108, 92), (168, 156, 128), (206, 196, 164), (230, 222, 194), (248, 244, 224)]
INDIGO = [(22, 16, 38), (40, 30, 66), (62, 46, 98)]
VIOLET = [(66, 34, 110), (104, 58, 170), (150, 98, 222), (198, 160, 255)]


def _sat(c: tuple) -> int:
    return max(c[:3]) - min(c[:3])


def recolor_spectral(c: tuple) -> tuple:
    """Masakado: corpo em azul de fantasma pela luminancia; vermelhos viram carmim (o onryo)."""
    lum = _lum(c) / 255.0
    if c[0] > c[1] + 60 and c[0] > c[2] + 40 and _lum(c) < 150:
        return _ramp(GHOST_RED, lum * 1.6)
    return _ramp(GHOST, min(1.0, lum * 1.15 + 0.04))


def recolor_hag(c: tuple) -> tuple:
    """Datsue-ba: pele verde do gaki vira pele cinza de velha; olhos amarelos viram rubros."""
    r, g, b = c[:3]
    if r > 180 and r >= g and b < 100:   # olhos e brilho dourado
        return (255, 92, 96) if g > 190 else (196, 40, 56)
    if g >= r - 15 and b < g - 20:       # pele verde-oliva do gaki
        return _ramp(HAG_SKIN, _lum(c) / 230.0)
    return (r, g, b)


def recolor_ivory_soul(c: tuple) -> tuple:
    """Gashadokuro: ossos marfim, armadura num indigo liso (sem salpico), cordoes e o olho em
    violeta de alma."""
    r, g, b = c[:3]
    lum = _lum(c)
    if b > r + 50:                       # olho azul
        return (232, 200, 255)
    if lum < 40:                         # contorno
        return (16, 10, 26)
    if r > max(g, b) + 40 and lum > 70:  # cordoes e laca vermelha clara
        return _ramp(VIOLET, (lum - 70) / 40.0)
    if lum < 72:                         # placas da armadura e laca escura
        return _ramp(INDIGO, (lum - 50) / 22.0)
    return _ramp(IVORY, (lum - 72) / 145.0)


RECOLOR = {"spectral": recolor_spectral, "hag": recolor_hag, "ivory_soul": recolor_ivory_soul}


def recolor(im: Image.Image, recipe: str) -> Image.Image:
    """Troca cada cor opaca do quadro pela da receita (tabela de cores; alfa igual)."""
    fn = RECOLOR[recipe]
    colors = im.getcolors(maxcolors=1 << 16) or []
    out = im.copy()
    px = out.load()
    table = {col: fn(col) for _n, col in colors if col[3] >= ALPHA_CUT}
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] >= ALPHA_CUT:
                q = table[p]
                px[x, y] = (q[0], q[1], q[2], 255)
    return out


# Fogo de alma (soulfire): cores da base para a ponta e altura maxima da chama (px).
SOUL_FIRE = [(244, 226, 255), (198, 150, 255), (140, 84, 226), (88, 46, 168)]
SOUL_PAD = 12


def soulfire(frames: list[Image.Image]) -> list[Image.Image]:
    """Linguas de fogo violeta subindo do contorno de cima (cabeca, ombros, espada), cada quadro
    com outra altura por coluna (ondas em seno com fase do quadro): deterministico."""
    import math
    out = []
    for i, f in enumerate(frames):
        w, h = f.size
        big = Image.new("RGBA", (w, h + SOUL_PAD), (0, 0, 0, 0))
        big.paste(f, (0, SOUL_PAD))
        a = big.getchannel("A").load()
        px = big.load()
        for x in range(w):
            top = next((y for y in range(big.height) if a[x, y] >= ALPHA_CUT), None)
            if top is None or top > SOUL_PAD + h * 0.55:
                continue
            if (x * 7 + i * 3) % 6 == 0:
                continue                  # falhas entre as linguas
            wave = 4.0 + 3.4 * math.sin(x * 0.83 + i * 2.1) + 2.6 * math.sin(x * 0.29 - i * 1.4)
            tall = max(0, min(SOUL_PAD - 1, round(wave)))
            for k in range(1, tall + 1):
                c = SOUL_FIRE[min(len(SOUL_FIRE) - 1, (k - 1) * len(SOUL_FIRE) // max(1, tall))]
                px[x, top - k] = (c[0], c[1], c[2], 255)
        out.append(big)
    return out

FACE_SIZE = 38
ALPHA_CUT = 128          # limiar de alfa em 50%
DEFAULT_METHOD = "box_pal"
METHODS = ["nearest", "box", "lanczos", "box_pal", "lanczos_pal"]
NATIVE_FROM = 0.9        # fator >= isto vira 1:1 (sem reamostrar)
FEET_BAND = 0.12        # faixa de baixo (fracao da altura) usada para achar o centro dos pes

BG = (88, 112, 86, 255)  # fundo das pranchas (grama apagada, como o chao do jogo)


# --------------------------------------------------------------------------- utilidades


def binarize(im: Image.Image) -> Image.Image:
    """Alfa 0/255 pelo limiar; RGB dos transparentes zerado (arquivo limpo e deterministico)."""
    im = im.convert("RGBA")
    a = im.getchannel("A").point(lambda v: 255 if v >= ALPHA_CUT else 0)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im.convert("RGB"), (0, 0), a)
    out.putalpha(a)
    return out


def palette_of(frames: list[Image.Image]) -> list[tuple[int, int, int]]:
    colors: set[tuple[int, int, int]] = set()
    for f in frames:
        used = f.getcolors(maxcolors=1 << 16) or []
        colors.update(c[:3] for _n, c in used if c[3] >= ALPHA_CUT)
    return sorted(colors)


def palette_image(colors: list[tuple[int, int, int]]) -> Image.Image:
    if len(colors) > 256:
        sys.exit("paleta com mais de 256 cores; use um metodo sem _pal")
    flat: list[int] = []
    for c in colors:
        flat.extend(c)
    # Completa com a 1a cor (repetir 0,0,0 criaria um preto que nao esta no sprite).
    while len(flat) < 768:
        flat.extend(colors[0])
    pal = Image.new("P", (1, 1))
    pal.putpalette(flat)
    return pal


def reduce(im: Image.Image, size: tuple[int, int], method: str,
           pal: Image.Image | None) -> Image.Image:
    """Reduz um quadro RGBA de alfa binario para `size`."""
    if method == "nearest":
        return binarize(im.resize(size, Image.Resampling.NEAREST))
    base, _, quant = method.partition("_")
    resample = {"box": Image.Resampling.BOX, "lanczos": Image.Resampling.LANCZOS}[base]
    # Alfa pre-multiplicado: a cor da borda nao puxa o preto do fundo transparente.
    small = im.convert("RGBa").resize(size, resample).convert("RGBA")
    small = binarize(small)
    if quant == "pal" and pal is not None:
        rgb = small.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
        a = small.getchannel("A")
        small = Image.new("RGBA", size, (0, 0, 0, 0))
        small.paste(rgb, (0, 0), a)
        small.putalpha(a)
    return small


def frame_diff(a: Image.Image, b: Image.Image) -> int:
    d = ImageChops.difference(a, b).convert("L")
    return sum(i * n for i, n in enumerate(d.histogram()))


def load_strip(pack: str, meta: dict, key: str) -> list[Image.Image]:
    m = meta[key]
    sheet = Image.open(os.path.join(pack, "characters", key + ".png")).convert("RGBA")
    cw, ch = int(m["cell"]), int(m["cell_h"])
    if sheet.width != cw * int(m["frames"]) or sheet.height != ch:
        print(f"  aviso: {key} {sheet.size} nao bate com cell {cw}x{ch} x {m['frames']}")
    return [binarize(sheet.crop((i * cw, 0, (i + 1) * cw, ch))) for i in range(int(m["frames"]))]


def union_box(frames: list[Image.Image]) -> tuple[int, int, int, int]:
    boxes = [f.getchannel("A").getbbox() for f in frames]
    boxes = [b for b in boxes if b]
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


def feet_center(frame: Image.Image) -> float:
    box = frame.getchannel("A").getbbox()
    band = max(2, round((box[3] - box[1]) * FEET_BAND))
    strip = frame.getchannel("A").crop((0, box[3] - band, frame.width, box[3]))
    # Soma por coluna via projecao: reduz a faixa para 1 linha com BOX (media) e le os bytes.
    proj = strip.resize((frame.width, 1), Image.Resampling.BOX).tobytes()
    total = sum(proj)
    if total == 0:
        return (box[0] + box[2]) / 2.0
    return sum(x * v for x, v in enumerate(proj)) / total + 0.5


# --------------------------------------------------------------------------- uma saida


def build(pack: str, meta: dict, entry: tuple, method: str) -> dict:
    oid, group, src, target, opts = entry
    method = opts.get("method", method)
    anim = opts.get("anim", "move")
    idle = load_strip(pack, meta, src + "_idle")
    frames: list[Image.Image] = []
    for a in anim.split("+"):
        frames += idle if a == "idle" else load_strip(pack, meta, f"{src}_{a}")
    if opts.get("flip"):
        idle = [f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in idle]
        frames = [f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in frames]
    if opts.get("recolor"):
        idle = [recolor(f, opts["recolor"]) for f in idle]
        frames = [recolor(f, opts["recolor"]) for f in frames]
    # Quadro parado = o mais parecido com o idle[0] (o jogo mostra o quadro 0 quando para):
    # gira a tira para ele vir primeiro, sem mudar a ordem do ciclo.
    if anim != "idle":
        diffs = [frame_diff(f, idle[0]) for f in frames]
        k = diffs.index(min(diffs))
        frames = frames[k:] + frames[:k]
    rest = frames[0]
    rbox = rest.getchannel("A").getbbox()
    rest_h = rbox[3] - rbox[1]
    s = target / rest_h
    # Nunca amplia (a arte do pack e o maximo de detalhe; ampliar 1,1x so duplica colunas soltas)
    # e, perto de 1:1, mantem 1:1: reduzir 0,95x apaga contornos sem ganho de tamanho.
    if s >= NATIVE_FROM and not (opts.get("grow") and s > 1.0):
        s = 1.0
    ux0, uy0, ux1, uy1 = union_box(frames)
    if opts.get("center", "feet") == "feet":
        cx = feet_center(rest)
        half = max(cx - ux0, ux1 - cx)
        x0, x1 = round(cx - half), round(cx + half)
    else:
        x0, x1 = ux0, ux1
    crop = (x0, uy0, x1, uy1)  # uy1 = linha mais baixa de todos os quadros (pes)
    w = max(1, round((x1 - x0) * s))
    h = max(1, round((uy1 - uy0) * s))
    pal = palette_image(palette_of(frames)) if method.endswith("_pal") else None
    out_frames = [reduce(f.crop(crop), (w, h), method, pal) for f in frames]
    if opts.get("soulfire"):
        out_frames = soulfire(out_frames)
        h = out_frames[0].height
    strip = Image.new("RGBA", (w * len(out_frames), h), (0, 0, 0, 0))
    for i, f in enumerate(out_frames):
        strip.paste(f, (i * w, 0))
    face = make_face(rest, rbox, opts.get("face"), method, pal)
    opaque_h = out_frames[0].getchannel("A").getbbox()
    return {
        "id": oid, "group": group, "src": src, "anim": anim, "frame": [w, h],
        "frames": len(out_frames), "fps": int(meta[f"{src}_{anim.split('+')[-1]}"]["fps"]),
        "height": opaque_h[3] - opaque_h[1],
        "faces_left": (not FACES_LEFT.get(src)) if opts.get("flip") else FACES_LEFT.get(src),
        "strip": strip, "first": out_frames[0], "face": face, "scale": s,
        "frames_img": out_frames,
    }


def make_face(rest: Image.Image, rbox: tuple, spec, method: str,
              pal: Image.Image | None) -> Image.Image:
    if spec is None:
        side = max(12, round((rbox[3] - rbox[1]) * 0.4))
        band = rest.getchannel("A").crop((rbox[0], rbox[1], rbox[2], rbox[1] + side))
        proj = band.resize((band.width, 1), Image.Resampling.BOX).tobytes()
        tot = sum(proj) or 1
        cx = sum(x * v for x, v in enumerate(proj)) / tot
        spec = (round(cx - side / 2), 0, side)
    fx, fy, side = spec
    x0, y0 = rbox[0] + fx, rbox[1] + fy
    crop = rest.crop((x0, y0, x0 + side, y0 + side))  # fora do quadro vira transparente
    if side <= FACE_SIZE:
        k = FACE_SIZE // side
        big = crop.resize((side * k, side * k), Image.Resampling.NEAREST)
        out = Image.new("RGBA", (FACE_SIZE, FACE_SIZE), (0, 0, 0, 0))
        out.paste(big, ((FACE_SIZE - big.width) // 2, (FACE_SIZE - big.height) // 2))
        return binarize(out)
    return reduce(crop, (FACE_SIZE, FACE_SIZE), method, pal)


# --------------------------------------------------------------------------- pranchas


def game_path(game: str, res: str) -> str:
    return os.path.join(game, res.replace("res://", "")) if res else ""


def current_look(game: str | None, oid: str, group: str) -> Image.Image | None:
    """Primeiro quadro do sprite atual no jogo, ja na escala em que e desenhado."""
    if not game:
        return None
    try:
        if group == ELITE:
            data = {e["id"]: e for e in json.load(open(os.path.join(game, "data/enemies.json"), encoding="utf-8"))}
            e = data[oid]
            spec = {"path": e["sprite"], "layout": e.get("layout", "dir4"), "frame": e.get("frame", [16, 16])}
            scale = float(e.get("scale", 1.0)) * 1.6  # EnemyManager.ELITE_SCALE
        else:
            data = {b["id"]: b for b in json.load(open(os.path.join(game, "data/bosses.json"), encoding="utf-8"))}
            b = data[oid]
            spec = b["sprite"]
            scale = float(b.get("scale", 1.0))
        sheet = Image.open(game_path(game, spec["path"])).convert("RGBA")
        fw, fh = spec.get("frame", [16, 16])
        if not fw:
            fh = sheet.height
            fw = fh
        img = sheet.crop((0, 0, int(fw), int(fh)))
        if abs(scale - 1.0) > 1e-6:
            img = img.resize((round(fw * scale), round(fh * scale)), Image.Resampling.NEAREST)
        return img
    except (KeyError, OSError, ValueError) as err:
        print(f"  (sem sprite atual para {oid}: {err})")
        return None


def common_enemy(game: str | None) -> Image.Image | None:
    if not game:
        return None
    p = os.path.join(game, "assets/art/actors/enemies/oni_red/SpriteSheet.png")
    return Image.open(p).convert("RGBA").crop((0, 0, 16, 16)) if os.path.exists(p) else None


def x3(im: Image.Image, k: int = 3) -> Image.Image:
    return im.resize((im.width * k, im.height * k), Image.Resampling.NEAREST)


def board(results: list[dict], game: str | None, title: str) -> Image.Image:
    """Uma linha por saida: [1x: comum 16px | nova | atual] [3x nova] [retrato 1x e 3x]."""
    font = ImageFont.load_default()
    oni = common_enemy(game)
    rows = []
    for r in results:
        cur = current_look(game, r["id"], r["group"])
        cells = []
        scene = [im for im in (oni, r["first"], cur) if im is not None]
        sw = sum(im.width for im in scene) + 6 * (len(scene) - 1)
        sh = max(im.height for im in scene)
        sc = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
        x = 0
        for im in scene:  # alinhados pelos pes
            sc.alpha_composite(im, (x, sh - im.height))
            x += im.width + 6
        cells += [sc, x3(r["first"]), r["face"], x3(r["face"])]
        rh = max(c.height for c in cells) + 18
        rw = sum(c.width for c in cells) + 16 * len(cells) + 8
        row = Image.new("RGBA", (rw, rh), BG)
        d = ImageDraw.Draw(row)
        d.text((4, 2), f"{r['id']} <- {r['src']} ({r['anim']}) frame {r['frame'][0]}x{r['frame'][1]}"
               f" x{r['frames']}  h={r['height']}  {'olha esq.' if r['faces_left'] else 'olha dir.'}",
               fill=(255, 255, 255, 255), font=font)
        x = 8
        for c in cells:
            row.alpha_composite(c, (x, rh - c.height - 2))
            x += c.width + 16
        rows.append(row)
    W = max(r.width for r in rows)
    H = sum(r.height + 2 for r in rows) + 20
    out = Image.new("RGBA", (W, H), (40, 44, 40, 255))
    ImageDraw.Draw(out).text((4, 4), title + "  (1x: oni comum 16px | novo | atual no jogo; 3x novo;"
                             " retrato 1x e 3x)", fill=(255, 255, 255, 255), font=font)
    y = 20
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.height + 2
    return out


def anim_sheet(results: list[dict]) -> Image.Image:
    rows = [x3(r["strip"]) for r in results]
    W = max(r.width for r in rows) + 8
    H = sum(r.height + 8 for r in rows)
    out = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(out)
    y = 0
    for r, img in zip(results, rows):
        out.alpha_composite(img, (4, y + 4))
        fw = r["frame"][0] * 3
        for i in range(1, r["frames"]):  # divisorias dos quadros
            d.line([(4 + i * fw, y + 4), (4 + i * fw, y + 4 + img.height)], fill=(255, 80, 80, 255))
        y += img.height + 8
    return out


def methods_sheet(pack: str, meta: dict, entries: list[tuple]) -> Image.Image:
    font = ImageFont.load_default()
    tiles = []
    for e in entries:
        row = []
        for mth in METHODS:
            r = build(pack, meta, e, mth)
            t = x3(r["first"])
            cell = Image.new("RGBA", (t.width + 8, t.height + 16), BG)
            ImageDraw.Draw(cell).text((2, 1), mth, fill=(255, 255, 255, 255), font=font)
            cell.alpha_composite(t, (4, 14))
            row.append(cell)
        tiles.append(row)
    W = max(sum(c.width for c in row) for row in tiles)
    H = sum(max(c.height for c in row) for row in tiles)
    out = Image.new("RGBA", (W, H), (40, 44, 40, 255))
    y = 0
    for row in tiles:
        x = 0
        for c in row:
            out.alpha_composite(c, (x, y))
            x += c.width
        y += max(c.height for c in row)
    return out


# --------------------------------------------------------------------------- jogo


def update_index(paths: list[str]) -> None:
    """Troca no assets/asset_index.json as linhas destes arquivos (origem e SHA-256)."""
    index_path = os.path.join(ROOT, "assets", "asset_index.json")
    index = json.load(open(index_path, encoding="utf-8"))
    rows = []
    for p in paths:
        rel = os.path.relpath(p, ROOT).replace(os.sep, "/")
        with open(p, "rb") as f:
            digest = hashlib.sha256(f.read()).hexdigest()
        rows.append({"file": rel, "source": "tools/import_sengoku.py", "license_id": LICENSE_ID,
                     "sha256": digest})
    names = {r["file"] for r in rows}
    index = sorted([row for row in index if row["file"] not in names] + rows, key=lambda row: row["file"])
    with open(index_path, "w", encoding="utf-8") as f:
        f.write(json.dumps(index, indent=1, ensure_ascii=False))


# --------------------------------------------------------------------------- main


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack", required=True)
    ap.add_argument("--out", default="", help="pasta de saida (sem ela, grava no jogo)")
    ap.add_argument("--game", default=None, help="raiz do Hyakki (so leitura) para comparar")
    ap.add_argument("--method", default=DEFAULT_METHOD, choices=METHODS)
    ap.add_argument("--only", default="", help="ids separados por virgula")
    ap.add_argument("--preview", default="")
    ap.add_argument("--anim", default="", help="ids para preview_anim.png")
    ap.add_argument("--methods-sheet", default="", help="png comparando os metodos")
    args = ap.parse_args()

    meta = json.load(open(os.path.join(args.pack, "pack.json"), encoding="utf-8"))["characters"]
    only = set(filter(None, args.only.split(",")))
    entries = [e for e in TABLE if not only or e[0] in only]
    results = []
    print(f"{'id':18s} {'origem':26s} {'anim':6s} {'frame':>9s} {'quadros':>7s} {'altura':>6s} faces_left")
    written: list[str] = []
    for e in entries:
        r = build(args.pack, meta, e, args.method)
        d = os.path.join(args.out, r["id"]) if args.out else             os.path.join(ROOT, DEST[r["group"]], GUARD_DIR.get(r["id"], r["id"]))
        os.makedirs(d, exist_ok=True)
        r["strip"].save(os.path.join(d, "Idle.png"), optimize=True)
        written.append(os.path.join(d, "Idle.png"))
        if args.out or r["group"] != ELITE:
            r["face"].save(os.path.join(d, "Faceset.png"), optimize=True)
            written.append(os.path.join(d, "Faceset.png"))
        results.append(r)
        print(f"{r['id']:18s} {r['src']:26s} {r['anim']:6s} {r['frame'][0]:>4d}x{r['frame'][1]:<4d}"
              f" {r['frames']:>7d} {r['height']:>6d} {r['faces_left']}")
    if not args.out:
        update_index(written)
    if args.preview:
        base, ext = os.path.splitext(args.preview)
        pages = {}
        for g in (BOSS, GUARD, ELITE):
            sel = [r for r in results if r["group"] == g]
            if sel:
                pages[g] = board(sel, args.game, g)
                pages[g].save(f"{base}_{g}{ext}")
        allp = list(pages.values())
        W = max(p.width for p in allp)
        full = Image.new("RGBA", (W, sum(p.height for p in allp)), (40, 44, 40, 255))
        y = 0
        for p in allp:
            full.alpha_composite(p, (0, y))
            y += p.height
        full.save(args.preview)
    if args.anim:
        ids = args.anim.split(",")
        sel = [r for i in ids for r in results if r["id"] == i]
        anim_sheet(sel).save(os.path.join(os.path.dirname(args.preview) or ".", "preview_anim.png"))
    if args.methods_sheet:
        pick = [e for e in TABLE if e[0] in ("red_oni", "tengu_crow", "kitsune_nine", "hyakume")]
        methods_sheet(args.pack, meta, pick).save(args.methods_sheet)


if __name__ == "__main__":
    main()
