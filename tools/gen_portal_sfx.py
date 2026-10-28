"""Gera os sons procedurais do portal do 隠世 (Kakuriyo) e do chefe intermediário (prefixo p_).

Obra original do projeto Hyakki, liberada em CC0-1.0 (entrada `hyakki_portal_sfx` em
licenses/registry.json). Só biblioteca padrão e sementes fixas: rodar de novo produz os
mesmos bytes. Saída: WAV PCM 16 bits, mono, 44,1 kHz, normalizado sem clipping.

- p_portal_hum: zumbido do portal, 4 s em loop perfeito (só senoides com número inteiro de
  ciclos em 4 s: o fim emenda no começo sem estalo). Marque loop no .import;
- p_portal_open_0..1: abertura do portal (brilho que sobe, sopro e sininhos);
- p_teleport_0..1: a guardiã atravessando (sopro que suga, varredura para cima, corte);
- p_midboss_roar_0..2: rugido do chefe intermediário (duas gargantas e um eco agudo
  fantasmagórico, mais longo que o e_roar);
- p_midboss_intro_0: aviso da chegada do chefe intermediário (estrondo de taiko grave e
  drone que cresce).

Também atualiza só as linhas p_* de assets/asset_index.json (hash e origem).
Depois rode o import do Godot para criar os .import.
Uso: python -I tools/gen_portal_sfx.py
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
LICENSE_ID = "hyakki_portal_sfx"
PREFIX = "p_"
BASE_SEED = 4507
TAU = 2.0 * math.pi
HUM_SECONDS = 4.0


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


def finish(x: list, peak: float, fade: bool = True) -> list:
    x = list(x)
    if fade:
        f = ns(0.004)
        for i in range(min(f, len(x))):
            x[i] *= i / f
            x[-1 - i] *= i / f
    m = max(abs(s) for s in x) or 1.0
    return [max(-1.0, min(1.0, s * peak / m)) for s in x]


def bell(n: int, at: int, f: float, amp: float, decay: float, out: list) -> None:
    """Sininho (parciais inarmônicas de suzu) somado em out a partir de `at`."""
    for j in range(min(n - at, ns(decay * 5.0))):
        t = j / SR
        e = amp * math.exp(-t / decay)
        out[at + j] += e * (math.sin(TAU * f * t) + 0.5 * math.sin(TAU * f * 2.76 * t)
                            + 0.25 * math.sin(TAU * f * 5.4 * t))


def portal_hum(rng: random.Random, v: int) -> tuple:
    n = ns(HUM_SECONDS)

    def cyc(freq: float) -> float:
        # Arredonda a frequência para um número inteiro de ciclos no loop.
        return round(freq * HUM_SECONDS) / HUM_SECONDS

    drones = [(cyc(55.0), 1.0), (cyc(82.5), 0.55), (cyc(110.25), 0.45), (cyc(165.5), 0.22)]
    # "Ar" que respira: 48 parciais de 300 a 1800 Hz, todas com ciclos inteiros.
    air = [(cyc(rng.uniform(300.0, 1800.0)), rng.uniform(0.0, TAU), rng.uniform(0.2, 1.0)) for _ in range(48)]
    shimmer = [(cyc(f), rng.uniform(0.0, TAU)) for f in (1318.5, 1567.75, 1975.5)]
    lfo = 1.0 / HUM_SECONDS  # 1 ciclo de respiração por loop
    out = []
    for i in range(n):
        t = i / SR
        breath = 0.65 + 0.35 * math.sin(TAU * lfo * t)
        x = sum(a * math.sin(TAU * f * t + 0.6 * math.sin(TAU * 2.0 * lfo * t)) for f, a in drones)
        x += 0.018 * breath * sum(a * math.sin(TAU * f * t + p) for f, p, a in air)
        x += 0.06 * (0.5 + 0.5 * math.sin(TAU * 4.0 * lfo * t)) * sum(math.sin(TAU * f * t + p) for f, p in shimmer)
        out.append(x * (0.85 + 0.15 * breath))
    return out, 0.6, False


def portal_open(rng: random.Random, v: int) -> tuple:
    dur = 1.7
    n = ns(dur)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    swell = bandpass(noise, 500.0, 3000.0)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        k = t / dur
        f = (180.0 + 40.0 * v) * (1.0 + 3.0 * (1.0 - math.exp(-k * 4.0)))
        phase += TAU * f / SR
        tone = math.sin(phase) * 0.5 + math.sin(phase * 1.5) * 0.25
        w = math.sin(math.pi * min(1.0, k * 1.15)) ** 1.2
        out.append((tone + 0.7 * swell[i]) * w)
    # Sininhos de suzu que acendem quando o portal termina de abrir.
    for j, f in enumerate((1318.5, 1760.0, 2093.0, 2637.0)):
        bell(n, ns(0.55 + 0.11 * j + 0.03 * v), f * (1.0 + 0.02 * v), 0.35, 0.22, out)
    boom = [math.sin(TAU * 70.0 * i / SR) * math.exp(-i / SR / 0.35) * 0.5 for i in range(n)]
    return [a + b for a, b in zip(out, boom)], 0.85, True


def teleport(rng: random.Random, v: int) -> tuple:
    dur = 0.95 + 0.1 * v
    n = ns(dur)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    hiss = bandpass(noise, 700.0, 5000.0)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        k = t / dur
        # Sopro "ao contrário": cresce até 75% e corta seco, com varredura para cima.
        w = (k / 0.75) ** 2.2 if k < 0.75 else math.exp(-(k - 0.75) * dur / 0.04)
        f = (220.0 + 60.0 * v) * 2.0 ** (3.0 * min(1.0, k / 0.75))
        phase += TAU * f / SR
        out.append((0.8 * hiss[i] + 0.45 * math.sin(phase) + 0.2 * math.sin(phase * 2.01)) * w)
    # Estalo de chegada.
    pop_at = ns(dur * 0.75)
    for j in range(min(n - pop_at, ns(0.12))):
        t = j / SR
        out[pop_at + j] += 0.9 * math.sin(TAU * 95.0 * t) * math.exp(-t / 0.05)
    bell(n, pop_at, 2349.0 + 200.0 * v, 0.25, 0.12, out)
    return out, 0.85, True


def midboss_roar(rng: random.Random, v: int) -> tuple:
    dur = 1.7 + 0.15 * v
    n = ns(dur)
    voices = []
    for base in (54.0 + 7.0 * v, 81.0 + 9.0 * v):
        sig = []
        phase = 0.0
        for i in range(n):
            t = i / SR
            k = t / dur
            f = base * (1.0 + 0.4 * math.sin(math.pi * min(1.0, k * 1.25))) * (1.0 + 0.035 * math.sin(TAU * 5.5 * t))
            phase += TAU * f / SR
            saw = (phase / TAU) % 1.0 * 2.0 - 1.0
            sig.append(saw + 0.4 * math.sin(phase * 2.0) + 0.55 * rng.uniform(-1.0, 1.0))
        voices.append(sig)
    raw = [a + 0.7 * b for a, b in zip(*voices)]
    voiced = [a * 0.6 + b for a, b in zip(bandpass(raw, 280.0, 950.0), bandpass(raw, 80.0, 380.0))]
    grit = bandpass([rng.uniform(-1.0, 1.0) for _ in range(n)], 700.0, 2600.0)
    # Eco agudo fantasmagórico (o yōkai "canta" por cima do rosnado).
    ghost = [math.sin(TAU * (520.0 + 60.0 * v) * (1.0 - 0.25 * i / n) * i / SR) for i in range(n)]
    e = env(n, 0.15, dur * 0.5)
    ge = [math.sin(math.pi * min(1.0, i / n * 1.4)) ** 2 for i in range(n)]
    x = [(a + 0.35 * g * (0.5 + 0.5 * math.sin(TAU * 27.0 * i / SR))) * w + 0.12 * h * q for i, (a, g, w, h, q) in
         enumerate(zip(voiced, grit, e, ghost, ge))]
    return x, 0.95, True


def midboss_intro(rng: random.Random, v: int) -> tuple:
    dur = 2.6
    n = ns(dur)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    rumble = lowpass(lowpass(noise, 140.0), 180.0)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        k = t / dur
        # Dois golpes de taiko grave (0 s e 0,45 s) e um drone que cresce até o fim.
        hit = math.sin(TAU * (75.0 - 30.0 * min(1.0, t / 0.4)) * t) * math.exp(-t / 0.35)
        t2 = t - 0.45
        hit2 = math.sin(TAU * (68.0 - 25.0 * min(1.0, t2 / 0.4)) * t2) * math.exp(-t2 / 0.45) if t2 > 0 else 0.0
        f = 58.0 * (1.0 + 0.5 * k)
        phase += TAU * f / SR
        drone = (math.sin(phase) + 0.5 * math.sin(phase * 1.5) + 0.3 * math.sin(phase * 2.0)) * k ** 1.5
        out.append(hit + 0.9 * hit2 + 0.45 * drone + rumble[i] * 5.0 * k)
    skin = highpass(noise, 1800.0)
    e1 = env(n, 0.001, 0.03)
    x = [a + 0.35 * s * w for a, s, w in zip(out, skin, e1)]
    tail = ns(0.25)
    for i in range(tail):
        x[-1 - i] *= i / tail
    return x, 0.95, True


RECIPES = {"portal_hum": (portal_hum, 1), "portal_open": (portal_open, 2), "teleport": (teleport, 2),
           "midboss_roar": (midboss_roar, 3), "midboss_intro": (midboss_intro, 1)}
# O loop não leva sufixo de variação: é tocado pelo nome direto.
SINGLE = {"portal_hum"}


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
            "source": "tools/gen_portal_sfx.py",
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
            raw, peak, fade = fn(random.Random(seed), v)
            x = finish(raw, peak, fade)
            stem = name if name in SINGLE else f"{name}_{v}"
            path = OUT / f"{PREFIX}{stem}.wav"
            write_wav(path, x)
            written.append(path)
            print(f"{path.relative_to(ROOT).as_posix()}  {len(x) / SR:.3f} s")
    update_index(written)
    print(f"{len(written)} arquivos gerados")
    return 0


if __name__ == "__main__":
    sys.exit(main())
