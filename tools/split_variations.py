"""Corta um WAV com várias variações separadas por silêncio em arquivos curtos (plano 15.7).

Usado no Pixel Combat do Helton Yan, cujos arquivos trazem ~6 variações de 24 s em 96 kHz/24 bit.
Saída: WAV 48 kHz, 16 bit, mono, com fade de 5 ms nas pontas, até `--max` variações por arquivo.
Uso: python -I tools/split_variations.py ENTRADA.wav PREFIXO_SAIDA [--max 6] [--threshold 0.02]
Só biblioteca padrão (wave + array), para rodar em qualquer máquina.
"""
import array
import pathlib
import sys
import wave

MIN_SILENCE = 0.12   # segundos de silêncio que separam variações
MIN_LENGTH = 0.04    # descarta cliques menores que isso
PAD = 0.01           # margem antes/depois do som
FADE = 0.005


def read_mono(path: pathlib.Path) -> tuple[list, int]:
    with wave.open(str(path)) as w:
        channels, width, rate, frames = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(frames)
    if width != 3 and width != 2:
        raise SystemExit(f"{path}: só 16 ou 24 bit")
    samples = []
    step = width * channels
    scale = float(1 << (8 * width - 1))
    for i in range(0, len(raw) - step + 1, step):
        acc = 0.0
        for c in range(channels):
            b = raw[i + c * width:i + (c + 1) * width]
            acc += int.from_bytes(b, "little", signed=True) / scale
        samples.append(acc / channels)
    return samples, rate


def resample_half(samples: list) -> list:
    return [(samples[i] + samples[i + 1]) * 0.5 for i in range(0, len(samples) - 1, 2)]


def segments(samples: list, rate: int, threshold: float) -> list:
    win = max(1, int(rate * 0.005))
    loud = []
    for i in range(0, len(samples), win):
        chunk = samples[i:i + win]
        loud.append(max(abs(s) for s in chunk) >= threshold)
    out, start, quiet = [], None, 0
    gap = int(MIN_SILENCE * rate / win)
    for idx, is_loud in enumerate(loud + [False] * (gap + 1)):
        if is_loud:
            if start is None:
                start = idx
            quiet = 0
        elif start is not None:
            quiet += 1
            if quiet > gap:
                end = idx - quiet + 1
                if (end - start) * win / rate >= MIN_LENGTH:
                    out.append((start * win, min(len(samples), end * win)))
                start, quiet = None, 0
    return out


def write(path: pathlib.Path, samples: list, rate: int) -> None:
    fade = int(FADE * rate)
    for i in range(min(fade, len(samples) // 2)):
        g = i / fade
        samples[i] *= g
        samples[-1 - i] *= g
    data = array.array("h", (max(-32767, min(32767, int(s * 32767))) for s in samples))
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data.tobytes())


def main() -> int:
    args = sys.argv[1:]
    src, prefix = pathlib.Path(args[0]), pathlib.Path(args[1])
    limit = int(args[args.index("--max") + 1]) if "--max" in args else 6
    threshold = float(args[args.index("--threshold") + 1]) if "--threshold" in args else 0.02
    samples, rate = read_mono(src)
    while rate > 48000:
        samples, rate = resample_half(samples), rate // 2
    pad = int(PAD * rate)
    found = segments(samples, rate, threshold)
    prefix.parent.mkdir(parents=True, exist_ok=True)
    for n, (a, b) in enumerate(found[:limit]):
        out = prefix.with_name(f"{prefix.name}{n}.wav")
        write(out, samples[max(0, a - pad):min(len(samples), b + pad)], rate)
        print(f"{out.name}: {(b - a) / rate:.2f} s")
    print(f"{src.name}: {len(found)} variações encontradas, {min(limit, len(found))} gravadas")
    return 0


if __name__ == "__main__":
    sys.exit(main())
