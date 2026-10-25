"""Gera os sons procedurais dos inimigos e chefes (prefixo e_) em assets/audio/sfx/.

Obra original do projeto Hyakki, liberada em CC0-1.0 (entrada `hyakki_enemy_sfx` em
licenses/registry.json). Só biblioteca padrão e sementes fixas: rodar de novo produz os
mesmos bytes. Saída: WAV PCM 16 bits, mono, 44,1 kHz, normalizado sem clipping.

- e_roar_0..2: rugido de chefe (rosnado grave com formantes e ruído áspero);
- e_boss_fall_0: queda do chefe (estrondo grave e longo);
- e_die_{ash,ember,mist,splat,bone}_0..2: mortes de inimigos por estilo.

Também atualiza só as linhas e_* de assets/asset_index.json (hash e origem).
Depois rode o import do Godot para criar os .import.
Uso: python -I tools/gen_enemy_sfx.py
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
LICENSE_ID = "hyakki_enemy_sfx"
PREFIX = "e_"
BASE_SEED = 7313
TAU = 2.0 * math.pi


def ns(seconds: float) -> int:
    return int(seconds * SR)


def lowpass(x: list, cutoff: float) -> list:
    a = math.exp(-TAU * cutoff / SR)
    out, y = [], 0.0
    for s in x:
        y = (1.0 - a) * s + a * y
        out.append(y)
    return out


def highpass(x: list, cutoff: float) -> list:
    low = lowpass(x, cutoff)
    return [s - l for s, l in zip(x, low)]


def bandpass(x: list, lo: float, hi: float) -> list:
    return lowpass(highpass(x, lo), hi)


def env(n: int, attack: float, decay: float) -> list:
    a = max(1, ns(attack))
    return [min(1.0, i / a) * math.exp(-max(0, i - a) / SR / decay) for i in range(n)]


def finish(x: list, peak: float) -> list:
    fade = ns(0.004)
    x = list(x)
    for i in range(min(fade, len(x))):
        x[i] *= i / fade
        x[-1 - i] *= i / fade
    m = max(abs(s) for s in x) or 1.0
    return [max(-1.0, min(1.0, s * peak / m)) for s in x]


def roar(rng: random.Random, v: int) -> tuple:
    dur = 1.25 + 0.15 * v
    n = ns(dur)
    base = 62.0 + 9.0 * v
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        k = t / dur
        # Sobe, sustenta e cai; vibrato lento + tremor áspero.
        f = base * (1.0 + 0.35 * math.sin(math.pi * min(1.0, k * 1.3))) * (1.0 + 0.03 * math.sin(TAU * 6.5 * t))
        phase += TAU * f / SR
        saw = (phase / TAU) % 1.0 * 2.0 - 1.0
        out.append(saw + 0.4 * math.sin(phase * 2.0) + 0.6 * rng.uniform(-1.0, 1.0))
    # Formantes de garganta (boca aberta "ahh") e rosnado.
    voiced = [a * 0.6 + b for a, b in zip(bandpass(out, 300.0, 900.0), bandpass(out, 90.0, 400.0))]
    grit = bandpass([rng.uniform(-1.0, 1.0) for _ in range(n)], 600.0, 2400.0)
    e = env(n, 0.12, dur * 0.45)
    x = [(a + 0.35 * g * (0.5 + 0.5 * math.sin(TAU * 31.0 * i / SR))) * w for i, (a, g, w) in
         enumerate(zip(voiced, grit, e))]
    return x, 0.95


def boss_fall(rng: random.Random, v: int) -> tuple:
    dur = 2.2
    n = ns(dur)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    rumble = lowpass(lowpass(noise, 120.0), 160.0)
    out = []
    for i in range(n):
        t = i / SR
        boom = math.sin(TAU * (48.0 - 18.0 * min(1.0, t / 1.5)) * t) * math.exp(-t / 0.7)
        out.append(boom * 0.9 + rumble[i] * 6.0 * math.exp(-t / 0.9))
    crack = highpass(noise, 1500.0)
    e = env(n, 0.002, 0.08)
    x = [a + 0.5 * c * w for a, c, w in zip(out, crack, e)]
    return x, 0.95


def die_ash(rng, v):
    dur = 0.32 + 0.04 * v
    n = ns(dur)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    puff = bandpass(noise, 400.0 + 120 * v, 2600.0)
    e = env(n, 0.006, 0.09)
    thump = [math.sin(TAU * (140.0 - 60.0 * i / n) * i / SR) * math.exp(-i / SR / 0.05) for i in range(n)]
    return [p * w + 0.7 * t for p, w, t in zip(puff, e, thump)], 0.7


def die_ember(rng, v):
    dur = 0.45 + 0.05 * v
    n = ns(dur)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    whoosh = bandpass(noise, 200.0, 1800.0)
    out = [w * math.exp(-i / SR / 0.15) for i, w in enumerate(whoosh)]
    # Estalos de brasa.
    for _ in range(9 + 3 * v):
        at = rng.randrange(0, n - ns(0.01))
        amp = rng.uniform(0.4, 1.0)
        for j in range(ns(0.004)):
            out[at + j] += amp * rng.uniform(-1.0, 1.0) * (1.0 - j / ns(0.004))
    boom = [math.sin(TAU * 85.0 * i / SR) * math.exp(-i / SR / 0.07) for i in range(n)]
    return [a + 0.8 * b for a, b in zip(out, boom)], 0.75


def die_mist(rng, v):
    dur = 0.6 + 0.08 * v
    n = ns(dur)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    breath = bandpass(noise, 900.0, 3500.0)
    out = []
    for i in range(n):
        t = i / SR
        f = (660.0 + 110.0 * v) * (1.0 - 0.35 * t / dur)
        tone = math.sin(TAU * f * t) * 0.35 + math.sin(TAU * f * 1.5 * t) * 0.15
        w = math.sin(math.pi * min(1.0, t / dur)) ** 1.5
        out.append((breath[i] * 0.8 + tone) * w)
    return out, 0.6


def die_splat(rng, v):
    dur = 0.3 + 0.03 * v
    n = ns(dur)
    out = []
    for i in range(n):
        t = i / SR
        f = 420.0 * (1.0 + v * 0.15) * math.exp(-t / 0.05) + 120.0
        out.append(math.sin(TAU * f * t) * math.exp(-t / 0.08))
    noise = lowpass([rng.uniform(-1.0, 1.0) for _ in range(n)], 1800.0)
    e = env(n, 0.002, 0.06)
    return [a + 0.6 * b * w for a, b, w in zip(out, noise, e)], 0.75


def die_bone(rng, v):
    dur = 0.4
    n = ns(dur)
    out = [0.0] * n
    # Três ou quatro estalos secos de madeira/osso caindo.
    at = 0
    for k in range(3 + v % 2):
        f = rng.uniform(900.0, 1700.0)
        for j in range(ns(0.05)):
            if at + j >= n:
                break
            t = j / SR
            out[at + j] += math.sin(TAU * f * t) * math.exp(-t / 0.012) * (1.0 - 0.2 * k)
        at += ns(rng.uniform(0.05, 0.09))
    noise = highpass([rng.uniform(-1.0, 1.0) for _ in range(n)], 2000.0)
    e = env(n, 0.001, 0.02)
    return [a + 0.4 * b * w for a, b, w in zip(out, noise, e)], 0.7


RECIPES = {"roar": (roar, 3), "boss_fall": (boss_fall, 1), "die_ash": (die_ash, 3), "die_ember": (die_ember, 3),
           "die_mist": (die_mist, 3), "die_splat": (die_splat, 3), "die_bone": (die_bone, 3)}


def write_wav(path: pathlib.Path, x: list) -> None:
    data = struct.pack("<%dh" % len(x), *(int(round(s * 32767.0)) for s in x))
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def update_index(written: list) -> None:
    path = ROOT / "assets" / "asset_index.json"
    index = json.loads(path.read_text(encoding="utf-8"))
    index = [row for row in index if row.get("license_id") != LICENSE_ID]
    for file in written:
        index.append({
            "file": file.relative_to(ROOT).as_posix(),
            "source": "tools/gen_enemy_sfx.py",
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
            seed = BASE_SEED + int(hashlib.sha256(f"{name}_{v}".encode()).hexdigest()[:8], 16)
            raw, peak = fn(random.Random(seed), v)
            x = finish(raw, peak)
            path = OUT / f"{PREFIX}{name}_{v}.wav"
            write_wav(path, x)
            written.append(path)
            print(f"{path.relative_to(ROOT).as_posix()}  {len(x) / SR:.3f} s")
    update_index(written)
    print(f"{len(written)} arquivos gerados")
    return 0


if __name__ == "__main__":
    sys.exit(main())
