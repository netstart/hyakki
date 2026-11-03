"""Gera os efeitos sonoros procedurais das habilidades dos guardiões (prefixo a_) em
assets/audio/sfx/.

Obra original do projeto Hyakki, liberada em CC0-1.0 (entrada `hyakki_ability_sfx` em
licenses/registry.json). Só biblioteca padrão e sementes fixas: rodar de novo produz os
mesmos bytes. Usa os blocos de tools/gen_sfx.py (osciladores, filtro de estado variável,
sinos, estalos, finalização) e grava WAV PCM 16 bits, mono, 44,1 kHz, normalizado sem
clipping, com fade de entrada e saída. Cada grupo vira um grupo de AudioManager.VARIANTS e
entra em camadas nos cues "ab_<id>" de WeaponSfx.

- a_dash: avanço de luz (Passo da Aurora): sopro rápido e rastro de brilho;
- a_light_ring: anel de luz (Muralha da Lanterna): brilho que sobe e zumbido quente;
- a_fire_column: coluna de fogo (Chama de Cem Anos): estouro grave, rugido de chama e brasas;
- a_caltrops: estrepes de ferro caindo e quicando no chão (Chuva de Makibishi);
- a_barrier: barreira sagrada (Kekkai): acorde de sinos com tremolo e zumbido;
- a_seal: selo de papel (Selo da Avó): tapas de ofuda e a trava do selo com brilho;
- a_diamond: Corpo de Diamante: cristais agudos e um "dong" grave de bronze;
- a_shakujo: Golpe do Shakujō: o cajado bate no chão e as argolas de metal tilintam;
- a_mantra: pulso do Mantra do Mestre: tigela tibetana (com batimento) e zumbido grave;
- a_holy_arrow: Hamaya: flecha sagrada com assobio de kaburaya (flecha que canta);
- a_trap: armadilha de caça fechando: mola, duas mandíbulas de ferro e um baque de madeira;
- a_anvil: martelo na bigorna: estalo de aço, anel inarmônico da bigorna e baque grave;
- a_chain_spin: corrente girando 360° (dois giros com efeito Doppler) e elos tilintando;
- a_steam: Têmpera: chiado do aço na água, sopro de vapor e estalos;
- a_claw: Garra Oni: três rasgos de garra;
- a_oni_roar: rugido oni: garganta grave com aspereza (dobra de período) e formantes;
- a_whirl: Redemoinho Onikiri: lâmina girando (sopro modulado pela rotação) e anel de aço;
- a_denied: recusa curta (sem energia): dois toques abafados descendo;
- a_ready: habilidade pronta de novo: um "plim" discreto.

Também atualiza só as linhas a_* de assets/asset_index.json (hash e origem).
Depois rode o import do Godot para criar os .import.
Uso: python -I tools/gen_ability_sfx.py
"""
import hashlib
import importlib.util
import json
import math
import pathlib
import random
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio" / "sfx"
LICENSE_ID = "hyakki_ability_sfx"
PREFIX = "a_"
BASE_SEED = 7213


def _gen_sfx():
    spec = importlib.util.spec_from_file_location("hyakki_gen_sfx", ROOT / "tools" / "gen_sfx.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


G = _gen_sfx()
SR, TAU = G.SR, G.TAU
ns, zeros, noise, mix, mul, scale = G.ns, G.zeros, G.noise, G.mix, G.mul, G.scale
exp_env, sweep, osc, lp, hp, bp = G.exp_env, G.sweep, G.osc, G.lp, G.hp, G.bp
crackle, place, bell, tone_env, finish, write_wav = (G.crackle, G.place, G.bell, G.tone_env,
                                                     G.finish, G.write_wav)
metal_clink = G.metal_clink


# --- Blocos próprios -----------------------------------------------------------------

def partials(base: float, seconds: float, spec, rng, start: float = 0.0) -> list:
    """Soma de parciais (razão, amplitude, queda em s) com fase aleatória; começa em `start`."""
    n = ns(seconds)
    out = [0.0] * n
    i0 = ns(start)
    for ratio, amp, decay in spec:
        f = base * ratio
        if f >= SR * 0.45:
            continue
        ph = rng.uniform(0, TAU)
        w = TAU * f / SR
        k = math.exp(-1.0 / (decay * SR))
        e = amp
        for i in range(i0, n):
            out[i] += e * math.sin(w * (i - i0) + ph)
            e *= k
    return out


def thud(seconds: float, f_hi: float, f_lo: float, decay: float) -> list:
    """Baque grave: senoide que cai de tom com queda exponencial."""
    n = ns(seconds)
    return mul(osc(sweep(f_hi, f_lo, n)), exp_env(seconds, decay, 0.001))


def burst(rng, seconds: float, lo: float, hi: float, decay: float, attack: float = 0.001) -> list:
    """Rajada de ruído em banda com queda exponencial (estalos, tapas, chiados)."""
    return mul(lp(hp(noise(rng, seconds), lo), hi), exp_env(seconds, decay, attack))


def rough_throat(rng, seconds: float, f0: float, f0_end: float) -> list:
    """Garganta de fera: dente de serra grave com jitter forte e dobra de período (aspereza),
    filtrado por formantes de vogal aberta."""
    n = ns(seconds)
    out = []
    p = 0.0
    wander = 0.0
    half = 0
    for i in range(n):
        frac = i / max(1, n - 1)
        wander = 0.995 * wander + 0.005 * rng.uniform(-1, 1)
        f = (f0 + (f0_end - f0) * frac) * (1 + 3.0 * wander)
        p += f / SR
        if p >= 1.0:
            p -= 1.0
            half ^= 1
        amp = 1.0 if half else 0.55  # dobra de período: um ciclo forte, outro fraco
        out.append((2.0 * p - 1.0) * amp * rng.uniform(0.85, 1.0))
    breath = scale(noise(rng, seconds), 0.25)
    src = mix((out, 1.0), (breath, 1.0))
    return mix((bp(src, 420.0, 3.0), 1.0), (bp(src, 950.0, 3.5), 0.7), (bp(src, 2300.0, 4.0), 0.35),
               (lp(src, 260.0), 0.5))


def amp_follow(x: list, shape) -> list:
    return [s * shape(i / SR) for i, s in enumerate(x)]


# --- Receitas (rng, v) -> (sinal cru, pico alvo) --------------------------------------

def dash(rng, v):
    """Passo da Aurora: sopro de ar curto e rápido e um rastro de brilhos que some."""
    dur = 0.5
    n = ns(dur)
    peak_t = 0.07 + 0.01 * v
    air = mul(bp(noise(rng, dur), sweep(900.0, 4200.0 + 400 * v, n), 1.4),
              tone_env(dur, lambda t: math.exp(-((t - peak_t) / 0.045) ** 2)))
    shimmer = zeros(dur)
    for k in range(9):
        at = 0.05 + k * 0.035
        place(shimmer, bell(rng.choice((2637.0, 3136.0, 3520.0, 4186.0)) * (1 + 0.01 * v), 0.25, 0.05, 0.5),
              at, 0.18 * math.exp(-k / 4.0))
    return mix((air, 1.6), (shimmer, 0.6)), 0.7


def light_ring(rng, v):
    """Muralha da Lanterna: arpejo de sinos que sobe, brilho de ar que se abre e zumbido quente."""
    dur = 1.1
    n = ns(dur)
    out = zeros(dur)
    notes = (523.25, 659.25, 783.99, 1046.5, 1318.5) if v == 0 else (587.33, 739.99, 880.0, 1174.66, 1480.0)
    for i, f in enumerate(notes):
        place(out, bell(f, 0.9, 0.35, 0.45), 0.02 + 0.055 * i, 0.22)
    swell = mul(bp(noise(rng, dur), sweep(500.0, 6000.0, n), 1.2),
                tone_env(dur, lambda t: math.sin(math.pi * min(t / 0.7, 1.0)) ** 2))
    hum = mul(mix((osc([130.81 * (1 + 0.5 * v / 12)] * n), 1.0), (osc([261.63] * n), 0.4)),
              tone_env(dur, lambda t: min(1.0, t / 0.15) * math.exp(-max(0.0, t - 0.3) / 0.35)))
    return mix((out, 1.0), (swell, 0.35), (hum, 0.25)), 0.72


def fire_column(rng, v):
    """Chama de Cem Anos: estouro grave, coluna de fogo que ruge (filtro que abre e fecha) e
    estalos de brasa."""
    dur = 1.3
    n = ns(dur)
    boom = thud(dur, 110.0 - 10 * v, 35.0, 0.22)
    roar_env = tone_env(dur, lambda t: min(1.0, t / 0.03) * math.exp(-t / (0.45 + 0.05 * v)))
    cut = [300.0 + 3800.0 * math.exp(-((i / SR - 0.12) / 0.25) ** 2) for i in range(n)]
    roar = mul(lp(noise(rng, dur), cut, 0.9), roar_env)
    flutter = [0.7 + 0.3 * math.sin(TAU * (14.0 + 3.0 * rng.random()) * i / SR) for i in range(n)]
    embers = mul(hp(crackle(rng, dur, 120.0, 0.8), 1500.0), tone_env(dur, lambda t: math.exp(-t / 0.6)))
    return mix((boom, 0.9), (mul(roar, flutter), 1.5), (embers, 0.6)), 0.9


def caltrops(rng, v):
    """Chuva de Makibishi: estrepes de ferro caindo (cada uma quica 2-3 vezes) e o chiado do
    arremesso."""
    dur = 0.9
    out = zeros(dur)
    count = 14 + 2 * v
    for k in range(count):
        at = 0.04 + 0.32 * (k / count) ** 1.4 + rng.uniform(0, 0.03)
        base = rng.uniform(2300.0, 4200.0)
        g = rng.uniform(0.35, 0.8)
        for bounce in range(rng.randint(2, 3)):
            place(out, metal_clink(rng, base * rng.uniform(0.98, 1.02), 0.05), at, g)
            at += 0.045 * (0.6 ** bounce) + rng.uniform(0.0, 0.01)
            g *= 0.45
    toss = mul(bp(noise(rng, dur), sweep(2500.0, 1200.0, ns(dur)), 1.5),
               tone_env(dur, lambda t: min(1.0, t / 0.01) * math.exp(-t / 0.06)))
    return mix((out, 0.8), (toss, 0.5)), 0.62


def barrier(rng, v):
    """Kekkai: acorde de sinos com tremolo (luz que pulsa), zumbido grave e o sopro do selo."""
    dur = 1.2
    n = ns(dur)
    chord = (392.0, 587.33, 783.99, 1174.66) if v == 0 else (440.0, 659.25, 880.0, 1318.5)
    pad = [0.0] * n
    for j, f in enumerate(chord):
        for detune in (1.0, 1.004):
            w = TAU * f * detune / SR
            ph = rng.uniform(0, TAU)
            for i in range(n):
                pad[i] += math.sin(w * i + ph) / (1 + j)
    trem = tone_env(dur, lambda t: (0.75 + 0.25 * math.sin(TAU * 6.0 * t)) * min(1.0, t / 0.12)
                    * math.exp(-max(0.0, t - 0.25) / 0.45))
    strike = zeros(dur)
    for i, f in enumerate(chord):
        place(strike, bell(f * 2, 0.8, 0.3, 0.4), 0.0 + 0.02 * i, 0.25)
    hum = mul(osc([98.0] * n), tone_env(dur, lambda t: min(1.0, t / 0.1) * math.exp(-t / 0.6)))
    seal = burst(rng, dur, 600.0, 5000.0, 0.05)
    return mix((mul(pad, trem), 0.3), (strike, 0.8), (hum, 0.35), (seal, 0.35)), 0.7


def seal(rng, v):
    """Selo da Avó: cinco tapas de papel (ofuda grudando), a trava do selo (estalo grave de
    madeira) e brilho de sino."""
    dur = 1.0
    out = zeros(dur)
    for k in range(5):
        slap = burst(rng, 0.08, 900.0, 6000.0, 0.012)
        place(out, slap, 0.02 + k * (0.055 + 0.005 * v), rng.uniform(0.5, 0.8))
    lock_at = 0.32
    place(out, thud(0.4, 180.0, 70.0, 0.08), lock_at, 1.2)
    place(out, burst(rng, 0.1, 300.0, 2500.0, 0.02), lock_at, 0.9)
    for i, f in enumerate((1046.5, 1567.98, 2093.0)):
        place(out, bell(f * (1 + 0.06 * v), 0.6, 0.18, 0.5), lock_at + 0.03 * i, 0.3)
    return out, 0.8


def diamond(rng, v):
    """Corpo de Diamante: "dong" grave de bronze e cristais agudos que brilham em cascata."""
    dur = 1.1
    out = zeros(dur)
    dong = partials(146.83 * (1 + 0.06 * v), dur, ((1.0, 1.0, 0.5), (2.0, 0.4, 0.35), (2.76, 0.5, 0.25),
                                                    (4.07, 0.25, 0.15), (5.4, 0.15, 0.1)), rng)
    out = mix((out, 1.0), (dong, 0.6))
    for k in range(12):
        f = rng.choice((3136.0, 3729.3, 4186.0, 4698.6, 5274.0))
        place(out, bell(f, 0.35, 0.08, 0.6), 0.03 + k * 0.045 + rng.uniform(0, 0.02), 0.12 * math.exp(-k / 7.0))
    return out, 0.72


def shakujo(rng, v):
    """Golpe do Shakujō: o cajado bate no chão (baque e estalo de madeira) e as seis argolas
    de ferro chacoalham e tilintam, em duas sacudidas."""
    dur = 1.0
    out = zeros(dur)
    place(out, thud(0.5, 130.0, 55.0, 0.09), 0.0, 1.3)
    place(out, burst(rng, 0.06, 1200.0, 7000.0, 0.008), 0.0, 0.8)
    ring_bases = [rng.uniform(1400.0, 2600.0) for _ in range(6)]
    for shake, (t0, g) in enumerate(((0.005, 1.0), (0.16 + 0.02 * v, 0.55))):
        for k, base in enumerate(ring_bases):
            for hit in range(2):
                at = t0 + rng.uniform(0.0, 0.07) + hit * rng.uniform(0.02, 0.05)
                ring = partials(base, 0.6, ((1.0, 1.0, 0.18), (2.32, 0.6, 0.11), (3.71, 0.4, 0.07),
                                            (5.12, 0.25, 0.04)), rng)
                place(out, ring, at, g * rng.uniform(0.12, 0.2) * (0.6 if hit else 1.0))
    return out, 0.82


def mantra(rng, v):
    """Pulso do Mantra: tigela tibetana tocada (parciais com batimento lento) e zumbido grave."""
    dur = 1.1
    n = ns(dur)
    base = (220.0, 207.65, 233.08)[v]
    bowl = partials(base, dur, ((1.0, 1.0, 0.7), (1.006, 0.8, 0.7), (2.71, 0.6, 0.45), (2.725, 0.4, 0.45),
                                (5.15, 0.3, 0.25), (8.43, 0.12, 0.12)), rng)
    hum = mul(mix((osc([base / 2] * n), 1.0), (osc([base] * n), 0.3)),
              tone_env(dur, lambda t: min(1.0, t / 0.05) * math.exp(-t / 0.45)))
    knock = burst(rng, 0.05, 200.0, 2000.0, 0.01)
    return mix((bowl, 0.5), (hum, 0.6), (knock, 0.3)), 0.75


def holy_arrow(rng, v):
    """Hamaya: flecha sagrada com assobio de kaburaya (tom que cai com o Doppler), sopro e um
    toque de sino na saída."""
    dur = 0.7
    n = ns(dur)
    f0 = 1700.0 + 150.0 * v
    whistle = mul(osc(sweep(f0 * 1.06, f0 * 0.82, n)),
                  tone_env(dur, lambda t: min(1.0, t / 0.03) * math.exp(-max(0.0, t - 0.1) / 0.22)))
    whistle2 = mul(osc(sweep(f0 * 2.12, f0 * 1.64, n)), tone_env(dur, lambda t: min(1.0, t / 0.03) * math.exp(-t / 0.15)))
    air = mul(bp(noise(rng, dur), sweep(f0, f0 * 0.8, n), 4.0),
              tone_env(dur, lambda t: min(1.0, t / 0.02) * math.exp(-t / 0.25)))
    out = mix((whistle, 0.35), (whistle2, 0.08), (air, 1.4))
    place(out, bell(2637.0, 0.5, 0.12, 0.4), 0.0, 0.2)
    return out, 0.62


def trap(rng, v):
    """Armadilha de caça: mola (zunido curto), duas mandíbulas de ferro batendo e o baque da
    base de madeira."""
    dur = 0.45
    out = zeros(dur)
    spring = mul(osc(sweep(900.0, 1500.0, ns(0.04))), exp_env(0.04, 0.015))
    place(out, spring, 0.0, 0.3)
    for k, at in enumerate((0.03, 0.045 + 0.005 * v)):
        jaw = partials(rng.uniform(1700.0, 2300.0), 0.3, ((1.0, 1.0, 0.05), (2.41, 0.7, 0.035),
                                                           (3.9, 0.5, 0.02), (6.2, 0.3, 0.012)), rng)
        place(out, jaw, at, 0.5)
        place(out, burst(rng, 0.03, 2000.0, 9000.0, 0.004), at, 0.9)
    place(out, thud(0.2, 160.0, 80.0, 0.04), 0.035, 0.9)
    return out, 0.82


def anvil(rng, v):
    """Martelo na bigorna: estalo do aço, anel inarmônico longo da bigorna e o baque grave."""
    dur = 1.3
    base = (980.0, 1060.0, 905.0)[v]
    ring = partials(base, dur, ((1.0, 1.0, 0.55), (1.58, 0.7, 0.4), (2.31, 0.55, 0.3), (2.97, 0.4, 0.22),
                                (4.12, 0.3, 0.14), (5.6, 0.2, 0.08)), rng)
    click = burst(rng, 0.03, 3000.0, 12000.0, 0.003)
    body = thud(0.4, 140.0, 60.0, 0.07)
    out = mix((ring, 0.35), (body, 1.0))
    place(out, click, 0.0, 1.2)
    return out, 0.88


def chain_spin(rng, v):
    """Corrente Puxadora: corrente girando 360° (sopro que vem e vai, com Doppler, dois giros) e
    os elos tilintando no ritmo do giro."""
    dur = 0.95
    n = ns(dur)
    turns = 2.0
    rate = turns / 0.8

    def pan(t):
        return 0.5 + 0.5 * math.cos(TAU * rate * t)

    cut = [900.0 + 2600.0 * pan(i / SR) for i in range(n)]
    whoosh = mul(bp(noise(rng, dur), cut, 1.6),
                 tone_env(dur, lambda t: (0.25 + 0.75 * pan(t)) * min(1.0, t / 0.05) * math.exp(-max(0.0, t - 0.6) / 0.12)))
    links = zeros(dur)
    t = 0.02
    while t < 0.8:
        g = 0.2 + 0.8 * pan(t)
        place(links, metal_clink(rng, rng.uniform(2200.0, 3600.0) * (0.95 + 0.1 * pan(t)), 0.05), t,
              g * rng.uniform(0.15, 0.3))
        t += rng.uniform(0.012, 0.03)
    return mix((whoosh, 1.5), (links, 0.8)), 0.72


def steam(rng, v):
    """Têmpera: o aço em brasa na água (chiado agudo que estala), o sopro do vapor subindo e um
    estouro abafado."""
    dur = 1.4
    n = ns(dur)
    pop = mix((thud(0.5, 90.0, 40.0, 0.12), 1.0), (burst(rng, 0.5, 80.0, 900.0, 0.08), 1.2))
    sizzle = mul(hp(crackle(rng, dur, 900.0 + 100 * v, 0.4), 2500.0),
                 tone_env(dur, lambda t: min(1.0, t / 0.02) * math.exp(-t / 0.5)))
    hiss = mul(bp(noise(rng, dur), sweep(7000.0, 2500.0, n), 0.9),
               tone_env(dur, lambda t: min(1.0, t / 0.04) * math.exp(-t / (0.45 + 0.05 * v))))
    puff = mul(lp(noise(rng, dur), sweep(3000.0, 400.0, n), 0.8),
               tone_env(dur, lambda t: min(1.0, t / 0.03) * math.exp(-t / 0.3)))
    out = zeros(dur)
    place(out, pop, 0.0, 0.9)
    return mix((out, 1.0), (sizzle, 0.5), (hiss, 1.0), (puff, 0.8)), 0.86


def claw(rng, v):
    """Garra Oni: três rasgos de garra (ar cortado que desce de tom, com aspereza de rasgo)."""
    dur = 0.5
    out = zeros(dur)
    for k in range(3):
        seg = 0.11
        m = ns(seg)
        rip = mul(bp(noise(rng, seg), sweep(5200.0 - 500 * k, 1300.0, m), 1.8),
                  tone_env(seg, lambda t: min(1.0, t / 0.008) * math.exp(-t / 0.03)))
        tear = mul(hp(crackle(rng, seg, 700.0, 0.3), 1800.0), exp_env(seg, 0.025))
        place(out, mix((rip, 1.4), (tear, 0.5)), 0.01 + k * (0.085 + 0.01 * v), 1.0 - 0.12 * k)
    place(out, thud(0.2, 120.0, 60.0, 0.04), 0.0, 0.4)
    return out, 0.78


def oni_roar(rng, v):
    """Rugido Oni: garganta grave e áspera que cresce e cai, com estrondo no começo."""
    dur = 1.3
    throat = rough_throat(rng, dur, 78.0 - 6 * v, 52.0 - 4 * v)
    throat = amp_follow(throat, lambda t: min(1.0, t / 0.12) * (1.0 if t < 0.55 else math.exp(-(t - 0.55) / 0.25)))
    boom = thud(0.6, 70.0, 30.0, 0.18)
    air = mul(bp(noise(rng, dur), 1800.0, 0.8), tone_env(dur, lambda t: min(1.0, t / 0.1) * math.exp(-t / 0.5)))
    return mix((throat, 1.0), (boom, 0.8), (air, 0.15)), 0.9


def whirl(rng, v):
    """Redemoinho Onikiri: a lâmina girando (sopro pulsando a cada passagem, ~6 por s) por 1,4 s
    e o anel do aço por baixo."""
    dur = 1.5
    n = ns(dur)
    rate = 6.0 + 0.5 * v
    env = tone_env(dur, lambda t: min(1.0, t / 0.08) * (1.0 if t < 1.2 else math.exp(-(t - 1.2) / 0.08)))
    am = [0.15 + 0.85 * abs(math.sin(math.pi * rate * i / SR)) ** 4 for i in range(n)]
    cut = [1200.0 + 2400.0 * a for a in am]
    swish = mul(mul(bp(noise(rng, dur), cut, 1.5), am), env)
    ring = mul(partials(620.0 + 40 * v, dur, ((1.0, 1.0, 2.0), (2.41, 0.4, 1.5), (3.93, 0.2, 1.0)), rng), env)
    sub = mul(osc([55.0] * n), mul(am, env))
    return mix((swish, 1.6), (ring, 0.08), (sub, 0.25)), 0.75


def denied(rng, v):
    """Sem energia: dois toques abafados e graves descendo (bloco de madeira com feltro)."""
    dur = 0.3
    out = zeros(dur)
    for k, f in enumerate((330.0, 247.0)):
        tone = mix((partials(f, 0.12, ((1.0, 1.0, 0.04), (2.0, 0.3, 0.02), (3.0, 0.1, 0.012)), rng), 1.0),
                   (burst(rng, 0.12, 200.0, 1500.0, 0.006), 0.2))
        place(out, lp(tone, 1800.0), 0.005 + 0.11 * k, 1.0)
    return out, 0.6


def ready(rng, v):
    """Habilidade pronta: um "plim" de sino pequeno e suave, com um harmônico brilhando."""
    dur = 0.6
    out = zeros(dur)
    place(out, bell(1567.98, 0.55, 0.12, 0.3), 0.0, 1.0)
    place(out, bell(2349.32, 0.45, 0.08, 0.2), 0.03, 0.35)
    return out, 0.5


RECIPES = {
    "dash": dash,
    "light_ring": light_ring,
    "fire_column": fire_column,
    "caltrops": caltrops,
    "barrier": barrier,
    "seal": seal,
    "diamond": diamond,
    "shakujo": shakujo,
    "mantra": mantra,
    "holy_arrow": holy_arrow,
    "trap": trap,
    "anvil": anvil,
    "chain_spin": chain_spin,
    "steam": steam,
    "claw": claw,
    "oni_roar": oni_roar,
    "whirl": whirl,
    "denied": denied,
    "ready": ready,
}
## Variações por grupo (o padrão é 2); sons únicos e discretos têm 1.
VARIATIONS = {"shakujo": 3, "caltrops": 3, "mantra": 3, "anvil": 3, "claw": 3, "denied": 1, "ready": 1}


def seed_for(name: str, v: int) -> int:
    return BASE_SEED + int(hashlib.sha256(f"{name}_{v}".encode()).hexdigest()[:8], 16)


def update_index(written: list) -> None:
    path = ROOT / "assets" / "asset_index.json"
    index = json.loads(path.read_text(encoding="utf-8"))
    index = [row for row in index if row.get("license_id") != LICENSE_ID
             or not row["file"].startswith("assets/audio/sfx/")]
    for file in written:
        index.append({
            "file": file.relative_to(ROOT).as_posix(),
            "source": "tools/gen_ability_sfx.py",
            "license_id": LICENSE_ID,
            "sha256": hashlib.sha256(file.read_bytes()).hexdigest(),
        })
    index.sort(key=lambda item: item["file"])
    path.write_text(json.dumps(index, indent=1, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for name, fn in RECIPES.items():
        for v in range(VARIATIONS.get(name, 2)):
            raw, peak = fn(random.Random(seed_for(name, v)), v)
            x = finish(raw, peak)
            path = OUT / f"{PREFIX}{name}_{v}.wav"
            write_wav(path, x)
            written.append(path)
            print(f"{path.relative_to(ROOT).as_posix()}  {len(x) / SR:.3f} s  pico {max(abs(s) for s in x):.2f}")
    update_index(written)
    print(f"{len(written)} arquivos gerados")
    return 0


if __name__ == "__main__":
    sys.exit(main())
