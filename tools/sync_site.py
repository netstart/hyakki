"""Sincroniza o Hyakki com o site público netstart.github.io (repositório irmão).

Tudo que é publicado no site (política de privacidade, página do jogo, .nojekyll)
é editado e commitado LÁ. O hyakki só gera o app-ads.txt a partir do ID do AdMob
em project.godot e confere a consistência entre os dois repositórios.

Uso:
  python -I tools/sync_site.py                   grava app-ads.txt no site se mudou
  python -I tools/sync_site.py --check           só verifica (sai com 1 se algo estiver errado)
  python -I tools/sync_site.py --commit          grava e commita app-ads.txt no site, se mudou
  python -I tools/sync_site.py --commit --push   ... e faz push do site

Onde fica o site: variável de ambiente NETSTART_SITE_DIR ou, por padrão, a pasta
irmã ../netstart.github.io.
"""
import os
import pathlib
import re
import subprocess
import sys
from urllib.parse import urlparse

ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE_ENV = "NETSTART_SITE_DIR"
SITE_DIR_NAME = "netstart.github.io"
# TAG ID fixo do Google AdMob no app-ads.txt (https://support.google.com/admob/answer/9363762).
ADMOB_TAG_ID = "f08c47fec0942fa0"
PACKAGE = "io.github.netstart.hyakki"
APP_ID_RE = re.compile(r'^general/android/app_id="ca-app-pub-(\d+)~(\d+)"', re.M)
PRIVACY_URL_RE = re.compile(r'^const PRIVACY_POLICY_URL\s*:?=\s*"([^"]+)"', re.M)
# Cópias proibidas no hyakki: esse conteúdo vive no site.
FORBIDDEN_COPIES = (
    "docs/index.html",
    "docs/privacy-policy.html",
    "docs/privacy-policy.md",
    "docs/app-ads.txt",
    "docs/.nojekyll",
)


def site_dir(root: pathlib.Path) -> pathlib.Path:
    """Pasta do site: NETSTART_SITE_DIR ou a pasta irmã do repositório."""
    env = os.environ.get(SITE_ENV)
    if env:
        return pathlib.Path(env)
    return root.parent / SITE_DIR_NAME


def read_app_id(project_godot: str) -> tuple[str, str]:
    """Extrai (publisher, app) de general/android/app_id="ca-app-pub-<pub>~<app>"."""
    m = APP_ID_RE.search(project_godot)
    if not m:
        raise ValueError("general/android/app_id não encontrado em project.godot")
    return m.group(1), m.group(2)


def app_ads_content(pub: str) -> str:
    """Conteúdo exato do app-ads.txt para o publisher do AdMob."""
    return f"google.com, pub-{pub}, DIRECT, {ADMOB_TAG_ID}\n"


def read_privacy_url(options_screen: str) -> str:
    m = PRIVACY_URL_RE.search(options_screen)
    if not m:
        raise ValueError("PRIVACY_POLICY_URL não encontrada em options_screen.gd")
    return m.group(1)


def url_to_site_path(url: str, site: pathlib.Path) -> pathlib.Path:
    """Resolve o caminho da URL dentro da pasta do site (raiz do GitHub Pages)."""
    path = urlparse(url).path.lstrip("/") or "index.html"
    if path.endswith("/"):
        path += "index.html"
    return site / path


def expected_app_ads(root: pathlib.Path) -> tuple[str, str]:
    """(publisher, conteúdo esperado do app-ads.txt) a partir do project.godot."""
    pub, _app = read_app_id((root / "project.godot").read_text(encoding="utf-8"))
    return pub, app_ads_content(pub)


def check_app_ads(root: pathlib.Path, site: pathlib.Path) -> list[str]:
    """Erros se o app-ads.txt do site não bate com o ID do AdMob."""
    _pub, expected = expected_app_ads(root)
    target = site / "app-ads.txt"
    if not target.is_file():
        return [f"{target} não existe (rode python -I tools/sync_site.py para gerar)"]
    actual = target.read_bytes().decode("utf-8", errors="replace")
    if actual == expected:
        return []
    if actual.replace("\r\n", "\n") == expected:
        return [f"{target} difere só no fim de linha (CRLF/LF); rode python -I tools/sync_site.py"]
    return [f"{target} difere do ID do AdMob em project.godot; rode python -I tools/sync_site.py"]


def check_site(root: pathlib.Path, site: pathlib.Path) -> list[str]:
    """Verificações de consistência entre o hyakki e o site (não escreve nada)."""
    errors = []
    try:
        url = read_privacy_url((root / "scripts/app/screens/options_screen.gd").read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        errors.append(str(e))
    else:
        policy = url_to_site_path(url, site)
        if not policy.is_file():
            errors.append(f"política de privacidade {url} não existe no site ({policy})")
        elif PACKAGE not in policy.read_text(encoding="utf-8", errors="replace"):
            errors.append(f"política de privacidade {policy} não menciona o pacote {PACKAGE}")
    if not (site / "hyakki" / "index.html").is_file():
        errors.append(f"página do jogo não existe no site ({site / 'hyakki' / 'index.html'})")
    if not (site / ".nojekyll").is_file():
        errors.append(f".nojekyll não existe na raiz do site ({site / '.nojekyll'})")
    for rel in FORBIDDEN_COPIES:
        if (root / rel).exists():
            errors.append(f"{rel} existe no hyakki: esse conteúdo vive no site (apague aqui e edite em {site})")
    return errors


def sync_app_ads(root: pathlib.Path, site: pathlib.Path, write: bool) -> tuple[bool, str]:
    """Grava o app-ads.txt no site se mudou. Retorna (mudou, publisher)."""
    pub, expected = expected_app_ads(root)
    target = site / "app-ads.txt"
    changed = not target.is_file() or target.read_bytes() != expected.encode("utf-8")
    if changed and write:
        target.write_bytes(expected.encode("utf-8"))
    return changed, pub


def git(site: pathlib.Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(site), *args], capture_output=True, text=True, check=False)


def commit_app_ads(site: pathlib.Path, pub: str, push: bool) -> list[str]:
    """Commita só o app-ads.txt no site, se ele difere do HEAD de lá; opcionalmente faz push."""
    status = git(site, "status", "--porcelain", "--", "app-ads.txt")
    if status.returncode != 0:
        return [f"git status falhou no site: {status.stderr.strip()}"]
    if not status.stdout.strip():
        print("OK app-ads.txt do site já está commitado")
        return []
    add = git(site, "add", "app-ads.txt")
    if add.returncode != 0:
        return [f"git add falhou no site: {add.stderr.strip()}"]
    commit = git(site, "commit", "-m", f"Hyakki: app-ads.txt atualizado (pub-{pub})", "--", "app-ads.txt")
    if commit.returncode != 0:
        return [f"git commit falhou no site: {commit.stderr.strip()} {commit.stdout.strip()}"]
    print(f"OK commit no site: app-ads.txt atualizado (pub-{pub})")
    if push:
        pushed = git(site, "push")
        if pushed.returncode != 0:
            return [f"git push falhou no site: {pushed.stderr.strip()}"]
        print("OK push do site feito")
    return []


def run(argv: list[str], root: pathlib.Path, site: pathlib.Path) -> int:
    check = "--check" in argv
    commit = "--commit" in argv
    push = "--push" in argv
    if push and not commit:
        print("ERRO --push só funciona junto com --commit")
        return 2
    if not site.is_dir():
        print(f"ERRO pasta do site não existe: {site}")
        print(f"     clone https://github.com/netstart/{SITE_DIR_NAME}.git ao lado do hyakki "
              f"ou aponte {SITE_ENV} para a pasta do site")
        return 1
    errors = []
    try:
        changed, pub = sync_app_ads(root, site, write=not check)
    except (OSError, ValueError) as e:
        errors.append(str(e))
        changed, pub = False, ""
    else:
        if check:
            errors.extend(check_app_ads(root, site))
        elif changed:
            print(f"OK app-ads.txt gravado no site (pub-{pub})")
        else:
            print(f"OK app-ads.txt do site já estava correto (pub-{pub})")
    errors.extend(check_site(root, site))
    if not errors and commit:
        errors.extend(commit_app_ads(site, pub, push))
    for e in errors:
        print("ERRO", e)
    if errors:
        return 1
    print(f"OK site consistente: {site}")
    return 0


def main() -> int:
    return run(sys.argv[1:], ROOT, site_dir(ROOT))


if __name__ == "__main__":
    sys.exit(main())
