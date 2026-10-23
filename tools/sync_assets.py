"""Copia para res://assets só os arquivos que o jogo usa (plano 8.3 e 12.5).

Uso:  python -I tools/sync_assets.py
Lê tools/asset_manifest.json (Ninja Adventure) e todo tools/*_assets.json (outros pacotes).
Também escreve assets/asset_index.json: lista de tudo que foi copiado, com origem e hash,
usado pelo tools/check_licenses.py para conferir que todo arquivo tem licença registrada.
"""
import hashlib
import json
import pathlib
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
SKIP_SUFFIXES = {".gif"}


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def copy_file(src: pathlib.Path, dst: pathlib.Path, license_id: str, index: list) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if not dst.exists() or sha256(src) != sha256(dst):
        shutil.copy2(src, dst)
    index.append({
        "file": dst.relative_to(ROOT).as_posix(),
        "source": src.as_posix(),
        "license_id": license_id,
        "sha256": sha256(dst),
    })


def sync_manifest(manifest_path: pathlib.Path, index: list) -> int:
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    pack = pathlib.Path(data["pack_root"])
    license_id = data["license_id"]
    missing = 0
    for src_rel, dst_rel in data.get("folders", {}).items():
        src_dir = pack / src_rel
        if not src_dir.is_dir():
            print(f"FALTA pasta: {src_dir}")
            missing += 1
            continue
        for src in sorted(src_dir.rglob("*")):
            if not src.is_file() or src.suffix.lower() in SKIP_SUFFIXES:
                continue
            if src.name.lower().startswith("preview") or src.name.lower().startswith("allpreview"):
                continue
            rel = src.relative_to(src_dir)
            dst = ASSETS / dst_rel / pathlib.Path(*[p.replace(" ", "_") for p in rel.parts])
            copy_file(src, dst, license_id, index)
    for src_rel, dst_rel in data.get("files", {}).items():
        src = pack / src_rel
        if not src.is_file():
            print(f"FALTA arquivo: {src}")
            missing += 1
            continue
        copy_file(src, ASSETS / dst_rel, license_id, index)
    return missing


def main() -> int:
    index: list = []
    missing = 0
    manifests = [ROOT / "tools" / "asset_manifest.json"] + sorted((ROOT / "tools").glob("*_assets.json"))
    for path in manifests:
        if path.exists():
            missing += sync_manifest(path, index)
    # Assets gerados por ferramentas do próprio repositório (ex.: tools/gen_sfx.py) ficam no índice.
    old_index = ASSETS / "asset_index.json"
    if old_index.exists():
        for row in json.loads(old_index.read_text(encoding="utf-8")):
            target = ROOT / row["file"]
            if row.get("source", "").startswith("tools/") and target.exists():
                index.append({**row, "sha256": sha256(target)})
    index.sort(key=lambda item: item["file"])
    (ASSETS / "asset_index.json").write_text(
        json.dumps(index, indent=1, ensure_ascii=False), encoding="utf-8")
    print(f"{len(index)} arquivos sincronizados, {missing} faltando")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
