#!/usr/bin/env bash
# Verificações do Hyakki para Linux/CI (mesmo conteúdo de tools/run_checks.ps1, sem o estresse):
# importação, testes de regras, gdlint, textos, licenças, ficha da loja, site irmão
# (netstart.github.io: app-ads.txt gerado do ID do AdMob, política e página do jogo lá,
# sem cópias em docs/), integração e determinismo 1x/2x/3x.  Uso: GODOT=/caminho/godot tools/run_checks.sh
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
failed=0
PY=python3
for c in python3 python; do if "$c" -c "import sys" >/dev/null 2>&1; then PY=$c; break; fi; done
run_godot() { timeout 600 "$GODOT" --headless --path . "$@" 2>&1; }

echo "== 1. Importação"
out=$(run_godot --import)
if grep -qE "SCRIPT ERROR|Parse Error|Compile Error" <<<"$out"; then grep -E "SCRIPT ERROR|Parse Error|Compile Error" <<<"$out"; failed=1; else echo ok; fi

echo "== 2. Testes de regras"
out=$(run_godot --script res://tests/run_tests.gd); rc=$?
grep -E "verificações|FALHOU" <<<"$out"
if [ $rc -ne 0 ] || grep -qE "FALHOU|SCRIPT ERROR" <<<"$out"; then failed=1; fi

echo "== 3. Lint"
gdlint scripts tests || failed=1

echo "== 4. Textos, licenças, ficha da loja e site irmão"
"$PY" -I tools/build_i18n.py --check || failed=1
"$PY" -I tools/check_licenses.py || failed=1
"$PY" -I tools/check_store_listing.py || failed=1
"$PY" -I tools/test_sync_site.py || failed=1
"$PY" -I tools/test_pre_commit.py || failed=1
"$PY" -I tools/sync_site.py --check || failed=1

echo "== 5. Testes de integração"
out=$(run_godot res://tests/integration_tests.tscn); rc=$?
grep -E "verificações|FALHOU|SCRIPT ERROR" <<<"$out"
if [ $rc -ne 0 ] || grep -qE "FALHOU|SCRIPT ERROR" <<<"$out"; then failed=1; fi

echo "== 6. Determinismo (1x, 2x, 3x)"
hashes=""
for speed in 1 2 3; do
  line=$(run_godot --fixed-fps 60 -- --bot --seed=7 --speed=$speed --quit-at=90 | grep "^FIM " | tail -1)
  echo "${speed}x: $line"
  hashes="$hashes ${line##*hash=}"
done
if [ "$(tr ' ' '\n' <<<"$hashes" | grep -v '^$' | sort -u | wc -l)" -ne 1 ]; then
  echo "FALHOU: o estado mudou com a velocidade"; failed=1
fi

if [ $failed -ne 0 ]; then echo "FALHOU"; exit 1; fi
echo "TUDO OK"
