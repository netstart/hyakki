"""Hook pre-commit do Hyakki (chamado por tools/githooks/pre-commit).

(a) Reprova o commit se ele toca cópias de arquivos publicados em netstart.github.io
    (docs/index.html, docs/privacy-policy.*, docs/app-ads.txt, docs/.nojekyll ou
    qualquer docs/*.html direto na raiz de docs): esse conteúdo é editado e commitado
    no repositório irmão C:\\src\\netstart.github.io (../netstart.github.io).
(b) Se project.godot está no commit e a linha general/android/app_id mudou, roda
    python -I tools/sync_site.py --commit para atualizar o app-ads.txt do site.

Uso: python -I tools/hooks/pre_commit.py   (sai com 1 para abortar o commit)
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
SITE_REPO = "C:\\src\\netstart.github.io (repositório irmão ../netstart.github.io)"
FORBIDDEN = frozenset((
    "docs/index.html",
    "docs/privacy-policy.md",
    "docs/privacy-policy.html",
    "docs/app-ads.txt",
    "docs/.nojekyll",
))
DOCS_ROOT_HTML = re.compile(r"^docs/[^/]+\.html$")
APP_ID_LINE = re.compile(r"^[+-](?![+-])\s*general/android/app_id=", re.M)


def normalize(path: str) -> str:
    return path.replace("\\", "/").strip("/")


def is_forbidden(path: str) -> bool:
    """True se o caminho (relativo à raiz do repo) é uma cópia que vive no site."""
    rel = normalize(path)
    return rel in FORBIDDEN or bool(DOCS_ROOT_HTML.match(rel))


def forbidden_paths(paths: list[str]) -> list[str]:
    """Caminhos adicionados/modificados/renomeados que não podem ser commitados aqui."""
    return [p for p in paths if is_forbidden(p)]


def parse_name_status(output: str) -> list[str]:
    """Caminhos de `git diff --cached --name-status` (A, M, R e C; o destino nos renomes)."""
    paths = []
    for line in output.splitlines():
        parts = line.split("\t")
        if len(parts) < 2 or parts[0][:1] == "D":
            continue
        paths.append(parts[-1])
    return paths


def app_id_changed(diff: str) -> bool:
    """True se o diff de project.godot mexe na linha general/android/app_id."""
    return bool(APP_ID_LINE.search(diff))


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True, cwd=ROOT).stdout


def main() -> int:
    paths = parse_name_status(git("diff", "--cached", "--name-status"))
    bad = forbidden_paths(paths)
    if bad:
        print("ERRO commit reprovado: estes arquivos são publicados em netstart.github.io", file=sys.stderr)
        for p in bad:
            print(f"     {p}", file=sys.stderr)
        print(f"     Edite e commite esse conteúdo em {SITE_REPO}.", file=sys.stderr)
        print("     O app-ads.txt do site é gerado por python -I tools/sync_site.py.", file=sys.stderr)
        return 1
    if "project.godot" in (normalize(p) for p in paths):
        diff = git("diff", "--cached", "-U0", "--", "project.godot")
        if app_id_changed(diff):
            print("general/android/app_id mudou: atualizando o app-ads.txt do site...")
            rc = subprocess.run([sys.executable, "-I", str(ROOT / "tools" / "sync_site.py"), "--commit"],
                                cwd=ROOT, check=False).returncode
            if rc != 0:
                print("ERRO commit reprovado: o app-ads.txt do site precisa ser atualizado e commitado "
                      f"em {SITE_REPO} (python -I tools/sync_site.py --commit falhou).", file=sys.stderr)
                return 1
            print("OK app-ads.txt do site atualizado (commit feito lá, se mudou)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
