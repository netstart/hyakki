"""Gera, a partir de licenses/registry.json (plano 12.6.2 e 12.6.5):

- licenses/index.json: o que a tela Licenças lê dentro do APK (sem caminhos de docs/);
- ASSET_LICENSES.md: tabela de todos os componentes, licenças e cópias locais;
- CREDITS.md: créditos para a tela Créditos e a página da loja.
Esses arquivos não são editados à mão. Uso: python -I tools/build_license_index.py
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
INDEX_FIELDS = ("id", "name", "author", "license_id", "category", "version", "downloaded_at",
                "verified_at", "modifications", "source_url", "license_file", "notice_file")


def files_count(entry: dict) -> int:
    index = json.loads((ROOT / "assets" / "asset_index.json").read_text(encoding="utf-8"))
    return sum(1 for row in index if row["license_id"] == entry["id"])


def res_path(path: str) -> str:
    return "res://" + path if path else ""


def render(entries: list) -> dict:
    index = []
    for e in entries:
        row = {k: e[k] for k in INDEX_FIELDS if e.get(k) not in (None, "")}
        row["verified_at"] = e.get("verified_at") or e.get("downloaded_at", "")
        row["license_file"] = res_path(e.get("license_file", ""))
        if e.get("notice_file"):
            row["notice_file"] = res_path(e["notice_file"])
        count = files_count(e)
        if count:
            row["files_count"] = count
        index.append(row)
    md = ["# Licenças de assets e software", "",
          "Gerado por `tools/build_license_index.py` a partir de `licenses/registry.json`. Não editar à mão.",
          "Os componentes de terceiros do próprio Godot (FreeType, HarfBuzz, etc.) aparecem na tela",
          "Licenças do jogo, lidos do motor exportado (`Engine.get_copyright_info()`).", "",
          "| Componente | Autor | Licença | Versão | Uso comercial | Crédito exigido | Texto local | Origem |",
          "|---|---|---|---|---|---|---|---|"]
    for e in entries:
        md.append("| {name} | {author} | {lic} | {ver} | {com} | {att} | `{file}` | {url} |".format(
            name=e["name"], author=e["author"], lic=e["license_id"], ver=e.get("version", ""),
            com="sim" if e.get("commercial_use") else "não", att="sim" if e.get("attribution_required") else "não",
            file=e["license_file"], url=e["source_url"]))
    md += ["", "Verificação: `python -I tools/check_licenses.py` (cobertura de todos os arquivos de `assets/`,",
           "hash das cópias, licenças permitidas, data de verificação). Snapshots das páginas de origem em",
           "`docs/licenses/` (fora do APK)."]
    credits = ["# Créditos", "", "**Hyakki — Até o Amanhecer**", "",
               "Design, programação e direção: Clayton", "", "## Arte, áudio e fontes", ""]
    for e in entries:
        if e["category"] in ("art", "audio", "font"):
            credits.append(f"- **{e['name']}** — {e['author']} ({e['license_id']}) — {e['source_url']}")
    credits += ["", "## Software", ""]
    for e in entries:
        if e["category"] not in ("art", "audio", "font"):
            credits.append(f"- **{e['name']}** — {e['author']} ({e['license_id']}) — {e['source_url']}")
    credits += ["", "Agradecimento especial a pixel-boy & AAA pelo Ninja Adventure, liberado em CC0.", ""]
    return {
        "licenses/index.json": json.dumps(index, ensure_ascii=False, indent=2) + "\n",
        "ASSET_LICENSES.md": "\n".join(md) + "\n",
        "CREDITS.md": "\n".join(credits),
    }


def main() -> int:
    entries = json.loads((ROOT / "licenses" / "registry.json").read_text(encoding="utf-8"))
    for path, content in render(entries).items():
        (ROOT / path).write_text(content, encoding="utf-8")
        print("ok", path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
