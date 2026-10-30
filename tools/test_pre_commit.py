"""Testes de tools/hooks/pre_commit.py e tools/hooks/guard_site_files.py.
Uso: python -I tools/test_pre_commit.py
"""
import json
import pathlib
import subprocess
import sys
import unittest

TOOLS = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS / "hooks"))
import guard_site_files  # noqa: E402
import pre_commit  # noqa: E402

FORBIDDEN = ["docs/index.html", "docs/privacy-policy.md", "docs/privacy-policy.html",
             "docs/app-ads.txt", "docs/.nojekyll", "docs/outra.html"]
ALLOWED = ["docs/store/listing.md", "docs/licenses/x.pdf", "docs/store/graphics/index.html",
           "README.md", "project.godot", "index.html", "app-ads.txt"]


class PreCommitTests(unittest.TestCase):
    def test_caminhos_proibidos_reprovados(self):
        self.assertEqual(pre_commit.forbidden_paths(FORBIDDEN + ALLOWED), FORBIDDEN)

    def test_caminhos_permitidos(self):
        self.assertEqual(pre_commit.forbidden_paths(ALLOWED), [])

    def test_barra_invertida_normalizada(self):
        self.assertTrue(pre_commit.is_forbidden("docs\\privacy-policy.html"))
        self.assertFalse(pre_commit.is_forbidden("docs\\store\\listing.md"))

    def test_name_status_ignora_remocoes_e_usa_destino_do_rename(self):
        out = "A\tdocs/novo.html\nM\tproject.godot\nD\tdocs/index.html\nR100\tdocs/a.md\tdocs/store/b.md\n"
        self.assertEqual(pre_commit.parse_name_status(out),
                         ["docs/novo.html", "project.godot", "docs/store/b.md"])

    def test_detecta_mudanca_do_app_id(self):
        diff = ('--- a/project.godot\n+++ b/project.godot\n@@ -13 +13 @@\n'
                '-general/android/app_id="ca-app-pub-1~1"\n+general/android/app_id="ca-app-pub-2~2"\n')
        self.assertTrue(pre_commit.app_id_changed(diff))

    def test_ignora_diff_sem_app_id(self):
        diff = '--- a/project.godot\n+++ b/project.godot\n@@ -5 +5 @@\n-config/version="1.0"\n+config/version="1.1"\n'
        self.assertFalse(pre_commit.app_id_changed(diff))
        self.assertFalse(pre_commit.app_id_changed(""))


class GuardSiteFilesTests(unittest.TestCase):
    def run_guard(self, stdin: str) -> subprocess.CompletedProcess:
        return subprocess.run([sys.executable, "-I", str(TOOLS / "hooks" / "guard_site_files.py")],
                              input=stdin, capture_output=True, text=True, cwd=TOOLS.parent)

    def test_bloqueia_caminho_absoluto_proibido(self):
        path = str(TOOLS.parent / "docs" / "privacy-policy.html")
        r = self.run_guard(json.dumps({"tool_input": {"file_path": path}}))
        self.assertEqual(r.returncode, 2)
        self.assertIn("netstart.github.io", r.stderr)
        self.assertIn("hyakki/privacy-policy.md", r.stderr)

    def test_bloqueia_caminho_relativo(self):
        r = self.run_guard(json.dumps({"tool_input": {"file_path": "docs/app-ads.txt"}}))
        self.assertEqual(r.returncode, 2)
        self.assertIn("sync_site.py", r.stderr)

    def test_permite_caminho_normal(self):
        path = str(TOOLS.parent / "docs" / "store" / "listing.md")
        r = self.run_guard(json.dumps({"tool_input": {"file_path": path}}))
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stderr, "")

    def test_permite_mesmo_nome_fora_do_repo(self):
        path = str(TOOLS.parent.parent / "netstart.github.io" / "privacy-policy.html")
        r = self.run_guard(json.dumps({"tool_input": {"file_path": path}}))
        self.assertEqual(r.returncode, 0)

    def test_json_invalido_sai_em_silencio(self):
        for stdin in ("isto não é json", "{}", '{"tool_input": {}}', '{"tool_input": {"file_path": 3}}'):
            r = self.run_guard(stdin)
            self.assertEqual(r.returncode, 0, stdin)
            self.assertEqual(r.stderr, "")

    def test_mensagem_equivalente(self):
        self.assertIn("hyakki/index.html", guard_site_files.message("docs/index.html"))
        self.assertIn("hyakki/outra.html", guard_site_files.message("docs/outra.html"))


if __name__ == "__main__":
    unittest.main()
