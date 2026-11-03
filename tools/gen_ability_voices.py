"""Gera as vozes dos guardiões ao soltar as habilidades (assets/audio/voice/<herói>_<n>.ogg).

São gritos de combate sem palavras (kiai, "Ha!", rosnados), então servem nos 11 idiomas.
Fontes (CC0, baixadas para C:/src/assets, com SHA256SUMS.txt e a página de origem):
- `cicifyre_rpg_voice`: "Female RPG Voice Starter Pack" (cicifyre, OpenGameArt, CC0) para
  Aki (Type 1), Hana (Type 2), Rin e Yuki (Type 3);
- `haeldb_yelling`: "Male grunt/yelling sounds" (HaelDB, OpenGameArt, CC0 escolhida entre
  OGA-BY 3.0 e CC0) para Kenta (vocalista 1), Goro (vocalista 3) e Tora (vocalista 4).
O "Om" do Mantra do Mestre (goro_3) é sintetizado aqui (formantes; obra original do projeto,
CC0, entrada `hyakki_ability_sfx`), sem gravação de terceiros.

Tratamento por personagem (cadeia em `process`): corte do silêncio, mudança de tom por
reamostragem (Goro e Tora mais graves), filtros, rouquidão (saturação em banda e "fry" em
modulação de amplitude, Tora), camada de rosnado sintetizado (Yuki), sopro de ar (Kenta),
reverberação curta de templo (Hana e Goro), fades e pico normalizado em -1 dBFS.
Saída: Ogg Vorbis mono 44,1 kHz. Sementes fixas: o áudio é o mesmo a cada execução (o número
de série do Ogg muda, então o hash do arquivo pode mudar; o índice é atualizado aqui).

Precisa de numpy, scipy e soundfile (fora da biblioteca padrão): rode sem -I, mas sem pôr a
pasta do script nem a atual no caminho de importação:
    python -E -P tools/gen_ability_voices.py
Atualiza as linhas assets/audio/voice/* de assets/asset_index.json. Depois rode o import do
Godot para criar os .import.
"""
import hashlib
import json
import pathlib
import sys
from fractions import Fraction

import numpy as np
import soundfile as sf
from scipy import signal

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio" / "voice"
SR = 44100
LOUD_DB = -10.0  # janela de 50 ms mais forte (volume percebido parecido entre vozes)
PEAK_DB = -1.2  # o Vorbis passa um pouco do pico: o arquivo decodificado fica perto de -1 dBFS
SOURCE = "tools/gen_ability_voices.py"
PACKS = {
    "cicifyre_rpg_voice": pathlib.Path("C:/src/assets/cicifyre-rpg-voice/pack/RPG Voice Starter Pack"),
    "haeldb_yelling": pathlib.Path("C:/src/assets/haeldb-yelling/pack/yelling sounds"),
}
SYNTH_LICENSE = "hyakki_ability_sfx"

# Perfis de cada personagem (aplicados a todas as falas dele, com ajustes por fala).
HERO = {
    # Jovem guardiã: firme e luminosa. Voz natural, presença em 3 kHz, sala pequena.
    "aki": {"pack": "cicifyre_rpg_voice", "pitch": -0.5, "hp": 140, "lp": 12000,
            "eq": [(3000, 2.5, 1.0), (250, -2.0, 1.0)], "room": (0.35, -20.0)},
    # Ninja: seco, ar curto; sopro de ar no ataque, sem reverberação, corte curto.
    "kenta": {"pack": "haeldb_yelling", "pitch": -1.0, "hp": 180, "lp": 9000,
              "eq": [(2200, 2.0, 1.2), (400, -3.0, 1.0)], "breath": 0.22, "max": 0.42},
    # Miko: serena; "Ha!" de purificação com reverberação de santuário.
    "hana": {"pack": "cicifyre_rpg_voice", "pitch": -1.0, "hp": 150, "lp": 10000,
             "eq": [(5000, 1.5, 0.8), (1200, -1.5, 1.0)], "room": (1.0, -11.0)},
    # Monge: grave, encorpado, templo de pedra.
    "goro": {"pack": "haeldb_yelling", "pitch": -3.0, "hp": 70, "lp": 7500,
             "eq": [(140, 3.0, 0.9), (2500, -2.0, 1.0)], "room": (1.3, -12.0), "drive": 0.25},
    # Caçadora: ríspida e rápida; seca, com estalo no ataque.
    "rin": {"pack": "cicifyre_rpg_voice", "pitch": 0.0, "hp": 200, "lp": 11000,
            "eq": [(2800, 3.0, 1.2), (300, -3.0, 1.0)], "room": (0.25, -24.0), "max": 0.45},
    # Ferreiro de 70 anos: rouco e potente.
    "tora": {"pack": "haeldb_yelling", "pitch": -3.0, "hp": 60, "lp": 7000,
             "eq": [(120, 3.5, 0.9), (1800, 2.5, 1.0)], "rasp": 0.55, "fry": 0.3, "drive": 0.5,
             "room": (0.5, -20.0)},
    # Meio-oni: voz feminina mais grave com rosnado sintetizado por baixo.
    "yuki": {"pack": "cicifyre_rpg_voice", "pitch": -2.5, "hp": 80, "lp": 9000,
             "eq": [(200, 2.5, 0.9), (2500, 2.0, 1.0)], "growl": 0.7, "drive": 0.35,
             "room": (0.4, -20.0)},
}

# Fala de cada habilidade: arquivo de origem (relativo ao pacote) e ajustes.
LINES = {
    "aki_1": ("Type 1/attack2.wav", {}),          # Passo da Aurora
    "aki_1_b": ("Type 1/attack1.wav", {}),
    "aki_2": ("Type 1/jump2.wav", {"pitch": -1.0, "room": (0.6, -16.0)}),   # Muralha da Lanterna
    "aki_3": ("Type 1/attack3.wav", {"pitch": -1.5, "drive": 0.25, "room": (0.8, -14.0)}),  # Cem Anos
    "kenta_1": ("1yell9.wav", {}),                 # Passo Sombrio
    "kenta_1_b": ("1yell15.wav", {}),
    "kenta_2": ("1yell16.wav", {"breath": 0.35}),  # Troca de Corpo
    "kenta_3": ("1yell7.wav", {"max": 0.5}),      # Chuva de Makibishi
    "hana_1": ("Type 2/attack1.wav", {}),          # Purificação ("Ha!")
    "hana_1_b": ("Type 2/attack3.wav", {}),
    "hana_2": ("Type 2/jump3.wav", {"pitch": -1.5, "room": (1.2, -9.0)}),    # Kekkai
    "hana_3": ("Type 2/attack2.wav", {"pitch": -1.5, "room": (1.4, -8.0)}),  # Selo da Avó
    "goro_1": ("3grunt5.wav", {"room": (0.8, -14.0)}),                 # Corpo de Diamante
    "goro_1_b": ("3grunt3.wav", {"max": 0.75, "room": (0.8, -14.0)}),
    "goro_2": ("3yell4.wav", {"pitch": -2.5}),     # Golpe do Shakujō
    "goro_3": (None, {}),                          # Mantra do Mestre: "Om" sintetizado
    "rin_1": ("Type 3/attack1.wav", {}),           # Hamaya
    "rin_1_b": ("Type 3/jump1.wav", {}),
    "rin_2": ("Type 3/attack2.wav", {}),           # Armadilha de Caça
    "rin_3": ("Type 3/jump3.wav", {"pitch": 0.5}),  # Salto da Andorinha
    "tora_1": ("yell12.wav", {"max": 0.7}),        # Martelo na Bigorna
    "tora_1_b": ("yell13.wav", {"max": 0.7}),
    "tora_2": ("yell7.wav", {"pitch": -2.0, "max": 0.8}),   # Corrente Puxadora
    "tora_3": ("yell3.wav", {"pitch": -2.0, "max": 1.0, "room": (0.9, -15.0)}),  # Têmpera
    "yuki_1": ("Type 3/attack3.wav", {}),          # Garra Oni
    "yuki_1_b": ("Type 3/jump2.wav", {}),
    "yuki_2": ("Type 3/damaged1.wav", {"pitch": -4.0, "growl": 1.4, "roar": 0.9,
                                       "room": (0.9, -14.0)}),   # Rugido Oni
    "yuki_3": ("Type 3/damaged3.wav", {"pitch": -3.0, "growl": 1.0}),  # Redemoinho Onikiri
}


# --- Blocos -------------------------------------------------------------------------

def seed_for(name: str) -> int:
    return int(hashlib.sha256(name.encode()).hexdigest()[:8], 16)


def load(path: pathlib.Path) -> np.ndarray:
    x, sr = sf.read(str(path), always_2d=True, dtype="float64")
    x = x.mean(axis=1)
    if sr != SR:
        frac = Fraction(SR, sr).limit_denominator(1000)
        x = signal.resample_poly(x, frac.numerator, frac.denominator)
    return x - x.mean()


def trim(x: np.ndarray, start_db: float = -30.0, end_db: float = -42.0) -> np.ndarray:
    """Tira o silêncio das pontas (5 ms de folga antes do ataque)."""
    a = np.abs(x)
    peak = a.max() or 1.0
    on = np.where(a > peak * 10 ** (start_db / 20))[0]
    off = np.where(a > peak * 10 ** (end_db / 20))[0]
    i0 = max(0, on[0] - int(0.005 * SR))
    i1 = min(len(x), off[-1] + int(0.01 * SR))
    return x[i0:i1]


def tape_pitch(x: np.ndarray, semitones: float) -> np.ndarray:
    """Muda o tom reamostrando (como fita): mais grave fica também um pouco mais lento."""
    if abs(semitones) < 1e-6:
        return x
    ratio = Fraction(2 ** (-semitones / 12.0)).limit_denominator(400)
    return signal.resample_poly(x, ratio.numerator, ratio.denominator)


def butter(x: np.ndarray, cutoff: float, kind: str, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, cutoff, kind, fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def peq(x: np.ndarray, freq: float, gain_db: float, q: float) -> np.ndarray:
    """Equalizador paramétrico (RBJ peaking)."""
    a_ = 10 ** (gain_db / 40)
    w = 2 * np.pi * freq / SR
    alpha = np.sin(w) / (2 * q)
    b = [1 + alpha * a_, -2 * np.cos(w), 1 - alpha * a_]
    a = [1 + alpha / a_, -2 * np.cos(w), 1 - alpha / a_]
    return signal.lfilter(np.array(b) / a[0], np.array(a) / a[0], x)


def envelope(x: np.ndarray, ms: float = 12.0) -> np.ndarray:
    n = max(1, int(ms * 0.001 * SR))
    e = np.convolve(np.abs(x), np.ones(n) / n, mode="same")
    return e / (e.max() or 1.0)


def drive(x: np.ndarray, amount: float) -> np.ndarray:
    """Saturação suave (tanh) misturada em paralelo: corpo sem clipping."""
    if amount <= 0:
        return x
    m = np.abs(x).max() or 1.0
    sat = np.tanh(x / m * (1 + 4 * amount)) * m
    return x * (1 - 0.5 * amount) + sat * 0.5 * amount


def rasp(x: np.ndarray, amount: float, fry: float, rng: np.random.Generator) -> np.ndarray:
    """Rouquidão: banda média saturada forte + "fry" (pulsos irregulares de ~70 Hz)."""
    if amount <= 0 and fry <= 0:
        return x
    m = np.abs(x).max() or 1.0
    band = butter(butter(x, 700, "highpass"), 4000, "lowpass")
    dirty = np.tanh(band / m * 8.0) * m * 0.5
    n = len(x)
    # Frequência do fry com deriva aleatória (voz velha), pulsos estreitos.
    drift = signal.lfilter([0.002], [1, -0.998], rng.normal(0, 1, n))
    f = 68 * (1 + 0.12 * drift / (np.abs(drift).max() or 1.0))
    phase = np.cumsum(f / SR)
    pulses = 0.5 + 0.5 * np.cos(2 * np.pi * phase)
    am = 1.0 - fry + fry * pulses ** 3
    return (x + amount * dirty) * am


def rough_throat(n: int, f0: float, rng: np.random.Generator) -> np.ndarray:
    """Garganta de fera: pulsos glotais graves com jitter forte e dobra de período (o "rrr"
    áspero de um rugido), por formantes de vogal aberta, com um pouco de ruído de ar."""
    t = np.arange(n) / SR
    wander = signal.lfilter([0.003], [1, -0.997], rng.normal(0, 1, n))
    f = f0 * (1 + 0.18 * wander / (np.abs(wander).max() or 1.0)) * (1 + 0.06 * np.exp(-t / 0.08))
    src = glottal(f, rng, tilt=0.9, jitter=0.05)
    half = np.cumsum(f / 2 / SR)
    src *= 1 + 0.6 * np.sign(np.sin(2 * np.pi * half))  # dobra de período: aspereza
    src += 0.35 * signal.lfilter([1], [1, -0.9], rng.normal(0, 1, n)) / 6
    out = src
    for fr, bw in ((420, 110), (950, 150), (2300, 260)):
        out = resonator(out, fr, bw)
    return out / (np.abs(out).max() or 1.0)


def growl_layer(x: np.ndarray, amount: float, rng: np.random.Generator, roar: float = 0.0) -> np.ndarray:
    """Rosnado oni: a mesma voz uma oitava abaixo e uma garganta de fera sintetizada (aspereza
    grave) que segue o envelope da voz; `roar` soma uma cauda de rugido depois da voz."""
    if amount <= 0:
        return x
    n = len(x)
    low = tape_pitch(x, -12.0)[:n]
    low = np.pad(low, (0, n - len(low)))
    m = np.abs(x).max() or 1.0
    low = low / (np.abs(low).max() or 1.0) * m
    throat = rough_throat(n, 82.0, rng) * envelope(x, 25) ** 0.8 * m
    out = x + amount * 0.45 * low + amount * 0.35 * throat
    if roar > 0:
        tail_n = int(0.65 * SR)
        tn = np.arange(tail_n) / SR
        r = rough_throat(tail_n, 64.0, rng)
        r *= np.minimum(1, tn / 0.06) * np.exp(-tn / 0.28)
        start = int(n * 0.4)
        out = np.pad(out, (0, max(0, start + tail_n - len(out))))
        out[start:start + tail_n] += r * m * roar
    return out


def breath_layer(x: np.ndarray, amount: float, rng: np.random.Generator) -> np.ndarray:
    """Sopro de ar no ataque (ninja): ruído agudo curto antes e durante a fala."""
    if amount <= 0:
        return x
    lead = int(0.03 * SR)
    n = len(x) + lead
    noise_ = butter(butter(rng.normal(0, 1, n), 1800, "highpass"), 9000, "lowpass")
    t = np.arange(n) / SR
    env = np.minimum(1, t / 0.02) * np.exp(-np.maximum(0, t - 0.02) / 0.06)
    m = np.abs(x).max() or 1.0
    noise_ = noise_ * env / (np.abs(noise_).max() or 1.0) * m * amount
    return np.pad(x, (lead, 0)) + noise_


def room(x: np.ndarray, rt60: float, wet_db: float, rng: np.random.Generator) -> np.ndarray:
    """Reverberação de convolução com resposta sintética (templo de madeira e pedra): reflexos
    iniciais esparsos e cauda de ruído que escurece com o tempo."""
    if rt60 <= 0:
        return x
    n = int(rt60 * 1.2 * SR)
    t = np.arange(n) / SR
    tail = rng.normal(0, 1, n) * np.exp(-6.9 * t / rt60)
    bright = butter(tail, 6000, "lowpass")
    dark = butter(tail, 1500, "lowpass")
    mixw = np.exp(-t / (rt60 * 0.3))
    ir = bright * mixw + dark * (1 - mixw)
    ir[: int(0.012 * SR)] = 0  # pré-atraso
    for d, g in ((0.013, 0.5), (0.021, -0.35), (0.029, 0.3), (0.041, -0.22), (0.057, 0.16)):
        ir[int(d * SR)] += g * 4
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = signal.fftconvolve(x, ir)
    wet = butter(wet, 180, "highpass")
    wet *= (np.abs(x).max() or 1.0) / (np.abs(wet).max() or 1.0) * 10 ** (wet_db / 20)
    out = np.pad(x, (0, len(wet) - len(x))) + wet
    return out


def finish(x: np.ndarray, max_len: float) -> np.ndarray:
    x = trim(x, -34.0, -46.0)
    max_n = int(max_len * SR)
    if len(x) > max_n:
        x = x[:max_n]
        fo = int(0.09 * SR)
        x[-fo:] *= np.linspace(1, 0, fo) ** 2
    fi = int(0.003 * SR)
    x[:fi] *= np.linspace(0, 1, fi)
    fo = int(0.012 * SR)
    x[-fo:] *= np.linspace(1, 0, fo)
    x = butter(x, 30, "highpass")
    # Mesmo volume percebido entre os guardiões: a janela de 50 ms mais forte vai a
    # LOUD_DB; um limitador (ataque 1 ms, soltura 60 ms) segura o pico em PEAK_DB.
    w = int(0.05 * SR)
    loud = max(np.sqrt(np.mean(x[i:i + w] ** 2)) for i in range(0, max(1, len(x) - w), w // 2))
    x = x * 10 ** (LOUD_DB / 20) / (loud or 1.0)
    return limit(x, 10 ** (PEAK_DB / 20))


def limit(x: np.ndarray, ceiling: float) -> np.ndarray:
    need = np.minimum(1.0, ceiling / np.maximum(np.abs(x), 1e-9))
    # Mínimo adiantado (olha 1 ms à frente) e soltura exponencial.
    look = int(0.001 * SR)
    ahead = np.array([need[i:i + look + 1].min() for i in range(len(need))])
    rel = np.exp(-1.0 / (0.06 * SR))
    gain = np.empty_like(ahead)
    g = 1.0
    for i, target in enumerate(ahead):
        g = target if target < g else target + (g - target) * rel
        gain[i] = g
    return np.clip(x * gain, -ceiling, ceiling)


# --- "Om" sintetizado (Goro, Mantra do Mestre) ---------------------------------------

def resonator(x: np.ndarray, freq: float, bw: float) -> np.ndarray:
    """Formante (polo duplo) com ganho 1 em DC, para síntese em cascata."""
    r = np.exp(-np.pi * bw / SR)
    c = -2 * r * np.cos(2 * np.pi * freq / SR)
    return signal.lfilter([1 + c + r * r], [1, c, r * r], x)


def antiresonator(x: np.ndarray, freq: float, bw: float) -> np.ndarray:
    r = np.exp(-np.pi * bw / SR)
    c = -2 * r * np.cos(2 * np.pi * freq / SR)
    g = 1 + c + r * r
    return signal.lfilter(np.array([1, c, r * r]) / g, [1], x)


def glottal(f0: np.ndarray, rng: np.random.Generator, tilt: float = 1.15,
            jitter: float = 0.004) -> np.ndarray:
    """Fonte glotal aditiva (harmônicos até 5 kHz com queda espectral), com jitter e shimmer."""
    n = len(f0)
    jit = signal.lfilter([0.02], [1, -0.98], rng.normal(0, 1, n))
    jit = 1 + jitter * jit / (np.abs(jit).max() or 1.0)
    phase = 2 * np.pi * np.cumsum(f0 * jit / SR)
    out = np.zeros(n)
    kmax = max(1, int(5000 / f0.max()))
    for k in range(1, kmax + 1):
        out += np.sin(k * phase + 0.3 * k) / k ** tilt
    shimmer = 1 + 0.05 * signal.lfilter([0.01], [1, -0.99], rng.normal(0, 1, n)) * 10
    return out * shimmer


def om(rng: np.random.Generator) -> np.ndarray:
    dur = 1.05
    n = int(dur * SR)
    t = np.arange(n) / SR
    voices = []
    for detune, gain, base in ((1.0, 1.0, 98.0), (1.0045, 0.7, 98.0), (1.0, 0.25, 49.0)):
        f0 = base * detune * (1 + 0.004 * np.sin(2 * np.pi * 4.6 * t + rng.uniform(0, 6.28)))
        f0 *= 1 + 0.02 * np.exp(-t / 0.05)  # leve subida no ataque, que assenta
        voices.append(gain * glottal(f0, rng, jitter=0.012))
    src = sum(voices)
    src += 0.015 * butter(rng.normal(0, 1, n), 1500, "highpass")  # ar na voz
    # Vogal "o" (cascata F1..F4) e nasal "m" (murmúrio grave com antiformante).
    o = src
    for f, bw in ((480, 70), (820, 90), (2600, 160), (3300, 200)):
        o = resonator(o, f, bw)
    m = src
    for f, bw in ((260, 50), (1150, 140), (2300, 250)):
        m = resonator(m, f, bw)
    m = butter(antiresonator(m, 900, 120), 1600, "lowpass")
    o /= np.abs(o).max()
    m /= np.abs(m).max()
    xfade = np.clip((t - 0.52) / 0.14, 0, 1)
    x = o * (1 - xfade) + 0.8 * m * xfade
    env = np.minimum(1, t / 0.07) * np.clip((dur - t) / 0.28, 0, 1) ** 1.5
    x *= env
    # Ataque: "Hm" curto de quem puxa o ar (sopro grave).
    breath = butter(butter(rng.normal(0, 1, int(0.06 * SR)), 300, "highpass"), 2500, "lowpass")
    breath *= np.hanning(len(breath)) * 0.08
    x = np.concatenate([breath, x])
    x = peq(x, 120, 3.0, 0.8)
    return room(x, 1.6, -7.0, rng)


# --- Montagem ----------------------------------------------------------------------

def process(name: str, src: str | None, opts: dict) -> tuple[np.ndarray, str]:
    hero = name.split("_")[0]
    p = {**HERO[hero], **opts}
    rng = np.random.default_rng(seed_for(name))
    if src is None:
        return finish(om(rng), 1.25), SYNTH_LICENSE
    x = trim(load(PACKS[p["pack"]] / src))
    x = tape_pitch(x, p.get("pitch", 0.0))
    x = butter(x, p["hp"], "highpass")
    x = butter(x, p["lp"], "lowpass")
    for f, g, q in p.get("eq", []):
        x = peq(x, f, g, q)
    x = rasp(x, p.get("rasp", 0.0), p.get("fry", 0.0), rng)
    x = growl_layer(x, p.get("growl", 0.0), rng, p.get("roar", 0.0))
    x = drive(x, p.get("drive", 0.0))
    x = breath_layer(x, p.get("breath", 0.0), rng)
    rt, wet = p.get("room", (0.0, -60.0))
    x = room(x, rt, wet, rng)
    return finish(x, p.get("max", 1.2)), p["pack"]


def update_index(rows: list) -> None:
    path = ROOT / "assets" / "asset_index.json"
    index = json.loads(path.read_text(encoding="utf-8"))
    index = [row for row in index if not row["file"].startswith("assets/audio/voice/")]
    index.extend(rows)
    index.sort(key=lambda item: item["file"])
    path.write_text(json.dumps(index, indent=1, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []
    for name, (src, opts) in LINES.items():
        x, license_id = process(name, src, opts)
        path = OUT / f"{name}.ogg"
        # O Vorbis passa um pouco do pico: só abaixa, pelo arquivo decodificado, até ficar
        # em -1 dBFS ou menos (até 4 passadas).
        for _ in range(4):
            sf.write(str(path), x.astype(np.float32), SR, format="OGG", subtype="VORBIS")
            y, _ = sf.read(str(path))
            over = 20 * np.log10(np.abs(y).max()) + 0.95
            if over <= 0:
                break
            x = x * 10 ** (-(over + 0.1) / 20)
        rows.append({
            "file": path.relative_to(ROOT).as_posix(),
            "source": SOURCE,
            "license_id": license_id,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        })
        print(f"{path.relative_to(ROOT).as_posix():36} {len(y) / SR:.2f} s  pico "
              f"{20 * np.log10(np.abs(y).max()):.1f} dBFS  <- {src or 'síntese (Om)'}")
    update_index(rows)
    print(f"{len(rows)} vozes geradas")
    return 0


if __name__ == "__main__":
    sys.exit(main())
