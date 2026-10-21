"""Confere os limites da Play Console em docs/store/listing.md (plano 16):
título ≤ 30, descrição curta ≤ 80, descrição completa ≤ 4.000 caracteres, nos 11 idiomas.
Uso: python -I tools/check_store_listing.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LANGS = ["pt_BR", "en", "es", "de", "fr", "ru", "id", "ja", "ko", "zh_TW", "zh_CN"]
BLOCK = re.compile(r"<!-- LISTING:(\w+) -->\n(.*?)<!-- /LISTING -->", re.S)
FIELD = re.compile(r"^\*\*[^*]+\*\*\s?(.*)$")


def main() -> int:
    text = (ROOT / "docs" / "store" / "listing.md").read_text(encoding="utf-8")
    found = {m.group(1): m.group(2).strip() for m in BLOCK.finditer(text)}
    errors = [f"falta o idioma {lang}" for lang in LANGS if lang not in found]
    for lang, body in found.items():
        parts = body.split("\n\n", 2)
        title = FIELD.match(parts[0]).group(1)
        short = FIELD.match(parts[1]).group(1)
        full = parts[2].split("\n", 1)[1].strip()
        for name, value, limit in (("título", title, 30), ("curta", short, 80), ("completa", full, 4000)):
            if not value or len(value) > limit:
                errors.append(f"{lang}: {name} com {len(value)} caracteres (limite {limit})")
    for e in errors:
        print("ERRO", e)
    if errors:
        return 1
    print(f"OK ficha da loja: {len(found)} idiomas dentro dos limites")
    return 0


if __name__ == "__main__":
    sys.exit(main())
