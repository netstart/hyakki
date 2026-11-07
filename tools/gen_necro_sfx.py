"""Gera os efeitos sonoros procedurais da Kuon (a Shinobi dos Mortos) e do mapa Osorezan
(prefixo nc_) em assets/audio/sfx/.

Obra original do projeto Hyakki, liberada em CC0-1.0 (entrada `hyakki_necro_sfx` em
licenses/registry.json). Só biblioteca padrão e sementes fixas: rodar de novo produz os
mesmos bytes. Usa os blocos de tools/gen_sfx.py (osciladores, filtro de estado variável,
sinos, estalos, finalização) e de tools/gen_altar_sfx.py (reverb de Schroeder, parciais com
batimento, golpe grave, corte da cauda) e grava WAV PCM 16 bits, mono, 44,1 kHz, normalizado
sem clipping com pico em PEAK_DB (padrão -3 dBFS).

Sabor fúnebre japonês: orin (tigela de bronze do altar budista), suzu (guizos), argolas do
shakujō, taiko grave, vento soprado, coro de fantasmas (vozes em dente-de-serra por formantes
de vogal "u/o"), estalos de osso, ofuda de papel e a água do Sanzu.

- nc_fuda_throw_0..2: ofuda lançada (papel batendo, sopro e um tique de suzu);
- nc_fuda_hit_0..2: ofuda colando no alvo (tapa de papel, estalo de selo violeta);
- nc_raise: alma subindo e virando servo (sopro que sobe, coro curto e orin);
- nc_minion_hit_0..2: golpe do servo espectral (corte fantasma abafado);
- nc_minion_fade: servo se desfazendo (coro descendo e virando ar);
- nc_bone_orbit: ossos girando em volta (giro com Doppler e estalos de osso);
- nc_bone_crack_0..1: osso quebrando;
- nc_sanzu_wave: onda do rio Sanzu atravessando (água larga, borbulhas, coro grave);
- nc_ferry_bell: sino da balsa do barqueiro (sino grande com batimento e água);
- nc_legion_march: o Exército de Yomi marchando (taiko em marcha, passos, argolas, coro);
- nc_soul_pickup_0..2: alma recolhida (plim suave de orin agudo e sopro);
- nc_harvest: Tamashii-gari (almas puxadas: redemoinho de vento e coro que converge);
- nc_bone_wall: Kotsu-heki (lanças de osso irrompendo do chão em anel);
- nc_yomigaeri: Yomigaeri (grande ressurreição: inchaço do coro, orin e sino);
- nc_rite: ultimate (procissão ao contrário: taiko, coro, suzu e orin em acorde);
- nc_gasha_roar: rugido da Gashadokuro (garganta oca de ossos e vento);
- nc_gasha_slam: mão da Gashadokuro batendo no chão;
- nc_gasha_rise: a Gashadokuro se erguendo (ossos se juntando e ronco que sobe);
- nc_datsueba_cackle: Datsue-ba (risada seca e sussurrada da velha, sem graça cômica);
- nc_masakado_cry: grito do Masakado no Onryō (brado de guerreiro com eco fantasma);
- nc_kazaguruma: cata-ventos girando no vento (ambiente, um disparo);
- nc_kuon_freed: Kuon libertada (carrilhão que resolve, orin e brilho).

update_index() só roda com --update-index (atualiza as linhas desta licença em
assets/asset_index.json com hash e origem). Depois rode o import do Godot.
Uso: python -I tools/gen_necro_sfx.py [--out <pasta>] [--root <repo>] [--update-index]
"""
import argparse
import hashlib
import importlib.util
import json
import math
import pathlib
import random
import sys

sys.dont_write_bytecode = True  # não deixa .pyc dos geradores irmãos em tools/__pycache__

ROOT = pathlib.Path(__file__).resolve().parent.parent
LICENSE_ID = "hyakki_necro_sfx"
PREFIX = "nc_"
BASE_SEED = 4471
PEAK_DB = -3.0


def _load(name: str, file: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _parse_root() -> None:
    # --root antes de carregar os módulos irmãos (para rodar fora do repositório).
    global ROOT
    if "--root" in sys.argv:
        ROOT = pathlib.Path(sys.argv[sys.argv.index("--root") + 1]).resolve()


_parse_root()
G = _load("hyakki_gen_sfx", "gen_sfx.py")
A = _load("hyakki_gen_altar_sfx", "gen_altar_sfx.py")
SR, TAU = G.SR, G.TAU
ns, zeros, noise, mix, mul, scale = G.ns, G.zeros, G.noise, G.mix, G.mul, G.scale
exp_env, sweep, osc, lp, hp, bp = G.exp_env, G.sweep, G.osc, G.lp, G.hp, G.bp
crackle, place, tone_env, finish, write_wav = G.crackle, G.place, G.tone_env, G.finish, G.write_wav
bell, metal_clink = G.bell, G.metal_clink
reverb, partials, boom, trim_tail = A.reverb, A.partials, A.boom, A.trim_tail


# --- Blocos próprios ---------------------------------------------------------------------

def orin(freq: float, seconds: float, bright: float = 1.0) -> list:
    """Orin (tigela do altar budista): fundamental longa com batimento lento, parciais da
    tigela (2,71 e 5,15) e um sub; mais escuro que o rin do altar."""
    table = ((1.0, 1.0, 1.8, 1.1), (2.71, 0.42 * bright, 1.0, 1.9), (5.15, 0.2 * bright, 0.5, 2.7),
             (8.1, 0.08 * bright, 0.25, 0.0), (0.5, 0.1, 0.9, 0.0))
    return partials(seconds, freq, table, 0.0015)


def mallet(rng, gain: float = 1.0) -> list:
    """Batida da baqueta de madeira na tigela."""
    tick = mul(hp(noise(rng, 0.025), 2200.0), exp_env(0.025, 0.004, 0.0003))
    knock = boom(0.05, 380.0, 280.0, 0.012, 0.0005)
    return mix((tick, 0.35 * gain), (knock, 0.25 * gain))


def suzu_shake(rng, seconds: float, hits: int, gain: float = 1.0, low: bool = False) -> list:
    """Guizos de santuário chacoalhados (pequenos sinos com bolinha)."""
    out = zeros(seconds)
    notes = (1975.5, 2349.3, 2637.0, 3136.0) if low else (2637.0, 3136.0, 3520.0, 3951.0, 4699.0)
    for k in range(hits):
        at = 0.01 + k * (seconds * 0.6 / max(1, hits)) + rng.uniform(0, 0.012)
        for _ in range(2):
            b = bell(rng.choice(notes) * rng.uniform(0.99, 1.01), min(0.3, seconds - at), 0.06, 0.5)
            place(out, b, at + rng.uniform(0, 0.008), gain * rng.uniform(0.25, 0.5) * math.exp(-k / 5.0))
    return out


def shakujo_rings(rng, seconds: float, hits: int, base: float = 1650.0) -> list:
    """Argolas de ferro do shakujō batendo umas nas outras."""
    out = zeros(seconds)
    for k in range(hits):
        at = 0.005 + k * rng.uniform(0.025, 0.05)
        if at >= seconds - 0.05:
            break
        place(out, metal_clink(rng, base * rng.uniform(0.85, 1.2), 0.12), at, rng.uniform(0.4, 0.9) * 0.85 ** k)
    return out


def taiko(rng, f0: float = 100.0, decay: float = 0.28, rim: bool = False) -> list:
    """Taiko: pele (ruído curto), corpo grave com a altura caindo e o barril."""
    dur = decay * 3.2
    body = boom(dur, f0, f0 * 0.46, decay, 0.002)
    shell = boom(dur * 0.6, f0 * 2.1, f0 * 1.3, decay * 0.3, 0.001)
    skin = mul(lp(noise(rng, 0.07), 2000.0), exp_env(0.07, 0.018, 0.0005))
    out = mix((body, 1.3), (shell, 0.25), (skin, 0.6))
    if rim:
        ka = mul(bp(noise(rng, 0.04), 2600.0, 3.0), exp_env(0.04, 0.008, 0.0003))
        place(out, ka, 0.0, 0.4)
    return out


def bone_clack(rng, base: float = 1900.0, gain: float = 1.0) -> list:
    """Estalo de osso: batida seca em banda com duas ressonâncias ocas curtas."""
    dur = 0.07
    hit = mul(bp(noise(rng, dur), base, 2.5), exp_env(dur, 0.008, 0.0002))
    body = partials(dur, base * 0.42, ((1.0, 1.0, 0.012, 0.0), (2.31, 0.6, 0.008, 0.0), (3.9, 0.3, 0.005, 0.0)),
                    0.0003)
    return scale(mix((hit, 1.4), (body, 0.6)), gain)


def ghost_choir(rng, seconds: float, f0, vowel: str = "u", voices: int = 4, vib: float = 5.0,
                breath: float = 0.25) -> list:
    """Coro de fantasmas: vozes em dente-de-serra levemente desafinadas, com vibrato lento,
    por formantes de vogal (u, o, a) e ar soprado. f0 pode ser número ou lista por amostra."""
    n = ns(seconds)
    base = f0 if isinstance(f0, list) else [f0] * n
    src = [0.0] * n
    for k in range(voices):
        det = 1.0 + (k - (voices - 1) / 2.0) * 0.006 + rng.uniform(-0.002, 0.002)
        fv = vib * rng.uniform(0.85, 1.15)
        p0 = rng.uniform(0.0, TAU)
        octave = 2.0 if k % 3 == 2 else 1.0
        freqs = [base[i] * det * octave * (1.0 + 0.011 * math.sin(TAU * fv * i / SR + p0)) for i in range(n)]
        saw = osc(freqs, "saw", p0)
        for i in range(n):
            src[i] += saw[i] * (0.6 if octave > 1.0 else 1.0)
    air = noise(rng, seconds)
    form = {"u": ((320.0, 5.0, 1.3), (800.0, 6.0, 0.5), (2400.0, 8.0, 0.12)),
            "o": ((450.0, 5.0, 1.3), (800.0, 6.0, 0.7), (2600.0, 8.0, 0.15)),
            "a": ((720.0, 4.0, 1.2), (1150.0, 5.0, 0.8), (2600.0, 6.0, 0.25))}[vowel]
    out = [0.0] * n
    for f, q, g in form:
        y = bp(src, f, q)
        for i in range(n):
            out[i] += y[i] * g
    wind = bp(air, form[0][0] * 1.8, 1.4)
    return [o * 0.35 + w * breath for o, w in zip(out, wind)]


def wind(rng, seconds: float, lo: float, hi: float, q: float = 1.2, gusts: int = 3) -> list:
    """Vento soprado: ruído em banda com o centro passeando e rajadas lentas."""
    n = ns(seconds)
    ph = [rng.uniform(0, TAU) for _ in range(3)]
    center = [lo + (hi - lo) * (0.5 + 0.5 * math.sin(TAU * 0.6 * i / SR + ph[0]) * math.sin(TAU * 0.23 * i / SR + ph[1]))
              for i in range(n)]
    x = bp(noise(rng, seconds), center, q)
    swell = [0.6 + 0.4 * math.sin(TAU * (gusts / seconds) * 0.5 * i / SR + ph[2]) for i in range(n)]
    return mul(x, swell)


def water(rng, seconds: float, density: float, lo: float = 300.0, hi: float = 1400.0) -> list:
    """Água: corpo de ruído grave e borbulhas (senos curtos que sobem)."""
    out = lp(noise(rng, seconds), 650.0, 0.6)
    out = scale(out, 0.5)
    for _ in range(int(density * seconds)):
        at = rng.uniform(0.0, seconds - 0.05)
        f = rng.uniform(lo, hi)
        d = rng.uniform(0.012, 0.035)
        m = ns(d * 3)
        blip = mul(osc(sweep(f, f * rng.uniform(1.4, 2.2), m)), exp_env(d * 3, d, 0.001))
        place(out, blip, at, rng.uniform(0.05, 0.18))
    return out


def paper_flap(rng, seconds: float, rate: float, center: float = 2400.0) -> list:
    """Papel batendo no ar: ruído em banda com batidas irregulares."""
    n = ns(seconds)
    env, p = [], 0.0
    for i in range(n):
        t = i / SR
        p += (rate + 6.0 * math.sin(TAU * 3.0 * t)) / SR
        env.append(max(0.0, math.sin(TAU * p)) ** 3)
    cen = [center + 400.0 * math.sin(TAU * 7.0 * i / SR) for i in range(n)]
    return mul(bp(noise(rng, seconds), cen, 1.2), env)


def env_ar(seconds: float, attack: float, release: float, curve: float = 2.0) -> list:
    """Envelope de ataque e soltura em seno ao quadrado (sobe e desce suave)."""
    def shape(t):
        if t < attack:
            return math.sin(0.5 * math.pi * t / attack) ** curve
        r = (t - attack) / max(1e-6, seconds - attack)
        return max(0.0, 1.0 - r) ** release
    return tone_env(seconds, shape)


# --- Receitas: (rng, v) -> (sinal cru, pico relativo 0..1) ---------------------------------

def fuda_throw(rng, v):
    dur = 0.42
    n = ns(dur)
    out = scale(mul(paper_flap(rng, dur, 34.0 + 5 * v, 2600.0 + 200 * v),
                    tone_env(dur, lambda t: math.sin(math.pi * min(t / (dur * 0.8), 1.0)) ** 1.4)), 1.2)
    whoosh = mul(bp(noise(rng, dur), sweep(700.0, 3200.0 + 300 * v, n), 1.4),
                 tone_env(dur, lambda t: math.sin(math.pi * min(t / dur, 1.0)) ** 2))
    out = mix((out, 1.0), (whoosh, 0.7))
    place(out, bell((2349.3, 2637.0, 2093.0)[v], 0.3, 0.06, 0.35), 0.03, 0.12)
    # Sussurro violeta: um "hm" grave muito leve por baixo.
    hm = mul(ghost_choir(rng, 0.3, 196.0 * (1 + 0.06 * v), "u", 2, 6.0, 0.1), env_ar(0.3, 0.06, 1.5))
    place(out, hm, 0.02, 0.35)
    return reverb(out, 0.15, room=0.6, damp=0.5, wet=0.2), 1.0


def fuda_hit(rng, v):
    dur = 0.36
    out = zeros(dur)
    slap = mul(bp(noise(rng, 0.05), 2200.0 + 300 * v, 1.1), exp_env(0.05, 0.009, 0.0003))
    place(out, slap, 0.0, 1.2)
    place(out, boom(0.12, 240.0, 120.0, 0.03, 0.0008), 0.0, 0.7)
    # Selo travando: dois tons inarmônicos descendo, cor violeta.
    seal = partials(0.3, (622.3, 587.3, 659.3)[v], ((1.0, 1.0, 0.09, 3.0), (2.41, 0.45, 0.05, 0.0),
                                                     (3.77, 0.2, 0.03, 0.0)), 0.001)
    place(out, seal, 0.008, 0.45)
    place(out, hp(crackle(rng, 0.12, 220, 0.5), 2600.0), 0.005, 0.25)
    return reverb(out, 0.12, room=0.6, damp=0.5, wet=0.22), 1.0


def raise_minion(rng, v):
    dur = 1.05
    n = ns(dur)
    out = zeros(dur)
    # Sopro que sobe do chão.
    rise = mul(bp(noise(rng, 0.7), sweep(260.0, 2600.0, ns(0.7)), 1.6), env_ar(0.7, 0.55, 2.0))
    place(out, rise, 0.0, 0.9)
    # Coro curto que sobe uma quarta e assenta.
    f = [233.1 * (1.0 + 0.335 * min(1.0, (i / SR) / 0.45) ** 1.5) for i in range(ns(0.85))]
    ch = mul(ghost_choir(rng, 0.85, f, "o", 4, 5.0, 0.2), env_ar(0.85, 0.4, 1.6))
    place(out, ch, 0.12, 0.8)
    # Orin no fim (a alma tomando corpo).
    place(out, orin(932.3, 0.55), 0.5, 0.35)
    place(out, mallet(rng, 0.6), 0.5)
    place(out, suzu_shake(rng, 0.35, 3, 0.6), 0.52, 0.5)
    return reverb(out, 0.45, room=0.82, damp=0.45, wet=0.38), 1.0


def minion_hit(rng, v):
    dur = 0.28
    n = ns(dur)
    swish = mul(bp(noise(rng, 0.14), sweep(3200.0, 900.0, ns(0.14)), 1.8), env_ar(0.14, 0.03, 1.4))
    out = zeros(dur)
    place(out, swish, 0.0, 0.9)
    thump = mul(lp(noise(rng, 0.12), 700.0), exp_env(0.12, 0.025, 0.001))
    place(out, thump, 0.06, 1.1)
    place(out, boom(0.15, 150.0 + 20 * v, 70.0, 0.04, 0.001), 0.06, 0.8)
    # Eco fantasma: a mesma batida em formante "u", mais longe.
    ghost = mul(ghost_choir(rng, 0.16, 300.0 + 30 * v, "u", 2, 7.0, 0.05), exp_env(0.16, 0.05, 0.004))
    place(out, ghost, 0.07, 0.4)
    return reverb(out, 0.12, room=0.6, damp=0.5, wet=0.25), 1.0


def minion_fade(rng, v):
    dur = 0.8
    n = ns(dur)
    f = sweep(311.1, 155.6, n)
    ch = mul(ghost_choir(rng, dur, f, "u", 3, 4.0, 0.45), env_ar(dur, 0.06, 1.8))
    air = mul(hp(noise(rng, dur), 3500.0), tone_env(dur, lambda t: math.exp(-t / 0.35) * min(1.0, t / 0.05)))
    out = mix((ch, 1.0), (air, 0.12))
    place(out, bell(1864.7, 0.4, 0.1, 0.3), 0.0, 0.08)
    return reverb(out, 0.4, room=0.82, damp=0.4, wet=0.4), 1.0


def bone_orbit(rng, v):
    dur = 1.0
    n = ns(dur)
    rot = 2.5  # giros por segundo
    # Sopro de giro com Doppler: centro e volume seguem a rotação.
    cen = [1100.0 * (1.0 + 0.35 * math.sin(TAU * rot * i / SR)) for i in range(n)]
    amp = [0.5 + 0.5 * math.sin(TAU * rot * i / SR) ** 2 for i in range(n)]
    whirl = mul(bp(noise(rng, dur), cen, 2.2), amp)
    e = env_ar(dur, 0.12, 1.0, 1.0)
    out = mul(whirl, e)
    # Estalos de osso batendo uns nos outros, mais fortes perto (pico do giro).
    t = 0.04
    while t < dur - 0.08:
        g = 0.4 + 0.6 * math.sin(TAU * rot * t) ** 2
        place(out, bone_clack(rng, rng.uniform(1500.0, 2600.0)), t, 0.5 * g * e[ns(t)])
        t += rng.uniform(0.05, 0.11)
    return reverb(out, 0.15, room=0.6, damp=0.5, wet=0.18), 1.0


def bone_crack(rng, v):
    dur = 0.4
    out = zeros(dur)
    place(out, bone_clack(rng, 2300.0 + 400 * v, 1.0), 0.0, 1.3)
    # Lascas: estalos curtos espalhados e o "crec" fibroso.
    for k in range(5 + v):
        place(out, bone_clack(rng, rng.uniform(2400.0, 4200.0)), 0.01 + rng.uniform(0, 0.12), rng.uniform(0.2, 0.5))
    fib = mul(hp(crackle(rng, 0.15, 900, 0.4), 1800.0), exp_env(0.15, 0.04))
    place(out, fib, 0.005, 0.6)
    place(out, boom(0.12, 180.0, 90.0, 0.03, 0.0005), 0.0, 0.5)
    return reverb(out, 0.12, room=0.6, damp=0.55, wet=0.2), 1.0


def sanzu_wave(rng, v):
    dur = 1.6
    n = ns(dur)
    # Onda larga: ruído com o corte abrindo e fechando (a crista passando).
    body = lp(noise(rng, dur), [300.0 + 2200.0 * math.sin(math.pi * min(1.0, i / n)) ** 2 for i in range(n)], 0.7)
    wave_e = tone_env(dur, lambda t: math.sin(math.pi * min(1.0, t / dur)) ** 1.5)
    out = scale(mul(body, wave_e), 1.4)
    out = mix((out, 1.0), (mul(water(rng, dur, 45.0), wave_e), 0.9))
    # Espuma: ruído agudo no pico da crista.
    foam = mul(hp(noise(rng, dur), 4500.0), tone_env(dur, lambda t: math.exp(-((t - 0.75) / 0.25) ** 2)))
    out = mix((out, 1.0), (foam, 0.3))
    # Coro grave das almas do rio por baixo.
    ch = mul(ghost_choir(rng, dur, 110.0, "o", 3, 3.5, 0.15), wave_e)
    out = mix((out, 1.0), (ch, 0.35))
    return reverb(out, 0.4, room=0.8, damp=0.5, wet=0.3), 1.0


def ferry_bell(rng, v):
    dur = 2.4
    out = zeros(dur)
    # Sino de bronze grande (bonshō pequeno): parciais inarmônicas com batimento e golpe.
    big = partials(dur, 196.0, ((1.0, 1.0, 1.6, 0.9), (2.0, 0.5, 1.2, 1.4), (2.66, 0.45, 0.9, 1.9),
                                (3.86, 0.3, 0.6, 0.0), (5.2, 0.2, 0.4, 2.6), (0.5, 0.35, 1.8, 0.0)), 0.003)
    place(out, big, 0.0, 1.0)
    place(out, boom(0.3, 160.0, 110.0, 0.06, 0.001), 0.0, 0.5)
    place(out, mul(lp(noise(rng, 0.05), 1600.0), exp_env(0.05, 0.01, 0.0005)), 0.0, 0.5)
    # Água batendo no casco.
    place(out, mul(water(rng, 1.8, 18.0, 250.0, 900.0), env_ar(1.8, 0.3, 1.5)), 0.2, 0.35)
    return reverb(out, 0.6, room=0.86, damp=0.45, wet=0.3), 1.0


def legion_march(rng, v):
    dur = 2.4
    out = zeros(dur)
    beat = 0.36
    t, k = 0.0, 0
    while t < dur - 0.4:
        acc = 1.0 if k % 2 == 0 else 0.7
        place(out, taiko(rng, 92.0 if k % 2 == 0 else 110.0, 0.22, rim=(k % 4 == 3)), t, acc)
        # Passos de muitos pés: ruído grave curto espalhado.
        for _ in range(6):
            st = mul(lp(noise(rng, 0.05), 500.0), exp_env(0.05, 0.012, 0.002))
            place(out, st, t + rng.uniform(0.0, 0.05), 0.25)
        place(out, shakujo_rings(rng, 0.2, 3, 1500.0), t + 0.01, 0.12)
        t += beat
        k += 1
    n = ns(dur)
    march_e = env_ar(dur, 0.6, 1.2, 1.0)
    ch = mul(ghost_choir(rng, dur, [98.0 if (i / SR) % (beat * 4) < beat * 2 else 110.0 for i in range(n)],
                         "o", 5, 4.0, 0.2), march_e)
    out = mix((out, 1.0), (ch, 0.5))
    return reverb(out, 0.4, room=0.8, damp=0.5, wet=0.25), 1.0


def soul_pickup(rng, v):
    dur = 0.45
    out = zeros(dur)
    f = (1567.98, 1760.0, 1975.53)[v]
    place(out, orin(f, 0.42, 0.6), 0.0, 0.5)
    place(out, bell(f * 1.5, 0.3, 0.07, 0.3), 0.04, 0.18)
    puff = mul(bp(noise(rng, 0.2), sweep(1500.0, 4000.0, ns(0.2)), 1.5), env_ar(0.2, 0.05, 2.0))
    place(out, puff, 0.0, 0.25)
    return reverb(out, 0.2, room=0.7, damp=0.4, wet=0.3), 1.0


def harvest(rng, v):
    dur = 1.3
    n = ns(dur)
    # Redemoinho de vento que fecha (centro subindo, rotação acelerando).
    rot = [3.0 + 9.0 * (i / n) ** 1.5 for i in range(n)]
    ph, cen = 0.0, []
    for i in range(n):
        ph += rot[i] / SR
        cen.append(700.0 + 1800.0 * (i / n) + 500.0 * math.sin(TAU * ph))
    vortex = mul(bp(noise(rng, dur), cen, 1.8), env_ar(dur, 0.9, 3.0, 1.2))
    # Coro que converge para o uníssono (desafinação diminuindo).
    ch = zeros(dur)
    for k, ratio in enumerate((1.0, 1.26, 1.5, 0.75)):
        f = [196.0 * (ratio + (1.0 - ratio) * min(1.0, i / (n * 0.85)) ** 2) for i in range(n)]
        place(ch, ghost_choir(rng, dur, f, "u", 2, 5.0, 0.1), 0.0, 0.6)
    ch = mul(ch, env_ar(dur, 0.8, 2.5, 1.5))
    out = mix((vortex, 1.0), (ch, 0.8))
    # Almas chegando: plins rápidos que se adensam.
    for k in range(10):
        at = 0.25 + 0.75 * (1.0 - (1.0 - k / 10.0) ** 1.6)
        place(out, bell(rng.choice((1567.98, 1864.66, 2093.0, 2349.3)), 0.25, 0.05, 0.3), at, 0.1)
    # Puxão final: golpe grave.
    place(out, boom(0.4, 130.0, 50.0, 0.12, 0.003), 1.02, 0.9)
    return reverb(out, 0.4, room=0.8, damp=0.45, wet=0.3), 1.0


def bone_wall(rng, v):
    dur = 1.2
    out = zeros(dur)
    # Terra rachando por baixo.
    rumble = lp(noise(rng, 0.35), sweep(200.0, 900.0, ns(0.35)), 0.8)
    place(out, mul(rumble, env_ar(0.35, 0.3, 1.0)), 0.0, 1.0)
    # Lanças irrompendo em anel: estalos de osso em sequência rápida e golpes.
    for k in range(10):
        at = 0.25 + k * 0.028 + rng.uniform(0, 0.01)
        place(out, bone_clack(rng, rng.uniform(1400.0, 2400.0)), at, 0.8)
        spike = mul(bp(noise(rng, 0.08), sweep(900.0, 3500.0, ns(0.08)), 2.0), exp_env(0.08, 0.02, 0.002))
        place(out, spike, at, 0.5)
    place(out, boom(0.6, 120.0, 40.0, 0.18, 0.002), 0.25, 1.2)
    place(out, mul(lp(noise(rng, 0.5), sweep(2500.0, 200.0, ns(0.5)), 0.8), exp_env(0.5, 0.1, 0.002)), 0.25, 1.0)
    # Assentamento: estalos de ossos se travando.
    for k in range(5):
        place(out, bone_clack(rng, rng.uniform(1800.0, 3000.0)), 0.6 + k * rng.uniform(0.04, 0.08), 0.25)
    return reverb(out, 0.3, room=0.75, damp=0.5, wet=0.25), 1.0


def yomigaeri(rng, v):
    dur = 2.6
    n = ns(dur)
    out = zeros(dur)
    # Inchaço do coro: sobe de nada até um acorde maior aberto e resolve.
    swell = env_ar(dur, 1.3, 1.6, 2.0)
    for f, g in ((130.8, 1.0), (196.0, 0.8), (261.6, 0.6), (329.6, 0.45)):
        place(out, mul(ghost_choir(rng, dur, f, "a" if f > 200 else "o", 3, 4.5, 0.1), swell), 0.0, g * 0.6)
    # Sopro que sobe (portal se abrindo).
    up = mul(bp(noise(rng, 1.4), sweep(200.0, 5000.0, ns(1.4)), 1.3), env_ar(1.4, 1.3, 3.0))
    place(out, up, 0.0, 0.8)
    # No ápice: orin grande, sino e suzu.
    at = 1.3
    place(out, orin(523.25, 1.3), at, 0.6)
    place(out, orin(783.99, 1.2, 0.7), at + 0.02, 0.35)
    place(out, mallet(rng), at)
    place(out, suzu_shake(rng, 0.9, 7, 0.8), at + 0.01, 0.6)
    place(out, boom(0.7, 90.0, 40.0, 0.25, 0.004), at, 1.0)
    return reverb(out, 0.6, room=0.86, damp=0.4, wet=0.35), 1.0


def rite(rng, v):
    dur = 3.0
    out = zeros(dur)
    # Procissão ao contrário: taiko em três golpes, coro em uníssono, suzu e orin em acorde.
    for k, (t, f) in enumerate(((0.0, 88.0), (0.32, 88.0), (0.64, 70.0))):
        place(out, taiko(rng, f, 0.32 if k == 2 else 0.2, rim=(k == 1)), t, 1.0 if k == 2 else 0.75)
    n = ns(dur - 0.6)
    f = [110.0 * (1.0 + 0.5 * min(1.0, (i / SR) / 0.5) ** 2) for i in range(n)]
    ch = mul(ghost_choir(rng, dur - 0.6, f, "o", 6, 4.5, 0.15), env_ar(dur - 0.6, 0.5, 1.3, 1.5))
    place(out, ch, 0.6, 0.9)
    place(out, mul(wind(rng, dur - 0.5, 400.0, 2600.0, 1.0, 3), env_ar(dur - 0.5, 0.6, 1.0)), 0.5, 0.6)
    for k, fr in enumerate((493.88, 587.33, 739.99)):
        place(out, orin(fr, 1.9, 0.8), 0.66 + 0.06 * k, 0.32)
    place(out, mallet(rng), 0.66)
    place(out, suzu_shake(rng, 1.6, 10, 0.7), 0.7, 0.55)
    place(out, shakujo_rings(rng, 0.6, 7), 0.68, 0.25)
    return reverb(out, 0.6, room=0.86, damp=0.45, wet=0.32), 1.0


def hollow_throat(rng, seconds: float, base: float, rise: float = 0.3) -> list:
    """Garganta oca de caveira: dente-de-serra grave com jitter e dobra de período, por
    formantes de vogal fechada, com sopro ressoando no crânio."""
    n = ns(seconds)
    jitter = lp(noise(rng, seconds), 12.0)
    f = []
    for i in range(n):
        k = i / n
        contour = 1.0 + rise * math.sin(math.pi * min(1.0, k * 1.5)) - 0.2 * max(0.0, k - 0.65)
        f.append(base * contour * (1.0 + 0.9 * jitter[i]))
    t1 = osc(f, "saw")
    t2 = osc([x * 0.5 for x in f], "square")
    raw = mix((t1, 1.0), (t2, 0.35), (noise(rng, seconds), 0.35))
    voiced = mix((bp(raw, 380.0, 3.5), 1.5), (bp(raw, 900.0, 4.0), 0.6), (lp(raw, 220.0), 0.8))
    hollow = bp(noise(rng, seconds), 520.0, 6.0)
    return mix((voiced, 1.0), (hollow, 0.5))


def gasha_roar(rng, v):
    dur = 2.2
    x = hollow_throat(rng, dur, 46.0, 0.4)
    e = tone_env(dur, lambda t: min(1.0, t / 0.18) * (1.0 if t < 1.3 else math.exp(-(t - 1.3) / 0.35)))
    x = mul(x, e)
    gust = mul(wind(rng, dur, 300.0, 1400.0, 1.5, 2), e)
    x = mix((x, 1.0), (gust, 0.6))
    # Ossos chacoalhando com o rugido.
    t = 0.15
    while t < 1.5:
        place(x, bone_clack(rng, rng.uniform(1300.0, 2400.0)), t, 0.18)
        t += rng.uniform(0.04, 0.09)
    return reverb(x, 0.6, room=0.85, damp=0.5, wet=0.3), 1.0


def gasha_slam(rng, v):
    dur = 1.6
    out = zeros(dur)
    place(out, mul(bp(noise(rng, 0.25), sweep(400.0, 1600.0, ns(0.25)), 1.2), env_ar(0.25, 0.24, 1.0)), 0.0, 0.5)
    hit = 0.24
    place(out, boom(1.1, 75.0, 26.0, 0.35, 0.002), hit, 1.6)
    place(out, mul(noise(rng, 0.05), exp_env(0.05, 0.01, 0.0002)), hit, 0.9)
    body = lp(noise(rng, 0.9), sweep(2200.0, 120.0, ns(0.9)), 0.8)
    place(out, mul(body, exp_env(0.9, 0.18, 0.002)), hit, 1.6)
    for k in range(14):
        place(out, bone_clack(rng, rng.uniform(1400.0, 3200.0)), hit + 0.01 + rng.uniform(0, 0.25), 0.35)
    debris = hp(crackle(rng, 0.8, 300, 1.0), 1200.0)
    place(out, mul(debris, exp_env(0.8, 0.25)), hit + 0.04, 0.4)
    return reverb(out, 0.5, room=0.82, damp=0.5, wet=0.25), 1.0


def gasha_rise(rng, v):
    dur = 2.8
    out = zeros(dur)
    # Ossos se juntando: estalos que aceleram e se adensam.
    t, k = 0.05, 0
    while t < 1.9:
        g = 0.2 + 0.6 * t / 1.9
        place(out, bone_clack(rng, rng.uniform(1200.0, 3000.0)), t, g)
        k += 1
        t += max(0.018, 0.16 * 0.93 ** k)
    # Ronco que sobe.
    rn = ns(2.0)
    rum = lp(noise(rng, 2.0), sweep(80.0, 700.0, rn), 0.9)
    place(out, mul(rum, tone_env(2.0, lambda t: (t / 2.0) ** 1.6)), 0.0, 3.0)
    riser = mul(lp(osc(sweep(40.0, 120.0, rn), "saw"), 500.0), tone_env(2.0, lambda t: (t / 2.0) ** 2.0))
    place(out, riser, 0.0, 0.5)
    # Golpe ao ficar de pé e um suspiro oco.
    place(out, boom(0.8, 90.0, 30.0, 0.28, 0.002), 2.0, 1.4)
    sigh = mul(hollow_throat(rng, 0.75, 40.0, 0.15), env_ar(0.75, 0.1, 1.5))
    place(out, sigh, 2.02, 0.5)
    return reverb(out, 0.5, room=0.84, damp=0.5, wet=0.28), 1.0


def datsueba_cackle(rng, v):
    """Risada da velha: sílabas secas "he-he-he" sussurradas, com voz rachada (fry) e uma
    altura que cai, numa sala de pedra. Sem tom cômico: lenta, baixa e áspera."""
    dur = 1.7
    out = zeros(dur)
    syll = 6
    for k in range(syll):
        at = 0.04 + k * (0.16 + 0.012 * k)
        sd = 0.12
        n = ns(sd)
        f0 = 260.0 * (1.0 - 0.05 * k) * rng.uniform(0.97, 1.03)
        # Fonte rachada: pulsos irregulares (fry) + ar.
        fry = []
        p = 0.0
        for i in range(n):
            p += f0 * (1.0 + 0.08 * rng.uniform(-1, 1)) / SR
            fry.append(1.0 if (p % 1.0) < 0.12 else 0.0)
        breath = noise(rng, sd)
        src = [0.7 * a + 0.6 * b for a, b in zip(fry, breath)]
        # Vogal "e" (450/1900/2600) fechando para "i".
        vow = mix((bp(src, 470.0, 5.0), 1.0), (bp(src, sweep(1900.0, 2300.0, n), 6.0), 0.8),
                  (bp(src, 2700.0, 7.0), 0.4), (hp(breath, 3000.0), 0.25))
        e = tone_env(sd, lambda t: min(1.0, t / 0.012) * math.exp(-t / 0.05))
        # "h" aspirado antes de cada sílaba.
        hh = mul(bp(noise(rng, 0.04), 2400.0, 1.0), tone_env(0.04, lambda t: math.sin(math.pi * t / 0.04)))
        place(out, hh, max(0.0, at - 0.03), 0.25)
        place(out, mul(vow, e), at, 1.0 * (1.0 - 0.08 * k))
    # Sopro longo de garganta no fim (o "hhh" que fica).
    tail = mul(bp(noise(rng, 0.6), 1600.0, 1.2), env_ar(0.6, 0.1, 2.0))
    place(out, tail, 1.05, 0.3)
    return reverb(out, 0.5, room=0.8, damp=0.55, wet=0.32), 1.0


def masakado_cry(rng, v):
    dur = 1.9
    n = ns(dur)
    jitter = lp(noise(rng, dur), 10.0)
    f = []
    for i in range(n):
        t = i / SR
        c = 150.0 * (1.0 + 0.25 * min(1.0, t / 0.12)) * (1.0 - 0.18 * max(0.0, t - 0.7) / 1.2)
        f.append(c * (1.0 + 0.5 * jitter[i] + 0.015 * math.sin(TAU * 5.5 * t)))
    src = mix((osc(f, "saw"), 1.0), (osc([x * 0.5 for x in f], "saw"), 0.3), (noise(rng, dur), 0.25))
    # Brado "oo-aa": formantes abrindo.
    f1 = [450.0 + 300.0 * min(1.0, (i / SR) / 0.3) for i in range(n)]
    voice = mix((bp(src, f1, 4.0), 1.3), (bp(src, 1150.0, 5.0), 0.6), (bp(src, 2500.0, 6.0), 0.25),
                (lp(src, 250.0), 0.5))
    grit = mul(bp(noise(rng, dur), 1800.0, 1.4), [0.5 + 0.5 * math.sin(TAU * 27.0 * i / SR) for i in range(n)])
    x = mix((voice, 1.0), (grit, 0.3))
    e = tone_env(dur, lambda t: min(1.0, t / 0.06) * (1.0 if t < 0.85 else math.exp(-(t - 0.85) / 0.25)))
    x = mul(x, e)
    # Eco fantasma: a voz uma oitava acima, atrasada e soprada.
    ghost = mul(ghost_choir(rng, dur, [x2 * 2.0 for x2 in f], "u", 2, 4.0, 0.3), e)
    out = zeros(dur + 0.3)
    place(out, x, 0.0, 1.0)
    place(out, ghost, 0.18, 0.25)
    place(out, shakujo_rings(rng, 0.3, 3, 1200.0), 0.02, 0.15)  # armadura tilintando
    return reverb(out, 0.6, room=0.86, damp=0.5, wet=0.33), 1.0


def kazaguruma(rng, v):
    dur = 3.0
    n = ns(dur)
    # Vento de montanha.
    w = mul(wind(rng, dur, 350.0, 1700.0, 1.0, 2), env_ar(dur, 0.8, 1.2, 1.5))
    # Cata-ventos girando: tique-tique de cata-vento de papel/plástico, a rotação segue a rajada.
    gust = [0.4 + 0.6 * math.sin(math.pi * min(1.0, i / n)) ** 1.5 for i in range(n)]
    out = scale(w, 0.9)
    for wheel in range(3):
        rate0 = 9.0 + 4.0 * wheel
        ph = rng.uniform(0, 1)
        last = 0
        base = rng.uniform(2600.0, 4200.0)
        for i in range(0, n, 32):
            ph += rate0 * gust[i] * 32 / SR
            if int(ph) != last:
                last = int(ph)
                tick = mul(bp(noise(rng, 0.012), base, 4.0), exp_env(0.012, 0.0025, 0.0002))
                place(out, tick, i / SR, 0.18 * gust[i] * (0.6 + 0.4 * rng.random()))
        # Zumbido do eixo (whir).
        hum = mul(bp(noise(rng, dur), 900.0 + 300 * wheel, 6.0), gust)
        out = mix((out, 1.0), (hum, 0.12))
    # Um sino de vento (fūrin) distante, uma vez.
    place(out, bell(2793.8, 1.0, 0.35, 0.4), 1.2, 0.05)
    return reverb(out, 0.3, room=0.7, damp=0.5, wet=0.25), 1.0


def kuon_freed(rng, v):
    dur = 3.0
    out = zeros(dur)
    # Carrilhão que resolve: suspensão (sus4) -> maior, em orins e sinos, com coro claro.
    sus = (587.33, 783.99, 880.0)    # ré-sol-lá
    res = (587.33, 739.99, 880.0)    # ré-fá#-lá
    for k, f in enumerate(sus):
        place(out, bell(f, 0.9, 0.35, 0.4), 0.0 + 0.09 * k, 0.4)
    for k, f in enumerate(res + (1174.66,)):
        place(out, orin(f, 2.2, 0.8), 0.75 + 0.08 * k, 0.28)
    place(out, mallet(rng, 0.7), 0.75)
    ch = mul(ghost_choir(rng, 2.0, 293.66, "a", 4, 4.0, 0.08), env_ar(2.0, 0.5, 1.4, 1.5))
    place(out, ch, 0.7, 0.35)
    ch2 = mul(ghost_choir(rng, 2.0, 440.0, "a", 3, 4.4, 0.05), env_ar(2.0, 0.6, 1.4, 1.5))
    place(out, ch2, 0.72, 0.2)
    # Brilho: arpejo agudo caindo como luz.
    for k, f in enumerate((2349.3, 2217.5, 1760.0, 1480.0, 1174.66)):
        place(out, bell(f, 0.6, 0.15, 0.3), 1.2 + 0.11 * k, 0.1)
    place(out, suzu_shake(rng, 1.0, 5, 0.5), 0.78, 0.3)
    return reverb(out, 0.7, room=0.88, damp=0.4, wet=0.36), 1.0


# nome -> (função, variações); variação única sem sufixo de índice.
RECIPES = {
    "fuda_throw": (fuda_throw, 3),
    "fuda_hit": (fuda_hit, 3),
    "raise": (raise_minion, 1),
    "minion_hit": (minion_hit, 3),
    "minion_fade": (minion_fade, 1),
    "bone_orbit": (bone_orbit, 1),
    "bone_crack": (bone_crack, 2),
    "sanzu_wave": (sanzu_wave, 1),
    "ferry_bell": (ferry_bell, 1),
    "legion_march": (legion_march, 1),
    "soul_pickup": (soul_pickup, 3),
    "harvest": (harvest, 1),
    "bone_wall": (bone_wall, 1),
    "yomigaeri": (yomigaeri, 1),
    "rite": (rite, 1),
    "gasha_roar": (gasha_roar, 1),
    "gasha_slam": (gasha_slam, 1),
    "gasha_rise": (gasha_rise, 1),
    "datsueba_cackle": (datsueba_cackle, 1),
    "masakado_cry": (masakado_cry, 1),
    "kazaguruma": (kazaguruma, 1),
    "kuon_freed": (kuon_freed, 1),
}


def seed_for(name: str, v: int) -> int:
    return BASE_SEED + int(hashlib.sha256(f"{name}_{v}".encode()).hexdigest()[:8], 16)


# Duração máxima (s): golpes curtos ficam em 1,5 s; ambiente e vinhetas até 3 s.
MAX_LEN = {"raise": 1.3, "sanzu_wave": 2.0, "ferry_bell": 2.6, "legion_march": 2.8, "yomigaeri": 3.0,
           "rite": 3.0, "gasha_roar": 2.6, "gasha_slam": 1.9, "gasha_rise": 3.0, "datsueba_cackle": 2.0,
           "masakado_cry": 2.3, "kazaguruma": 3.0, "kuon_freed": 3.0}


def cap(x: list, seconds: float, fade: float = 0.15) -> list:
    """Corta em `seconds` com fade quadrático de `fade` s (cauda de reverb longa demais)."""
    n = ns(seconds)
    if len(x) <= n:
        return x
    x = x[:n]
    f = ns(fade)
    for i in range(f):
        x[n - f + i] *= (1.0 - (i + 1) / f) ** 2
    return x


def render(name: str, v: int) -> list:
    fn, _ = RECIPES[name]
    raw, rel = fn(random.Random(seed_for(name, v)), v)
    x = cap(trim_tail(raw, -50.0), MAX_LEN.get(name, 1.5))
    return finish(x, rel * 10.0 ** (PEAK_DB / 20.0), fade_out_ms=40.0)


def update_index(written: list, root: pathlib.Path) -> None:
    path = root / "assets" / "asset_index.json"
    index = json.loads(path.read_text(encoding="utf-8"))
    names = {f.relative_to(root).as_posix() for f in written}
    index = [row for row in index if row.get("license_id") != LICENSE_ID and row["file"] not in names]
    for file in written:
        index.append({
            "file": file.relative_to(root).as_posix(),
            "source": "tools/gen_necro_sfx.py",
            "license_id": LICENSE_ID,
            "sha256": hashlib.sha256(file.read_bytes()).hexdigest(),
        })
    index.sort(key=lambda item: item["file"])
    path.write_text(json.dumps(index, indent=1, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=None, help="raiz do repositório (padrão: pasta acima de tools/)")
    ap.add_argument("--out", default=None, help="pasta de saída (padrão: <root>/assets/audio/sfx)")
    ap.add_argument("--only", default="", help="nomes separados por vírgula (sem prefixo)")
    ap.add_argument("--update-index", action="store_true", help="atualiza assets/asset_index.json")
    args = ap.parse_args()
    out_dir = pathlib.Path(args.out) if args.out else ROOT / "assets" / "audio" / "sfx"
    out_dir.mkdir(parents=True, exist_ok=True)
    only = {s for s in args.only.split(",") if s}
    written = []
    for name, (fn, count) in RECIPES.items():
        if only and name not in only:
            continue
        for v in range(count):
            x = render(name, v)
            stem = name if count == 1 else f"{name}_{v}"
            path = out_dir / f"{PREFIX}{stem}.wav"
            write_wav(path, x)
            written.append(path)
            rms = math.sqrt(sum(s * s for s in x) / len(x))
            print(f"{path.name:28} {len(x) / SR:.3f} s  pico {20 * math.log10(max(abs(s) for s in x)):.1f} dBFS"
                  f"  rms {20 * math.log10(rms):.1f} dBFS")
    if args.update_index:
        update_index(written, ROOT)
    print(f"{len(written)} arquivos gerados em {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
