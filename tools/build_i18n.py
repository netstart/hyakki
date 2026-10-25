"""Gera i18n/strings.csv a partir de tools/i18n/*.py (plano 7.7).

Valida: toda chave usada pelo jogo existe, cada linha tem os 11 idiomas, nenhum texto
vazio e os marcadores (%s, %d) batem com o português em cada idioma.
Uso: python -I tools/build_i18n.py [--check]  (--check só valida, não grava)
"""
import csv
import importlib.util
import io
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LANGS = ["pt_BR", "en", "es", "de", "fr", "ru", "id", "ja", "ko", "zh_TW", "zh_CN"]
MODULES = ["ui", "data", "progress", "bestiary", "story", "gfx", "levelup_chest", "menus"]
PLACEHOLDER = re.compile(r"%[sd]")


def load(name: str):
    path = ROOT / "tools" / "i18n" / f"{name}.py"
    spec = importlib.util.spec_from_file_location(f"i18n_{name}", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.STRINGS


def keys_module():
    spec = importlib.util.spec_from_file_location("i18n_keys", ROOT / "tools" / "i18n_keys.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def collect() -> tuple[dict, list]:
    strings: dict = {}
    errors: list = []
    for name in MODULES:
        for key, values in load(name).items():
            if key in strings:
                errors.append(f"chave duplicada: {key} ({name})")
            strings[key] = values
    for key, values in strings.items():
        if len(values) != len(LANGS):
            errors.append(f"{key}: {len(values)} idiomas, esperado {len(LANGS)}")
            continue
        base = PLACEHOLDER.findall(values[0])
        for lang, text in zip(LANGS, values):
            if not text.strip():
                errors.append(f"{key} [{lang}]: vazio")
            if PLACEHOLDER.findall(text) != base:
                errors.append(f"{key} [{lang}]: marcadores {PLACEHOLDER.findall(text)} != {base}")
    used = set(keys_module().all_keys())
    for key in sorted(used - strings.keys()):
        errors.append(f"sem tradução: {key}")
    for key in sorted(strings.keys() - used):
        errors.append(f"chave não usada: {key}")
    return strings, errors


def render(strings: dict) -> str:
    out = io.StringIO()
    writer = csv.writer(out, lineterminator="\n")
    writer.writerow(["key", *LANGS])
    for key in sorted(strings):
        writer.writerow([key, *[v.replace("\n", "\\n") for v in strings[key]]])
    return out.getvalue()


def main() -> int:
    strings, errors = collect()
    for e in errors:
        print("ERRO", e)
    if errors:
        return 1
    target = ROOT / "i18n" / "strings.csv"
    text = render(strings)
    if "--check" in sys.argv:
        current = target.read_text(encoding="utf-8") if target.exists() else ""
        if current != text:
            print("ERRO i18n/strings.csv desatualizado; rode tools/build_i18n.py")
            return 1
        print(f"OK {len(strings)} chaves x {len(LANGS)} idiomas")
        return 0
    target.write_text(text, encoding="utf-8")
    print(f"OK {len(strings)} chaves x {len(LANGS)} idiomas -> {target.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
