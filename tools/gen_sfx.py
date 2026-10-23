"""Gera os efeitos sonoros procedurais do jogo (prefixo g_) em assets/audio/sfx/.

Obra original do projeto Hyakki, liberada em CC0-1.0 (entrada `hyakki_generated_sfx` em
licenses/registry.json). Só biblioteca padrão e sementes fixas: rodar de novo produz os
mesmos bytes. Saída: WAV PCM 16 bits, mono, 44,1 kHz, normalizado sem clipping, com fade de
entrada e saída.

Também atualiza as linhas g_* de assets/asset_index.json (hash e origem) para o
tools/check_licenses.py. Depois rode o import do Godot para criar os .import.
Uso: python -I tools/gen_sfx.py
"""
import hashlib
import json
import math
import pathlib
import random
import struct
import sys
import wave

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio" / "sfx"
SR = 44100
LICENSE_ID = "hyakki_generated_sfx"
BASE_SEED = 1931  # fixa: o resultado é reproduzível
TAU = 2.0 * math.pi


# --- Blocos básicos (sinais são listas de float) -------------------------------------

def ns(seconds: float) -> int:
    return int(seconds * SR)


def zeros(seconds: float) -> list:
    return [0.0] * ns(seconds)


def noise(rng: random.Random, seconds: float) -> list:
    return [rng.uniform(-1.0, 1.0) for _ in range(ns(seconds))]


def mix(*parts) -> list:
    """Soma (sinal, ganho) de mesmo tamanho ou menor (completa com zero)."""
    n = max(len(p) for p, _ in parts)
    out = [0.0] * n
    for sig, gain in parts:
        for i, s in enumerate(sig):
            out[i] += s * gain
    return out


def mul(a: list, b: list) -> list:
    return [x * y for x, y in zip(a, b)]


def scale(a: list, g: float) -> list:
    return [x * g for x in a]


def exp_env(seconds: float, decay: float, attack: float = 0.001) -> list:
    """Ataque linear curto e queda exponencial (decay = constante de tempo em s)."""
    a = max(1, ns(attack))
    out = []
    for i in range(ns(seconds)):
        e = math.exp(-i / SR / decay)
        if i < a:
            e *= i / a
        out.append(e)
    return out


def sweep(start: float, end: float, n: int, exponential: bool = True) -> list:
    if n <= 1:
        return [start] * n
    if exponential:
        r = end / start
        return [start * r ** (i / (n - 1)) for i in range(n)]
    return [start + (end - start) * i / (n - 1) for i in range(n)]


def osc(freq: list, kind: str = "sine", phase: float = 0.0) -> list:
    """Oscilador com frequência por amostra."""
    out = []
    p = phase / TAU
    for f in freq:
        p += f / SR
        frac = p % 1.0
        if kind == "sine":
            out.append(math.sin(TAU * frac))
        elif kind == "saw":
            out.append(2.0 * frac - 1.0)
        else:  # square
            out.append(1.0 if frac < 0.5 else -1.0)
    return out


def svf(x: list, cutoff, q: float, mode: str) -> list:
    """Filtro de estado variável TPT (Zavalishin), estável em qualquer corte; corte fixo ou
    por amostra. mode: lp, hp, bp."""
    n = len(x)
    cuts = cutoff if isinstance(cutoff, list) else [cutoff] * n
    k = 1.0 / q
    ic1 = ic2 = 0.0
    out = [0.0] * n
    top = SR * 0.45
    last_c = None
    a1 = a2 = a3 = 0.0
    for i in range(n):
        c = min(max(cuts[i], 10.0), top)
        if c != last_c:
            g = math.tan(math.pi * c / SR)
            a1 = 1.0 / (1.0 + g * (g + k))
            a2 = g * a1
            a3 = g * a2
            last_c = c
        v3 = x[i] - ic2
        v1 = a1 * ic1 + a2 * v3
        v2 = ic2 + a2 * ic1 + a3 * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        out[i] = v2 if mode == "lp" else (v1 if mode == "bp" else x[i] - k * v1 - v2)
    return out


def lp(x, cutoff, q=0.7):
    return svf(x, cutoff, q, "lp")


def hp(x, cutoff, q=0.7):
    return svf(x, cutoff, q, "hp")


def bp(x, cutoff, q=2.0):
    return svf(x, cutoff, q, "bp")


def crackle(rng: random.Random, seconds: float, density: float, decay_ms: float = 1.0) -> list:
    """Estalos aleatórios (eletricidade, brasas): impulsos de sinal e altura aleatórios."""
    n = ns(seconds)
    out = [0.0] * n
    k = math.exp(-1.0 / (decay_ms * 0.001 * SR))
    for _ in range(int(density * seconds)):
        pos = rng.randrange(n)
        amp = rng.uniform(0.3, 1.0) * rng.choice((-1.0, 1.0))
        tail = int(decay_ms * 0.006 * SR)
        e = amp
        for j in range(pos, min(n, pos + tail)):
            out[j] += e * rng.uniform(-1.0, 1.0)
            e *= k
    return out


def place(dst: list, src: list, at: float, gain: float = 1.0) -> None:
    i0 = ns(at)
    for j, s in enumerate(src):
        i = i0 + j
        if i >= len(dst):
            break
        dst[i] += s * gain


def ramp_in(x: list, seconds: float) -> list:
    a = max(1, ns(seconds))
    return [s * (i / a if i < a else 1.0) for i, s in enumerate(x)]


def bell(freq: float, seconds: float, decay: float, bright: float = 0.5) -> list:
    """Sino pequeno: parciais inarmônicos com quedas diferentes."""
    partials = ((1.0, 1.0, 1.0), (2.76, 0.5 * bright, 0.55), (5.40, 0.3 * bright, 0.3),
                (8.93, 0.15 * bright, 0.2))
    out = []
    for i in range(ns(seconds)):
        t = i / SR
        out.append(sum(a * math.sin(TAU * freq * r * t) * math.exp(-t / (decay * d)) for r, a, d in partials))
    return ramp_in(out, 0.002)


def tone_env(seconds: float, shape) -> list:
    return [shape(i / SR) for i in range(ns(seconds))]


# --- Finalização -------------------------------------------------------------------

def finish(x: list, peak: float, fade_in_ms: float = 1.5, fade_out_ms: float = 12.0) -> list:
    mean = sum(x) / len(x)
    x = hp([s - mean for s in x], 25.0)  # tira DC e subgrave inaudível
    fi = max(1, int(fade_in_ms * 0.001 * SR))
    fo = max(1, int(fade_out_ms * 0.001 * SR))
    n = len(x)
    for i in range(fi):
        x[i] *= i / fi
    for i in range(fo):
        x[n - fo + i] *= (1.0 - (i + 1) / fo) ** 2
    m = max(abs(s) for s in x)
    g = peak / m if m > 0 else 1.0
    return [max(-1.0, min(1.0, s * g)) for s in x]


def write_wav(path: pathlib.Path, x: list) -> None:
    data = struct.pack("<%dh" % len(x), *(int(round(s * 32767.0)) for s in x))
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


# --- Receitas ----------------------------------------------------------------------
# Cada função recebe (rng, v), v = índice da variação, e devolve (sinal cru, pico alvo).

def thunder(rng, v):
    dur = 1.15 + 0.15 * v
    out = zeros(dur)
    # Estalo: rajada larga muito curta + estalos agudos densos.
    cl = 0.09
    c = mul(noise(rng, cl), exp_env(cl, 0.012, 0.0003))
    c = mix((hp(c, 900.0), 0.9), (c, 0.5),
            (mul(hp(crackle(rng, cl, 2500 + 600 * v, 0.8), 1500.0), exp_env(cl, 0.03)), 1.4))
    place(out, c, 0.0)
    # Segundo estalo menor (ramificação do raio).
    c2 = mul(hp(noise(rng, 0.05), 1200.0), exp_env(0.05, 0.01, 0.0005))
    place(out, c2, 0.035 + 0.02 * v, 0.6)
    # Ronco: ruído em passa-baixa com corte descendo e ondulações lentas de volume.
    rl = dur - 0.02
    n = ns(rl)
    r = lp(lp(noise(rng, rl), sweep(900.0, 140.0, n), 0.8), sweep(600.0, 110.0, n), 0.9)
    swells = [(rng.uniform(0.05, rl * 0.7), rng.uniform(0.08, 0.25), rng.uniform(0.4, 1.0))
              for _ in range(4 + v)]
    tau = 0.45 + 0.08 * v

    def rumble_env(t):
        s = 0.35 + sum(a * math.exp(-((t - c0) / w) ** 2) for c0, w, a in swells)
        return s * math.exp(-t / tau) * min(1.0, t / 0.03)

    place(out, mul(r, tone_env(rl, rumble_env)), 0.02, 3.2)
    # Subgrave: seno caindo 55 -> 32 Hz.
    sub = mul(osc(sweep(55.0, 32.0, n)), tone_env(rl, lambda t: math.exp(-t / 0.35) * min(1.0, t / 0.01)))
    place(out, sub, 0.01, 0.35)
    return out, 0.92


def zap(rng, v):
    dur = 0.26 + 0.06 * v
    n = ns(dur)
    jitter = lp(noise(rng, dur), 600.0)
    freq = [f * (1.0 + 0.5 * j) for f, j in zip(sweep(2600.0 + 500.0 * v, 260.0 + 60 * v, n), jitter)]
    body = mix((osc(freq, "saw"), 0.6), (osc([f * 1.503 for f in freq], "square"), 0.25))
    hum = 90 + 25 * v
    body = [b * (0.6 + 0.4 * (1.0 if math.sin(TAU * hum * i / SR) >= 0 else -1.0)) for i, b in enumerate(body)]
    body = mix((bp(body, sweep(5000.0, 900.0, n), 1.2), 1.5), (body, 0.25))
    ck = hp(crackle(rng, dur, 900 + 300 * v, 1.0), 2500.0)
    sizzle = bp(noise(rng, dur), sweep(7000.0, 2500.0, n), 1.5)
    return mul(mix((body, 1.0), (ck, 1.2), (sizzle, 0.5)), exp_env(dur, 0.09 + 0.02 * v, 0.002)), 0.75


def chain_zap(rng, v):
    dur = 0.13 + 0.02 * v
    n = ns(dur)
    freq = [f * (1 + 0.15 * rng.uniform(-1, 1)) for f in sweep(3200.0 + 300 * v, 900.0, n)]
    body = bp(osc(freq, "saw"), 3000.0 + 400 * v, 1.0)
    ck = hp(crackle(rng, dur, 1800, 0.7), 3000.0)
    return mul(mix((body, 0.7), (ck, 1.3)), exp_env(dur, 0.04, 0.001)), 0.6


def hit_blade(rng, v):
    dur = 0.2
    base = 1900.0 * (1 + 0.09 * v)
    ring = [0.0] * ns(dur)
    for ratio, amp, dk in ((1.0, 1.0, 0.07), (1.71, 0.6, 0.05), (2.63, 0.45, 0.035), (3.89, 0.3, 0.025)):
        ph = rng.uniform(0, TAU)
        for i in range(len(ring)):
            t = i / SR
            ring[i] += amp * math.sin(TAU * base * ratio * t + ph) * math.exp(-t / dk)
    tr = mul(hp(noise(rng, dur), 3500.0), exp_env(dur, 0.012, 0.0005))
    thump = mul(lp(noise(rng, dur), 700.0), exp_env(dur, 0.015, 0.0005))
    return mix((ring, 0.35), (tr, 0.9), (thump, 0.6)), 0.62


def hit_projectile(rng, v):
    dur = 0.13
    n = ns(dur)
    body = mul(osc(sweep(280.0 - 25 * v, 110.0, n)), exp_env(dur, 0.035, 0.001))
    click = mul(lp(noise(rng, dur), 2800.0 - 400 * v), exp_env(dur, 0.008, 0.0003))
    wood = mul(bp(noise(rng, dur), 900.0 + 150 * v, 4.0), exp_env(dur, 0.02))
    return mix((body, 1.0), (click, 1.2), (wood, 1.1)), 0.66


def hit_fire(rng, v):
    dur = 0.22
    n = ns(dur)
    peak_t = 0.09 + 0.01 * v
    cut = [700.0 + 2600.0 * math.sin(math.pi * min(i / SR / peak_t, 1.0)) ** 2 * math.exp(-i / SR / 0.12)
           for i in range(n)]
    whoomp = mul(lp(noise(rng, dur), cut, 1.1), exp_env(dur, 0.06, 0.006))
    sizzle = mul(hp(crackle(rng, dur, 700 + 200 * v, 0.8), 3000.0), exp_env(dur, 0.08))
    low = mul(osc(sweep(120.0, 60.0, n)), exp_env(dur, 0.04, 0.003))
    return mix((whoomp, 1.4), (sizzle, 0.9), (low, 0.4)), 0.62


def hit_thunder(rng, v):
    dur = 0.15
    n = ns(dur)
    ck = hp(crackle(rng, dur, 2200 + 400 * v, 0.6), 2200.0)
    buzz = bp(osc(sweep(1400.0 + 200 * v, 500.0, n), "square"), 2500.0, 1.2)
    snap = mul(hp(noise(rng, dur), 1500.0), exp_env(dur, 0.006, 0.0003))
    return mul(mix((ck, 1.0), (buzz, 0.25), (snap, 0.8)), exp_env(dur, 0.04, 0.001)), 0.6


def hit_wind(rng, v):
    dur = 0.2
    n = ns(dur)
    center = 0.06 + 0.01 * v
    swish = mul(bp(noise(rng, dur), sweep(900.0, 3200.0 + 300 * v, n), 2.2),
                tone_env(dur, lambda t: math.exp(-((t - center) / 0.035) ** 2)))
    thump = mul(osc(sweep(110.0, 65.0, n)),
                tone_env(dur, lambda t: 0.0 if t < center - 0.004 else math.exp(-max(t - center, 0.0) / 0.03)))
    return mix((swish, 1.6), (lp(thump, 400.0), 0.6)), 0.58


def hit_area(rng, v):
    dur = 0.24
    n = ns(dur)
    boom = mul(osc(sweep(120.0 - 10 * v, 50.0, n)), exp_env(dur, 0.07, 0.002))
    body = mul(lp(noise(rng, dur), sweep(2200.0, 300.0, n), 0.9), exp_env(dur, 0.045, 0.001))
    thud = mul(bp(noise(rng, dur), 260.0 + 30 * v, 1.5), exp_env(dur, 0.05, 0.002))
    return mix((boom, 1.0), (body, 1.6), (thud, 2.0)), 0.68


def hit_orbit(rng, v):
    dur = 0.22
    chime = bell((1568.0, 1760.0, 2093.0)[v], dur, 0.09, 0.4)  # G6, A6, C7 (pentatônica)
    paper = mul(bp(noise(rng, dur), 2600.0 + 300 * v, 1.5), exp_env(dur, 0.01, 0.0005))
    tap = mul(lp(noise(rng, dur), 1500.0), exp_env(dur, 0.006, 0.0003))
    return mix((chime, 0.45), (paper, 1.2), (tap, 0.5)), 0.55


def hit_poison(rng, v):
    dur = 0.22
    out = scale(mul(bp(noise(rng, dur), 4500.0, 0.8), exp_env(dur, 0.07, 0.01)), 0.5)
    for _ in range(4 + v):
        bl = rng.uniform(0.018, 0.035)
        f0 = rng.uniform(260.0, 520.0)
        m = ns(bl)
        blip = mul(osc(sweep(f0, f0 * 2.6, m)), [math.sin(math.pi * i / m) for i in range(m)])
        place(out, blip, rng.uniform(0.0, dur - bl - 0.02), rng.uniform(0.4, 0.9))
    gurgle = mul(lp(noise(rng, dur), 500.0), exp_env(dur, 0.03, 0.004))
    return mix((out, 1.0), (gurgle, 0.8)), 0.55


def ofuda_cast(rng, v):
    dur = 0.6 + 0.05 * v
    n = ns(dur)
    # Papel batendo: ruído em banda com batidas irregulares de 25-40 Hz.
    flap = []
    p = 0.0
    for i in range(n):
        t = i / SR
        p += (28.0 + 6.0 * v + 6.0 * math.sin(TAU * 3.0 * t)) / SR
        f = max(0.0, math.sin(TAU * p)) ** 3
        f *= math.sin(math.pi * min(t / (dur * 0.7), 1.0)) ** 1.5
        flap.append(f)
    center = [2400.0 + 400 * math.sin(TAU * 7 * i / SR) for i in range(n)]
    out = scale(mul(bp(noise(rng, dur), center, 1.2), flap), 1.3)
    # Brilho mágico: arpejo pentatônico subindo, com leve chorus.
    scales = ((1174.7, 1480.0, 1760.0, 2349.3), (1318.5, 1568.0, 1975.5, 2637.0),
              (1046.5, 1318.5, 1568.0, 2093.0))
    for i, f in enumerate(scales[v]):
        tone = mix((bell(f, dur * 0.6, 0.18, 0.3), 1.0), (bell(f * 1.004, dur * 0.6, 0.18, 0.2), 0.5))
        place(out, tone, 0.06 + i * 0.07, 0.22)
    shimmer = mul(hp(noise(rng, dur), 7000.0), tone_env(dur, lambda t: math.sin(math.pi * min(t / dur, 1.0)) ** 2))
    return mix((out, 1.0), (shimmer, 0.15)), 0.7


def incense_pulse(rng, v):
    dur = 0.6
    att = 0.07 + 0.01 * v
    env = tone_env(dur, lambda t: (t / att) ** 1.5 if t < att else math.exp(-(t - att) / 0.16))
    puff = mul(lp(noise(rng, dur), 900.0 + 250 * v, 0.8), env)
    breath = mul(bp(noise(rng, dur), 1800.0, 1.0), env)
    out = mix((puff, 1.6), (breath, 0.35))
    place(out, bell((1318.5, 1174.7, 1568.0)[v], dur - att, 0.22, 0.25), att * 0.6, 0.18)
    return out, 0.6


def chest_open(rng, v):
    """Fanfarra de baú: whoomp grave, arpejo maior com timbre de metal/sino e cauda de brilhos."""
    dur = 1.5 + 0.4 * v
    out = zeros(dur)
    # Whoomp suave no começo.
    wl = 0.35
    whoomp = mix((mul(osc(sweep(140.0, 60.0, ns(wl))), exp_env(wl, 0.09, 0.01)), 1.0),
                 (mul(lp(noise(rng, wl), sweep(1500.0, 250.0, ns(wl)), 0.8), exp_env(wl, 0.06, 0.015)), 0.8))
    place(out, whoomp, 0.0, 0.7)
    # Arpejo maior subindo (C5 E5 G5 C6 / G4 B4 D5 G5 B5), timbre de metal: harmônicos com brilho que cai.
    notes = ((523.25, 659.25, 783.99, 1046.5), (392.0, 493.88, 587.33, 783.99, 987.77))[v]
    step = 0.085
    for i, f in enumerate(notes):
        last = i == len(notes) - 1
        nl = (dur - 0.05 - i * step) if last else 0.55
        m = ns(nl)
        tone = [0.0] * m
        for h, amp in ((1, 1.0), (2, 0.55), (3, 0.35), (4, 0.2), (5, 0.12), (6, 0.06)):
            ph = rng.uniform(0, TAU)
            for j in range(m):
                t = j / SR
                bright = math.exp(-t * h / (0.35 if last else 0.18))  # agudos caem mais rápido
                vib = 1.0 + (0.004 * math.sin(TAU * 5.5 * t) * min(1.0, t / 0.15) if last else 0.0)
                tone[j] += amp * bright * math.sin(TAU * f * h * vib * t + ph)
        att = 0.012
        rel = (0.55 if last else 0.16)
        env = tone_env(nl, lambda t: min(1.0, t / att) * math.exp(-t / rel))
        tone = mix((mul(tone, env), 1.0), (bell(f * 2.0, nl, 0.25, 0.3), 0.18))
        place(out, tone, 0.04 + i * step, 0.55 if last else 0.4)
    # Cauda de brilhos: sininhos agudos aleatórios (pentatônica alta) que vão sumindo.
    sparkle = (2093.0, 2349.3, 2637.0, 3136.0, 3520.0, 4186.0)
    start = 0.04 + len(notes) * step
    for k in range(14 + 4 * v):
        at = start + rng.uniform(0.0, dur - start - 0.3)
        g = 0.12 * math.exp(-(at - start) / 0.6) + 0.02
        place(out, bell(rng.choice(sparkle), 0.3, 0.07, 0.35), at, g)
    shimmer = mul(hp(noise(rng, dur), 8000.0),
                  tone_env(dur, lambda t: 0.0 if t < start else math.exp(-(t - start) / 0.4) * min(1.0, (t - start) / 0.05)))
    return mix((out, 1.0), (shimmer, 0.05)), 0.6


RECIPES = {
    "thunder": thunder,
    "zap": zap,
    "chain_zap": chain_zap,
    "hit_blade": hit_blade,
    "hit_projectile": hit_projectile,
    "hit_fire": hit_fire,
    "hit_thunder": hit_thunder,
    "hit_wind": hit_wind,
    "hit_area": hit_area,
    "hit_orbit": hit_orbit,
    "hit_poison": hit_poison,
    "ofuda_cast": ofuda_cast,
    "incense_pulse": incense_pulse,
    "chest_open": chest_open,
}
VARIATIONS = {"chest_open": 2}  # os outros grupos têm 3


def seed_for(name: str, v: int) -> int:
    return BASE_SEED + int(hashlib.sha256(f"{name}_{v}".encode()).hexdigest()[:8], 16)


def update_index(written: list) -> None:
    path = ROOT / "assets" / "asset_index.json"
    index = json.loads(path.read_text(encoding="utf-8"))
    index = [row for row in index if row.get("license_id") != LICENSE_ID]
    for file in written:
        index.append({
            "file": file.relative_to(ROOT).as_posix(),
            "source": "tools/gen_sfx.py",
            "license_id": LICENSE_ID,
            "sha256": hashlib.sha256(file.read_bytes()).hexdigest(),
        })
    index.sort(key=lambda item: item["file"])
    path.write_text(json.dumps(index, indent=1, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for name, fn in RECIPES.items():
        for v in range(VARIATIONS.get(name, 3)):
            raw, peak = fn(random.Random(seed_for(name, v)), v)
            x = finish(raw, peak)
            path = OUT / f"g_{name}_{v}.wav"
            write_wav(path, x)
            written.append(path)
            print(f"{path.relative_to(ROOT).as_posix()}  {len(x) / SR:.3f} s  pico {max(abs(s) for s in x):.2f}")
    update_index(written)
    print(f"{len(written)} arquivos gerados")
    return 0


if __name__ == "__main__":
    sys.exit(main())
