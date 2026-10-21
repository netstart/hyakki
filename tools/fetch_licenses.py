"""Baixa as cópias das licenças do registro (plano 12.6.3).

Para cada entrada de licenses/registry.json:
1. baixa o texto canônico (license_url) para license_file;
2. copia ou baixa o aviso do autor (notice_source / notice_url) para notice_file;
3. salva um snapshot em PDF da página de origem em docs/licenses/<id>_<data>.pdf
   (Chrome/Edge headless), porque páginas de itch.io/GitHub podem mudar;
4. grava SHA-256 e downloaded_at no registro.
Nunca sobrescreve uma cópia diferente: guarda a nova com a data e marca needs_review.
Uso: python -I tools/fetch_licenses.py [--no-snapshot]
"""
import datetime
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "licenses" / "registry.json"
BROWSERS = [
    pathlib.Path("C:/Program Files/Google/Chrome/Application/chrome.exe"),
    pathlib.Path("C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"),
]
TODAY = datetime.date.today().isoformat()


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def download(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "hyakki-license-fetch/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def store(target: pathlib.Path, content: bytes, entry: dict) -> None:
    """Grava sem perder histórico: conteúdo novo e diferente vira cópia datada + revisão."""
    content = content.replace(b"\r\n", b"\n")
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and target.read_bytes() != content:
        dated = target.with_name(f"{target.stem}_{TODAY}{target.suffix}")
        dated.write_bytes(content)
        entry["needs_review"] = True
        print(f"  MUDOU: {target.relative_to(ROOT)} -> nova cópia {dated.name}; revisar")
        return
    target.write_bytes(content)


def snapshot(entry: dict) -> None:
    url = entry.get("snapshot_url")
    browser = next((b for b in BROWSERS if b.exists()), None)
    if not url or browser is None:
        return
    target = ROOT / "docs" / "licenses" / f"{entry['id']}_{TODAY}.pdf"
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        entry["snapshot_file"] = target.relative_to(ROOT).as_posix()
        return
    profile = ROOT / "build" / "chrome_profile"
    subprocess.run([str(browser), "--headless=new", "--disable-gpu", "--no-first-run",
                    f"--user-data-dir={profile}", "--virtual-time-budget=8000",
                    f"--print-to-pdf={target}", url], timeout=120, check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if target.exists():
        entry["snapshot_file"] = target.relative_to(ROOT).as_posix()
        print(f"  snapshot {target.relative_to(ROOT)}")
    else:
        print(f"  AVISO: snapshot falhou para {url}")


def main() -> int:
    entries = json.loads(REGISTRY.read_text(encoding="utf-8"))
    texts_done: dict = {}
    for entry in entries:
        print(entry["id"])
        hashes = entry.setdefault("sha256", {})
        license_file = ROOT / entry["license_file"]
        if entry.get("license_source"):
            # Termos proprietários (Google): resumo local com os links; snapshot em docs/licenses.
            store(license_file, (ROOT / entry["license_source"]).read_bytes(), entry)
        elif entry["license_file"] not in texts_done:
            try:
                store(license_file, download(entry["license_url"]), entry)
                texts_done[entry["license_file"]] = True
            except OSError as error:
                print(f"  ERRO ao baixar {entry['license_url']}: {error}")
                if not license_file.exists():
                    return 1
        hashes["license_file"] = sha256(license_file)
        if entry.get("notice_file"):
            notice = ROOT / entry["notice_file"]
            if entry.get("notice_source"):
                store(notice, (ROOT / entry["notice_source"]).read_bytes(), entry)
            elif entry.get("notice_url"):
                store(notice, download(entry["notice_url"]), entry)
            hashes["notice_file"] = sha256(notice)
        if "--no-snapshot" not in sys.argv:
            snapshot(entry)
        if entry.get("snapshot_file"):
            hashes["snapshot_file"] = sha256(ROOT / entry["snapshot_file"])
        entry["downloaded_at"] = TODAY
    REGISTRY.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    shutil.rmtree(ROOT / "build" / "chrome_profile", ignore_errors=True)
    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
