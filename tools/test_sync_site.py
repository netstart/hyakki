"""Testes de tools/sync_site.py com um hyakki e um site falsos em pastas temporárias.
Uso: python -I tools/test_sync_site.py
"""
import contextlib
import io
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import sync_site  # noqa: E402

PUB = "1234567890123456"
APP_ADS = f"google.com, pub-{PUB}, DIRECT, f08c47fec0942fa0\n"


def make_root(base: pathlib.Path) -> pathlib.Path:
    root = base / "hyakki"
    (root / "scripts/app/screens").mkdir(parents=True)
    (root / "project.godot").write_text(
        f'[general]\n\ngeneral/android/app_id="ca-app-pub-{PUB}~9876543210"\n', encoding="utf-8")
    (root / "scripts/app/screens/options_screen.gd").write_text(
        'extends Control\nconst PRIVACY_POLICY_URL := "https://netstart.github.io/privacy-policy.html"\n',
        encoding="utf-8")
    return root


def make_site(base: pathlib.Path, app_ads: str | None = APP_ADS) -> pathlib.Path:
    site = base / "netstart.github.io"
    (site / "hyakki").mkdir(parents=True)
    (site / "privacy-policy.html").write_text("<p>io.github.netstart.hyakki</p>", encoding="utf-8")
    (site / "hyakki/index.html").write_text("<h1>Hyakki</h1>", encoding="utf-8")
    (site / ".nojekyll").write_text("", encoding="utf-8")
    if app_ads is not None:
        (site / "app-ads.txt").write_bytes(app_ads.encode("utf-8"))
    return site


class SyncSiteTests(unittest.TestCase):
    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.root = make_root(self.tmp)

    def run_cli(self, *args, site=None):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = sync_site.run(list(args), self.root, site if site is not None else self.site)
        return rc, out.getvalue()

    def test_app_ads_gerado_do_app_id(self):
        pub, app = sync_site.read_app_id((self.root / "project.godot").read_text(encoding="utf-8"))
        self.assertEqual((pub, app), (PUB, "9876543210"))
        self.assertEqual(sync_site.app_ads_content(pub), APP_ADS)
        self.assertEqual(sync_site.expected_app_ads(self.root), (PUB, APP_ADS))

    def test_url_da_politica_resolvida_no_site(self):
        site = self.tmp / "s"
        self.assertEqual(sync_site.url_to_site_path("https://x.io/privacy-policy.html", site),
                         site / "privacy-policy.html")
        self.assertEqual(sync_site.url_to_site_path("https://x.io/hyakki/", site), site / "hyakki/index.html")

    def test_check_passa_com_tudo_certo(self):
        self.site = make_site(self.tmp)
        rc, out = self.run_cli("--check")
        self.assertEqual(rc, 0, out)
        self.assertIn("OK site consistente", out)
        self.assertEqual((self.site / "app-ads.txt").read_bytes(), APP_ADS.encode("utf-8"))

    def test_check_falha_com_app_ads_diferente(self):
        self.site = make_site(self.tmp, app_ads="google.com, pub-0, DIRECT, f08c47fec0942fa0\n")
        rc, out = self.run_cli("--check")
        self.assertEqual(rc, 1)
        self.assertIn("ERRO", out)
        self.assertIn("difere do ID do AdMob", out)
        # --check não grava
        self.assertIn("pub-0", (self.site / "app-ads.txt").read_text(encoding="utf-8"))

    def test_check_falha_com_app_ads_ausente(self):
        self.site = make_site(self.tmp, app_ads=None)
        rc, out = self.run_cli("--check")
        self.assertEqual(rc, 1)
        self.assertFalse((self.site / "app-ads.txt").exists())

    def test_check_aponta_diferenca_so_de_fim_de_linha(self):
        self.site = make_site(self.tmp, app_ads=APP_ADS.replace("\n", "\r\n"))
        rc, out = self.run_cli("--check")
        self.assertEqual(rc, 1)
        self.assertIn("fim de linha", out)

    def test_check_falha_sem_politica(self):
        self.site = make_site(self.tmp)
        (self.site / "privacy-policy.html").unlink()
        rc, out = self.run_cli("--check")
        self.assertEqual(rc, 1)
        self.assertIn("política de privacidade", out)

    def test_check_falha_sem_pacote_na_politica(self):
        self.site = make_site(self.tmp)
        (self.site / "privacy-policy.html").write_text("<p>nada</p>", encoding="utf-8")
        rc, out = self.run_cli("--check")
        self.assertEqual(rc, 1)
        self.assertIn("io.github.netstart.hyakki", out)

    def test_check_falha_com_copia_proibida_no_hyakki(self):
        self.site = make_site(self.tmp)
        (self.root / "docs").mkdir()
        (self.root / "docs/privacy-policy.html").write_text("x", encoding="utf-8")
        rc, out = self.run_cli("--check")
        self.assertEqual(rc, 1)
        self.assertIn("docs/privacy-policy.html existe no hyakki", out)

    def test_check_falha_sem_nojekyll_ou_index(self):
        self.site = make_site(self.tmp)
        (self.site / ".nojekyll").unlink()
        (self.site / "hyakki/index.html").unlink()
        rc, out = self.run_cli("--check")
        self.assertEqual(rc, 1)
        self.assertIn(".nojekyll", out)
        self.assertIn("página do jogo", out)

    def test_falha_sem_pasta_do_site(self):
        rc, out = self.run_cli("--check", site=self.tmp / "nao-existe")
        self.assertEqual(rc, 1)
        self.assertIn("ERRO pasta do site não existe", out)
        self.assertIn("NETSTART_SITE_DIR", out)

    def test_modo_padrao_grava_o_arquivo(self):
        self.site = make_site(self.tmp, app_ads=None)
        rc, out = self.run_cli()
        self.assertEqual(rc, 0, out)
        self.assertIn("app-ads.txt gravado", out)
        self.assertEqual((self.site / "app-ads.txt").read_bytes(), APP_ADS.encode("utf-8"))
        rc, out = self.run_cli()
        self.assertEqual(rc, 0)
        self.assertIn("já estava correto", out)

    def test_push_exige_commit(self):
        self.site = make_site(self.tmp)
        rc, out = self.run_cli("--push")
        self.assertEqual(rc, 2)

    def test_site_dir_pela_variavel_de_ambiente(self):
        import os
        old = os.environ.get(sync_site.SITE_ENV)
        os.environ[sync_site.SITE_ENV] = str(self.tmp / "outro")
        try:
            self.assertEqual(sync_site.site_dir(self.root), self.tmp / "outro")
        finally:
            if old is None:
                del os.environ[sync_site.SITE_ENV]
            else:
                os.environ[sync_site.SITE_ENV] = old
        self.assertEqual(sync_site.site_dir(self.root), self.tmp / "netstart.github.io")

    @unittest.skipIf(shutil.which("git") is None, "git não encontrado")
    def test_commit_so_do_app_ads_no_site(self):
        self.site = make_site(self.tmp, app_ads="antigo\n")
        git = ["git", "-C", str(self.site), "-c", "user.name=t", "-c", "user.email=t@t"]
        subprocess.run(["git", "-C", str(self.site), "init", "-q"], check=True)
        subprocess.run([*git, "add", "-A"], check=True)
        subprocess.run([*git, "commit", "-q", "-m", "inicio"], check=True)
        (self.site / "hyakki/index.html").write_text("mudou", encoding="utf-8")
        subprocess.run([*git, "config", "user.name", "t"], check=True)
        subprocess.run([*git, "config", "user.email", "t@t"], check=True)
        rc, out = self.run_cli("--commit")
        self.assertEqual(rc, 0, out)
        self.assertIn("OK commit no site", out)
        log = subprocess.run([*git, "log", "-1", "--format=%s%n%b"], capture_output=True, text=True).stdout
        self.assertIn(f"Hyakki: app-ads.txt atualizado (pub-{PUB})", log)
        self.assertNotIn("Co-Authored-By", log)
        committed = subprocess.run([*git, "show", "--name-only", "--format=", "HEAD"],
                                   capture_output=True, text=True).stdout.split()
        self.assertEqual(committed, ["app-ads.txt"])
        rc, out = self.run_cli("--commit")
        self.assertEqual(rc, 0)
        self.assertIn("já está commitado", out)


if __name__ == "__main__":
    unittest.main()
