"""Verifica as licenças antes de cada build (plano 12.6.4). Sai com código 1 se:

- algum arquivo em assets/ (que vai no export) não é coberto por uma entrada do registro;
- uma entrada não tem a cópia local da licença, ou o SHA-256 não confere;
- a licença não está na lista permitida (sem NC, ND, SA, GPL, personal_only...);
- o componente exige crédito e não aparece em CREDITS.md;
- a verificação tem mais de 180 dias ou a entrada está marcada needs_review;
- licenses/index.json ou os .md gerados estão desatualizados.
Uso: python -I tools/check_licenses.py
"""
import datetime
import fnmatch
import hashlib
import importlib.util
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ALLOWED = {"CC0-1.0", "MIT", "Apache-2.0", "OFL-1.1", "CC-BY-4.0", "BSD-2-Clause", "BSD-3-Clause",
           "Zlib", "FTL"}
BLOCKED_FLAGS = ("personal_only", "no_monetized_games")
MAX_AGE_DAYS = 180
IGNORED = ("*.import", "assets/asset_index.json")


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def builder():
    spec = importlib.util.spec_from_file_location("bli", ROOT / "tools" / "build_license_index.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    errors: list = []
    entries = json.loads((ROOT / "licenses" / "registry.json").read_text(encoding="utf-8"))
    today = datetime.date.today()
    for e in entries:
        tag = e["id"]
        lic = e["license_id"]
        if lic not in ALLOWED and not lic.startswith("LicenseRef-"):
            errors.append(f"{tag}: licença não permitida {lic}")
        if any(x in lic for x in ("-NC", "-ND", "-SA", "GPL")):
            errors.append(f"{tag}: licença bloqueada {lic}")
        for flag in BLOCKED_FLAGS:
            if e.get(flag):
                errors.append(f"{tag}: marcada {flag}")
        if not e.get("commercial_use"):
            errors.append(f"{tag}: uso comercial não confirmado")
        if e.get("ai_generated"):
            errors.append(f"{tag}: asset gerado por IA precisa de decisão registrada (12.1)")
        for key in ("license_file", "notice_file", "snapshot_file"):
            if not e.get(key):
                continue
            path = ROOT / e[key]
            if not path.exists():
                errors.append(f"{tag}: falta {e[key]}")
            elif e.get("sha256", {}).get(key) != sha256(path):
                errors.append(f"{tag}: SHA-256 de {e[key]} não confere (rode fetch_licenses.py e revise)")
        if not e.get("snapshot_file"):
            errors.append(f"{tag}: sem snapshot da página de origem em docs/licenses/")
        verified = e.get("verified_at") or e.get("downloaded_at")
        if not verified:
            errors.append(f"{tag}: sem data de verificação")
        elif (today - datetime.date.fromisoformat(verified)).days > MAX_AGE_DAYS:
            errors.append(f"{tag}: verificada há mais de {MAX_AGE_DAYS} dias")
        if e.get("needs_review"):
            errors.append(f"{tag}: marcada needs_review (a licença ou a página mudou)")
    # Cobertura: todo arquivo de assets/ pertence a alguma entrada.
    uncovered = []
    for path in sorted((ROOT / "assets").rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT).as_posix()
        if any(fnmatch.fnmatch(rel, pattern) for pattern in IGNORED):
            continue
        if not any(fnmatch.fnmatch(rel, p) for e in entries for p in e.get("files", [])):
            uncovered.append(rel)
    for rel in uncovered[:20]:
        errors.append(f"arquivo sem licença registrada: {rel}")
    if len(uncovered) > 20:
        errors.append(f"... e mais {len(uncovered) - 20} arquivos sem licença")
    # O índice de assets também precisa concordar com o registro.
    ids = {e["id"] for e in entries}
    index = json.loads((ROOT / "assets" / "asset_index.json").read_text(encoding="utf-8"))
    for row in index:
        if row["license_id"] not in ids:
            errors.append(f"asset_index: {row['file']} aponta para licença desconhecida {row['license_id']}")
        elif (ROOT / row["file"]).exists() and sha256(ROOT / row["file"]) != row["sha256"]:
            errors.append(f"asset_index: {row['file']} mudou desde a cópia (rode sync_assets.py)")
    # Arquivos gerados em dia e crédito para quem exige.
    module = builder()
    for path, content in module.render(entries).items():
        target = ROOT / path
        if not target.exists() or target.read_text(encoding="utf-8") != content:
            errors.append(f"{path} desatualizado (rode tools/build_license_index.py)")
    credits = (ROOT / "CREDITS.md").read_text(encoding="utf-8") if (ROOT / "CREDITS.md").exists() else ""
    for e in entries:
        if e.get("attribution_required") and e["name"] not in credits:
            errors.append(f"{e['id']}: exige crédito e não está em CREDITS.md")
    for message in errors:
        print("ERRO", message)
    if errors:
        return 1
    print(f"OK licenças: {len(entries)} componentes, {len(index)} arquivos de assets cobertos")
    return 0


if __name__ == "__main__":
    sys.exit(main())
