"""Gera os efeitos sonoros procedurais dos Altares do Selo e dos Elites (prefixo alt_) em
assets/audio/sfx/.

Obra original do projeto Hyakki, liberada em CC0-1.0 (entrada `hyakki_altar_sfx` em
licenses/registry.json). Só biblioteca padrão e sementes fixas: rodar de novo produz os
mesmos bytes. Usa os blocos de tools/gen_sfx.py (osciladores, filtro de estado variável,
sinos, estalos, finalização) mais um reverb de Schroeder (4 pentes com amortecimento e 2
passa-tudo) para as caudas, e grava WAV PCM 16 bits, mono, 44,1 kHz, normalizado sem clipping
no mesmo pico dos outros geradores (cerca de -1 dBFS).

- alt_hum: zumbido do altar canalizando, 2 s em loop perfeito (coro grave com vibrato,
  quinta e oitava, formantes "ah", brilho agudo com tremolo e ar filtrado; tudo periódico em
  2 s e filtrado em regime: o fim emenda no começo sem estalo). Marque loop no .import;
- alt_rune_0..3: sino rin (sino de tigela do templo) a cada runa acesa, subindo de tom
  (lá, si, ré, mi), com batimento entre parciais e cauda de reverb;
- alt_break: o selo estourando: estalo de vidro com dezenas de cacos tilintando, papel
  rasgando e um estrondo grave;
- alt_thunder_0..2: raio caindo perto: estalo seco e ramificado e o ronco que rola;
- alt_elite_rise: o Elite subindo do chão: ronco que cresce, sopro que sobe e o impacto final;
- alt_elite_roar: rugido monstruoso em camadas (três gargantas, sub-harmônico e aspereza);
- alt_elite_death: explosão grande em camadas e o arpejo de sinos da vitória;
- alt_shield_hit: escudo de cristal (Kongō) recebendo golpe: "ting" vítreo curto;
- alt_shield_break: o escudo de cristal estilhaçando;
- alt_ambush: emboscada: golpe de taiko grave e gongo;
- alt_telegraph: aviso curto de golpe chegando: zunido que sobe.

Também atualiza só as linhas desta licença em assets/asset_index.json (hash e origem).
Depois rode o import do Godot para criar os .import.
Uso: python -I tools/gen_altar_sfx.py
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
LICENSE_ID = "hyakki_altar_sfx"
PREFIX = "alt_"
BASE_SEED = 9137
HUM_SECONDS = 2.0


def _gen_sfx():
    spec = importlib.util.spec_from_file_location("hyakki_gen_sfx", ROOT / "tools" / "gen_sfx.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


G = _gen_sfx()
SR, TAU = G.SR, G.TAU
ns, zeros, noise, mix, mul, scale = G.ns, G.zeros, G.noise, G.mix, G.mul, G.scale
exp_env, sweep, osc, lp, hp, bp = G.exp_env, G.sweep, G.osc, G.lp, G.hp, G.bp
crackle, place, tone_env, finish, write_wav = G.crackle, G.place, G.tone_env, G.finish, G.write_wav


# --- Blocos próprios ---------------------------------------------------------------------

def reverb(x: list, tail: float, room: float = 0.82, damp: float = 0.35, wet: float = 0.3) -> list:
    """Reverb de Schroeder (estilo Freeverb, mono): 4 pentes com passa-baixa na realimentação
    em paralelo e 2 passa-tudo em série. Devolve o sinal seco + molhado, com `tail` s a mais."""
    n = len(x) + ns(tail)
    src = x + [0.0] * (n - len(x))
    wet_sum = [0.0] * n
    for d in (1557, 1617, 1491, 1422):
        buf = [0.0] * d
        idx, store = 0, 0.0
        for i in range(n):
            y = buf[idx]
            store = y * (1.0 - damp) + store * damp
            buf[idx] = src[i] + store * room
            idx = idx + 1 if idx + 1 < d else 0
            wet_sum[i] += y
    for d in (556, 225):
        buf = [0.0] * d
        idx = 0
        for i in range(n):
            b = buf[idx]
            v = wet_sum[i]
            buf[idx] = v + b * 0.5
            wet_sum[i] = b - v
            idx = idx + 1 if idx + 1 < d else 0
    return [s + w * wet * 0.25 for s, w in zip(src, wet_sum)]


def partials(seconds: float, freq: float, table, strike: float = 0.002) -> list:
    """Soma de parciais (razão, amplitude, queda em s, desafinação em Hz para batimento)."""
    out = []
    a = max(1, ns(strike))
    for i in range(ns(seconds)):
        t = i / SR
        s = 0.0
        for r, amp, dec, beat in table:
            f = freq * r
            e = amp * math.exp(-t / dec)
            if e < 1e-5:
                continue
            s += e * math.sin(TAU * f * t)
            if beat:
                s += e * 0.6 * math.sin(TAU * (f + beat) * t + 0.7)
        out.append(s * (min(1.0, i / a)))
    return out


def boom(seconds: float, f0: float, f1: float, decay: float, attack: float = 0.004) -> list:
    """Golpe grave: seno com a altura caindo e queda exponencial."""
    n = ns(seconds)
    return mul(osc(sweep(f0, f1, n)), exp_env(seconds, decay, attack))


def glass_shards(rng: random.Random, seconds: float, count: int, lo: float, hi: float, spread: float) -> list:
    """Cacos de vidro: muitos 'tings' curtos de parciais inarmônicas espalhados no tempo."""
    out = zeros(seconds)
    for k in range(count):
        at = (rng.random() ** 1.8) * spread
        f = rng.uniform(lo, hi)
        dec = rng.uniform(0.03, 0.14)
        amp = rng.uniform(0.25, 1.0) * (1.0 - 0.6 * at / max(spread, 1e-6))
        ping = partials(min(seconds - at, dec * 6.0), f, ((1.0, 1.0, dec, 0.0), (2.32, 0.6, dec * 0.7, 0.0),
                                                           (4.25, 0.35, dec * 0.45, 0.0)), 0.0005)
        place(out, ping, at, amp)
    return out


def rin(freq: float, seconds: float) -> list:
    """Sino rin (tigela de bronze): fundamental longa, parciais da tigela com batimento lento,
    golpe da baqueta (ruído curto filtrado) e um leve tremolo de giro."""
    table = ((1.0, 1.0, 1.4, 1.6), (2.71, 0.55, 0.9, 2.3), (5.15, 0.3, 0.45, 3.1), (8.1, 0.16, 0.22, 0.0),
             (0.5, 0.12, 0.8, 0.0))
    body = partials(seconds, freq, table, 0.0015)
    return body


# --- Receitas: (rng, v) -> (sinal cru, pico alvo) ------------------------------------------

def hum(rng, v):
    """Loop de 2 s: só componentes periódicos em 2 s; filtros aplicados sobre 3 voltas e
    recorta-se a do meio (regime estacionário), então o fim emenda no começo."""
    n = ns(HUM_SECONDS)

    def cyc(f: float) -> float:
        return round(f * HUM_SECONDS) / HUM_SECONDS

    out = [0.0] * n
    # Coro: vozes em dente-de-serra com vibrato periódico (fase integrada analiticamente).
    voices = [(cyc(65.5), 1.0, cyc(5.0), 0.010), (cyc(65.5 * 1.004), 0.8, cyc(4.5), 0.012),
              (cyc(98.0), 0.6, cyc(5.5), 0.009), (cyc(131.0), 0.45, cyc(6.0), 0.008),
              (cyc(196.5), 0.22, cyc(5.0), 0.007)]
    for f, amp, fv, depth in voices:
        p0 = rng.uniform(0.0, TAU)
        harmonics = range(1, 14)
        for i in range(n):
            t = i / SR
            ph = TAU * f * t + (depth * f / fv) * math.sin(TAU * fv * t) + p0
            s = 0.0
            for h in harmonics:
                s += math.sin(h * ph) / h
            out[i] += amp * s
    # Brilho agudo (sinos longos de fundo) com tremolo de 1,5 Hz.
    shimmer = [(cyc(1046.5), 0.05), (cyc(1568.0), 0.035), (cyc(2093.0), 0.025), (cyc(2637.0), 0.015)]
    tremolo = cyc(1.5)
    for i in range(n):
        t = i / SR
        tr = 0.6 + 0.4 * math.sin(TAU * tremolo * t)
        out[i] += tr * sum(a * math.sin(TAU * f * t + k) for k, (f, a) in enumerate(shimmer))
    # Ar: ruído de 2 s repetido (é periódico), modulado pela "respiração" de 0,5 Hz.
    air = noise(rng, HUM_SECONDS)
    breath = cyc(0.5)
    for i in range(n):
        out[i] += 0.25 * air[i] * (0.6 + 0.4 * math.sin(TAU * breath * i / SR))
    # Formantes de vogal "ah" e corpo grave, em 3 voltas; fica a do meio.
    tri = out * 3
    ah = mix((bp(tri, 720.0, 4.0), 1.3), (bp(tri, 1150.0, 5.0), 0.8), (bp(tri, 2600.0, 6.0), 0.25),
             (lp(tri, 300.0), 0.55))
    air_f = bp(air * 3, 3200.0, 1.2)
    seg = [a + 0.18 * b for a, b in zip(ah[n:2 * n], air_f[n:2 * n])]
    return seg, 0.62


def trim_tail(x: list, db: float = -60.0) -> list:
    """Corta a cauda que já caiu abaixo de `db` em relação ao pico (janelas de 10 ms)."""
    peak = max(abs(s) for s in x) or 1.0
    limit = peak * 10.0 ** (db / 20.0)
    win = ns(0.01)
    end = len(x)
    while end > win and max(abs(s) for s in x[end - win:end]) < limit:
        end -= win
    return x[:end]


def hum_finish(x: list, peak: float) -> list:
    """Normaliza o loop sem fades (os fades quebrariam a emenda)."""
    mean = sum(x) / len(x)
    x = [s - mean for s in x]
    m = max(abs(s) for s in x) or 1.0
    return [max(-1.0, min(1.0, s * peak / m)) for s in x]


RUNE_NOTES = (880.0, 987.77, 1174.66, 1318.51)


def rune(rng, v):
    f = RUNE_NOTES[v]
    dur = 1.6
    body = rin(f, dur)
    # Baqueta: clique de madeira + ruído brilhante muito curto.
    tick = mul(hp(noise(rng, 0.03), 2500.0), exp_env(0.03, 0.004, 0.0003))
    knock = boom(0.05, 420.0, 300.0, 0.012, 0.0005)
    # Brilho de "selo": um segundo sino uma oitava acima, entrando de leve.
    halo = partials(dur, f * 2.0, ((1.0, 1.0, 0.5, 2.0), (2.76, 0.4, 0.25, 0.0)), 0.04)
    x = mix((body, 1.0), (tick, 0.35), (knock, 0.25), (halo, 0.18 + 0.04 * v))
    return reverb(x, 0.6, room=0.84, damp=0.4, wet=0.45), 0.85


def seal_break(rng, v):
    dur = 1.9
    out = zeros(dur)
    # Estalo inicial (vidro grande partindo): ruído largo e seco.
    crack = mul(noise(rng, 0.06), exp_env(0.06, 0.008, 0.0002))
    place(out, mix((hp(crack, 1200.0), 1.0), (crack, 0.4)), 0.0, 1.2)
    # Cacos tilintando.
    place(out, glass_shards(rng, 1.2, 46, 2200.0, 7800.0, 0.55), 0.01, 0.55)
    # Papel rasgando: ruído em banda com rajadas irregulares.
    tear_len = 0.32
    tn = ns(tear_len)
    tear = bp(noise(rng, tear_len), sweep(1800.0, 3400.0, tn), 1.4)
    grains = lp([abs(s) for s in noise(rng, tear_len)], 90.0)
    tear = [s * (0.3 + 4.0 * g) for s, g in zip(tear, grains)]
    place(out, mul(tear, tone_env(tear_len, lambda t: min(1.0, t / 0.02) * math.exp(-t / 0.18))), 0.02, 0.9)
    place(out, hp(crackle(rng, 0.3, 700, 0.6), 2000.0), 0.02, 0.5)
    # Estrondo grave e o corpo do "selo" soltando ar.
    place(out, boom(1.4, 95.0, 34.0, 0.42, 0.003), 0.0, 1.2)
    body = lp(noise(rng, 1.0), sweep(1400.0, 120.0, ns(1.0)), 0.8)
    place(out, mul(body, exp_env(1.0, 0.22, 0.002)), 0.0, 1.4)
    # Brilho que some (o selo morrendo): varredura descendente.
    fall = mul(osc(sweep(2400.0, 500.0, ns(0.7))), exp_env(0.7, 0.2, 0.01))
    place(out, fall, 0.05, 0.12)
    return reverb(out, 0.5, room=0.8, damp=0.45, wet=0.35), 0.9


def close_thunder(rng, v):
    dur = 1.7 + 0.2 * v
    out = zeros(dur)
    # Estalo muito perto: ruído largo, uma rajada de estalos e ramificações.
    cl = 0.12
    c = mul(noise(rng, cl), exp_env(cl, 0.018, 0.0002))
    c = mix((hp(c, 700.0), 1.0), (c, 0.7),
            (mul(hp(crackle(rng, cl, 3200 + 700 * v, 0.7), 1300.0), exp_env(cl, 0.05)), 1.6))
    place(out, c, 0.0, 0.75)
    for k in range(2 + v):
        at = 0.03 + 0.045 * k + rng.uniform(0.0, 0.02)
        b = mul(hp(noise(rng, 0.06), 900.0 + 300.0 * k), exp_env(0.06, 0.012, 0.0004))
        place(out, b, at, 0.65 - 0.12 * k)
    # Estalo de ar (onda de choque): um golpe grave curtíssimo.
    place(out, boom(0.25, 140.0, 45.0, 0.07, 0.0008), 0.0, 0.9)
    # Ronco que rola com ondulações.
    rl = dur - 0.05
    n = ns(rl)
    r = lp(lp(noise(rng, rl), sweep(1100.0, 120.0, n), 0.8), sweep(700.0, 90.0, n), 0.9)
    swells = [(rng.uniform(0.08, rl * 0.6), rng.uniform(0.1, 0.3), rng.uniform(0.4, 1.0)) for _ in range(5 + v)]

    def env(t):
        s = 0.4 + sum(a * math.exp(-((t - c0) / w) ** 2) for c0, w, a in swells)
        return s * math.exp(-t / (0.55 + 0.1 * v)) * min(1.0, t / 0.02)

    place(out, mul(r, tone_env(rl, env)), 0.03, 5.2)
    sub = mul(osc(sweep(52.0, 30.0, n)), tone_env(rl, lambda t: math.exp(-t / 0.45) * min(1.0, t / 0.01)))
    place(out, sub, 0.01, 0.45)
    return reverb(out, 0.4, room=0.78, damp=0.5, wet=0.2), 0.92


def elite_rise(rng, v):
    dur = 2.1
    hit = 1.42
    out = zeros(dur)
    # Ronco crescente: ruído grave com o corte subindo e volume em curva.
    rn = ns(hit)
    rum = lp(lp(noise(rng, hit), sweep(90.0, 900.0, rn), 0.9), sweep(120.0, 1100.0, rn), 0.8)
    place(out, mul(rum, tone_env(hit, lambda t: (t / hit) ** 1.6)), 0.0, 4.0)
    # Sopro que sobe (prato ao contrário) e varredura tonal.
    whoosh = bp(noise(rng, hit), sweep(300.0, 4200.0, rn), 1.6)
    place(out, mul(whoosh, tone_env(hit, lambda t: (t / hit) ** 3.0)), 0.0, 1.3)
    riser = mix((osc(sweep(48.0, 190.0, rn), "saw"), 0.5), (osc(sweep(72.0, 285.0, rn), "saw"), 0.3))
    riser = lp(riser, sweep(300.0, 2400.0, rn), 1.1)
    place(out, mul(riser, tone_env(hit, lambda t: (t / hit) ** 2.2)), 0.0, 0.7)
    # Tremor da terra: batidas graves acelerando.
    t, k = 0.15, 0
    while t < hit - 0.05:
        place(out, boom(0.18, 70.0, 40.0, 0.06, 0.002), t, 0.25 + 0.5 * t / hit)
        k += 1
        t += max(0.06, 0.32 * 0.82 ** k)
    # Impacto: estalo, golpe grave e corpo de ruído.
    crack = mul(noise(rng, 0.05), exp_env(0.05, 0.01, 0.0002))
    place(out, hp(crack, 900.0), hit, 1.0)
    place(out, boom(0.65, 120.0, 36.0, 0.22, 0.002), hit, 1.5)
    body = lp(noise(rng, 0.6), sweep(2000.0, 150.0, ns(0.6)), 0.8)
    place(out, mul(body, exp_env(0.6, 0.12, 0.002)), hit, 1.6)
    return reverb(out, 0.45, room=0.8, damp=0.4, wet=0.3), 0.92


def elite_roar(rng, v):
    dur = 1.8
    n = ns(dur)
    # Altura: sobe no ataque, segura e cai no fim (com tremor de garganta).
    jitter = lp(noise(rng, dur), 14.0)

    def pitch(base):
        out = []
        for i in range(n):
            k = i / n
            contour = 1.0 + 0.45 * math.sin(math.pi * min(1.0, k * 1.6)) - 0.25 * max(0.0, k - 0.6)
            out.append(base * contour * (1.0 + 0.04 * math.sin(TAU * 6.5 * i / SR) + 0.8 * jitter[i]))
        return out

    throat1 = osc(pitch(58.0), "saw")
    throat2 = osc(pitch(87.5), "saw")
    throat3 = osc(pitch(29.0), "square")  # sub-harmônico (dobra de período)
    raw = mix((throat1, 1.0), (throat2, 0.7), (throat3, 0.35), (noise(rng, dur), 0.5))
    # Formantes de uma vogal "aa/oo" que abre e fecha.
    f1 = [520.0 + 260.0 * math.sin(math.pi * min(1.0, i / n * 1.3)) for i in range(n)]
    voiced = mix((bp(raw, f1, 3.0), 1.4), (bp(raw, 1250.0, 4.0), 0.6), (lp(raw, 260.0), 0.9))
    # Aspereza: ruído em banda modulado a 31 Hz (garganta rasgando).
    grit = bp(noise(rng, dur), 1900.0, 1.2)
    grit = [g * (0.5 + 0.5 * math.sin(TAU * 31.0 * i / SR)) for i, g in enumerate(grit)]
    x = mix((voiced, 1.0), (grit, 0.45))
    e = tone_env(dur, lambda t: min(1.0, t / 0.12) * (1.0 if t < 1.0 else math.exp(-(t - 1.0) / 0.3)))
    x = mul(x, e)
    # Eco agudo de yōkai por cima.
    ghost = mul(osc(sweep(640.0, 410.0, n)), tone_env(dur, lambda t: math.sin(math.pi * min(1.0, t / 1.4)) ** 2))
    x = mix((x, 1.0), (ghost, 0.06))
    return reverb(x, 0.45, room=0.8, damp=0.45, wet=0.25), 0.95


def elite_death(rng, v):
    dur = 2.9
    out = zeros(dur)
    # Explosão em camadas: estalo, corpo de ruído caindo, sub, detritos.
    crack = mul(noise(rng, 0.08), exp_env(0.08, 0.014, 0.0002))
    place(out, mix((hp(crack, 800.0), 1.0), (crack, 0.6)), 0.0, 1.1)
    bn = ns(1.6)
    body = lp(lp(noise(rng, 1.6), sweep(3500.0, 140.0, bn), 0.7), sweep(2500.0, 120.0, bn), 0.8)
    place(out, mul(body, exp_env(1.6, 0.35, 0.003)), 0.0, 2.6)
    place(out, boom(1.3, 110.0, 30.0, 0.4, 0.003), 0.0, 1.4)
    debris = hp(crackle(rng, 1.0, 380, 1.2), 1500.0)
    place(out, mul(debris, exp_env(1.0, 0.35)), 0.06, 0.6)
    place(out, boom(0.5, 80.0, 40.0, 0.15, 0.003), 0.18, 0.5)
    # Sino da vitória: arpejo rápido subindo (dó-mi-sol-dó) e acorde sustentado.
    notes = (1046.5, 1318.5, 1568.0, 2093.0)
    for k, f in enumerate(notes):
        b = partials(1.9, f, ((1.0, 1.0, 0.8, 1.5), (2.76, 0.45, 0.35, 0.0), (5.4, 0.22, 0.15, 0.0)), 0.001)
        place(out, b, 0.32 + 0.075 * k, 0.32)
    chord = partials(2.0, 523.25, ((1.0, 1.0, 1.2, 1.2), (1.5, 0.7, 1.0, 0.9), (2.0, 0.6, 0.9, 1.1),
                                    (3.0, 0.25, 0.5, 0.0)), 0.01)
    place(out, chord, 0.62, 0.22)
    sparkle = glass_shards(rng, 1.4, 22, 3500.0, 8000.0, 0.9)
    place(out, sparkle, 0.4, 0.12)
    return reverb(out, 0.6, room=0.84, damp=0.4, wet=0.33), 0.92


def shield_hit(rng, v):
    dur = 0.55
    ping = partials(dur, 2350.0, ((1.0, 1.0, 0.16, 7.0), (1.51, 0.7, 0.12, 0.0), (2.43, 0.5, 0.08, 0.0),
                                  (3.87, 0.3, 0.05, 0.0)), 0.0005)
    tick = mul(hp(noise(rng, 0.02), 4000.0), exp_env(0.02, 0.003, 0.0002))
    thud = boom(0.12, 300.0, 180.0, 0.03, 0.0005)
    x = mix((ping, 1.0), (tick, 0.6), (thud, 0.35))
    return reverb(x, 0.35, room=0.7, damp=0.3, wet=0.35), 0.82


def shield_break(rng, v):
    dur = 1.4
    out = zeros(dur)
    crack = mul(noise(rng, 0.05), exp_env(0.05, 0.008, 0.0002))
    place(out, hp(crack, 1800.0), 0.0, 1.2)
    place(out, partials(0.6, 1880.0, ((1.0, 1.0, 0.18, 9.0), (1.51, 0.6, 0.12, 0.0), (2.43, 0.4, 0.07, 0.0)),
                        0.0005), 0.0, 0.8)
    place(out, glass_shards(rng, 1.3, 60, 2600.0, 9000.0, 0.7), 0.012, 0.7)
    fall = mul(osc(sweep(4200.0, 900.0, ns(0.6))), exp_env(0.6, 0.18, 0.005))
    place(out, fall, 0.02, 0.15)
    place(out, boom(0.4, 180.0, 70.0, 0.1, 0.001), 0.0, 0.6)
    return reverb(out, 0.4, room=0.75, damp=0.3, wet=0.3), 0.88


def ambush(rng, v):
    dur = 3.0
    out = zeros(dur)
    # Taiko: pele (ruído curto), corpo grave com a altura caindo e ressonância do barril.
    place(out, boom(0.9, 115.0, 52.0, 0.28, 0.002), 0.0, 1.5)
    place(out, boom(0.6, 230.0, 140.0, 0.08, 0.001), 0.0, 0.3)
    skin = mul(lp(noise(rng, 0.08), 2200.0), exp_env(0.08, 0.02, 0.0005))
    place(out, skin, 0.0, 0.8)
    # Segundo golpe de borda (ka) bem curto.
    ka = mul(bp(noise(rng, 0.04), 2600.0, 3.0), exp_env(0.04, 0.008, 0.0003))
    place(out, ka, 0.19, 0.5)
    # Gongo: parciais inarmônicas com batimento e "bloom" (os agudos crescem depois do golpe).
    gong = partials(2.7, 98.0, ((1.0, 1.0, 1.4, 0.7), (1.52, 0.6, 1.1, 1.3), (2.31, 0.5, 0.9, 1.7),
                                (2.98, 0.4, 0.8, 0.0), (3.73, 0.35, 0.7, 2.2), (4.61, 0.3, 0.55, 0.0),
                                (5.97, 0.22, 0.45, 2.9), (7.4, 0.15, 0.35, 0.0)), 0.008)
    gn = len(gong)
    bloom = [math.sin(math.pi * min(1.0, i / gn * 2.2)) * 0.9 + 0.1 for i in range(gn)]
    gong = mix((lp(gong, 900.0), 1.0), (mul(hp(gong, 900.0), bloom), 1.2))
    place(out, gong, 0.03, 0.75)
    # Sopro sombrio grave por baixo.
    drone = lp(noise(rng, 2.5), 220.0)
    place(out, mul(drone, tone_env(2.5, lambda t: math.sin(math.pi * min(1.0, t / 2.5)) ** 2)), 0.1, 1.6)
    return reverb(out, 0.5, room=0.82, damp=0.45, wet=0.28), 0.92


def telegraph(rng, v):
    dur = 0.42
    n = ns(dur)
    f = sweep(520.0, 2300.0, n)
    vib = [ff * (1.0 + 0.03 * math.sin(TAU * 28.0 * i / SR)) for i, ff in enumerate(f)]
    tone = mix((osc(vib, "saw"), 0.6), (osc([x * 1.5 for x in vib]), 0.4))
    tone = bp(tone, sweep(900.0, 3600.0, n), 1.6)
    air = bp(noise(rng, dur), sweep(1500.0, 6000.0, n), 2.0)
    e = tone_env(dur, lambda t: min(1.0, t / 0.03) * (1.0 if t < 0.3 else math.exp(-(t - 0.3) / 0.03)))
    x = mul(mix((tone, 1.0), (air, 0.35)), e)
    ping = partials(0.3, 2793.8, ((1.0, 1.0, 0.07, 0.0), (2.76, 0.4, 0.04, 0.0)), 0.0005)
    out = x + [0.0] * ns(0.12)
    place(out, ping, 0.3, 0.35)
    return reverb(out, 0.15, room=0.6, damp=0.4, wet=0.2), 0.8


# nome -> (função, variações); variação única sem sufixo de índice.
RECIPES = {
    "hum": (hum, 1),
    "rune": (rune, 4),
    "break": (seal_break, 1),
    "thunder": (close_thunder, 3),
    "elite_rise": (elite_rise, 1),
    "elite_roar": (elite_roar, 1),
    "elite_death": (elite_death, 1),
    "shield_hit": (shield_hit, 1),
    "shield_break": (shield_break, 1),
    "ambush": (ambush, 1),
    "telegraph": (telegraph, 1),
}


def seed_for(name: str, v: int) -> int:
    return BASE_SEED + int(hashlib.sha256(f"{name}_{v}".encode()).hexdigest()[:8], 16)


def update_index(written: list) -> None:
    path = ROOT / "assets" / "asset_index.json"
    index = json.loads(path.read_text(encoding="utf-8"))
    names = {f.relative_to(ROOT).as_posix() for f in written}
    index = [row for row in index if row.get("license_id") != LICENSE_ID and row["file"] not in names]
    for file in written:
        index.append({
            "file": file.relative_to(ROOT).as_posix(),
            "source": "tools/gen_altar_sfx.py",
            "license_id": LICENSE_ID,
            "sha256": hashlib.sha256(file.read_bytes()).hexdigest(),
        })
    index.sort(key=lambda item: item["file"])
    path.write_text(json.dumps(index, indent=1, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for name, (fn, count) in RECIPES.items():
        for v in range(count):
            raw, peak = fn(random.Random(seed_for(name, v)), v)
            if name == "hum":
                x = hum_finish(raw, peak)
            else:
                x = finish(trim_tail(raw), peak, fade_out_ms=40.0)
            stem = name if count == 1 else f"{name}_{v}"
            path = OUT / f"{PREFIX}{stem}.wav"
            write_wav(path, x)
            written.append(path)
            rms = math.sqrt(sum(s * s for s in x) / len(x))
            print(f"{path.relative_to(ROOT).as_posix()}  {len(x) / SR:.3f} s  "
                  f"pico {20 * math.log10(max(abs(s) for s in x)):.1f} dBFS  rms {20 * math.log10(rms):.1f} dBFS")
    update_index(written)
    print(f"{len(written)} arquivos gerados")
    return 0


if __name__ == "__main__":
    sys.exit(main())
