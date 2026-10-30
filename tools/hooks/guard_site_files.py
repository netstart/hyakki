"""Hook PreToolUse do Claude Code (Edit|Write|MultiEdit): bloqueia edições em cópias de
arquivos publicados em netstart.github.io dentro deste repositório.

Lê o JSON da ferramenta no stdin (tool_input.file_path). Se o caminho, relativo à raiz
do repositório (cwd), é docs/index.html, docs/privacy-policy.*, docs/app-ads.txt,
docs/.nojekyll ou docs/*.html, explica no stderr onde esse conteúdo vive e sai com 2
(bloqueia a ferramenta). Qualquer outro caminho ou JSON inválido: sai com 0 em silêncio.
"""
import json
import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from pre_commit import is_forbidden, normalize  # noqa: E402

SITE = "C:\\src\\netstart.github.io"
EQUIVALENT = {
    "docs/privacy-policy.html": "privacy-policy.html na raiz do site (fonte: hyakki/privacy-policy.md)",
    "docs/privacy-policy.md": "hyakki/privacy-policy.md (gera privacy-policy.html na raiz do site)",
    "docs/index.html": "hyakki/index.html",
    "docs/app-ads.txt": "app-ads.txt na raiz do site, gerado por python -I tools/sync_site.py",
    "docs/.nojekyll": ".nojekyll na raiz do site",
}


def relative_to_root(file_path: str, root: pathlib.Path) -> str | None:
    """Caminho relativo à raiz do repo, ou None se o arquivo está fora dela."""
    try:
        path = pathlib.Path(file_path)
        if not path.is_absolute():
            path = root / path
        return normalize(os.path.relpath(path.resolve(), root.resolve()))
    except (OSError, ValueError):
        return None


def message(rel: str) -> str:
    where = EQUIVALENT.get(rel, f"hyakki/{rel.split('/', 1)[1]}")
    return (f"Edição bloqueada: {rel} não vive neste repositório. Esse conteúdo é publicado em "
            f"{SITE} (caminho equivalente lá: {where}). Edite e commite no site.")


def main() -> int:
    try:
        data = json.load(sys.stdin)
        file_path = data["tool_input"]["file_path"]
    except (ValueError, KeyError, TypeError):
        return 0
    if not isinstance(file_path, str):
        return 0
    rel = relative_to_root(file_path, pathlib.Path.cwd())
    if rel is None or rel.startswith("..") or not is_forbidden(rel):
        return 0
    sys.stderr.reconfigure(encoding="utf-8")
    print(message(rel), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
