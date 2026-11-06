#!/usr/bin/env bash
# Verificações do Hyakki para Linux/CI (mesmo conteúdo de tools/run_checks.ps1), em paralelo:
# importação primeiro; depois, ao mesmo tempo, a integração em N fatias (--shard=k/N), testes de
# regras, determinismo 1x/2x/3x e 3x Baixa, a jornada do bot pelos três níveis (Kakuriyo, Tokoyo e
# o último chefe, mesmo estado em 1x/2x/3x), estresse, gdlint em partes e os checks em Python
# (textos, licenças, ficha da loja, site irmão netstart.github.io: app-ads.txt gerado do ID do
# AdMob, política e página do jogo lá, sem cópias em docs/).
#
# Cada Godot roda com XDG_DATA_HOME próprio (user:// isolado: nunca o perfil real, e as fatias
# não disputam arquivos). Tarefa sem saída nova por STALL_MINUTES (padrão 8, regra do AGENTS.md)
# é encerrada à força e rodada de novo uma vez; travou de novo = falha. Qualquer falha reprova.
#
# Uso: GODOT=/caminho/godot tools/run_checks.sh
#      SHARDS=N (padrão: núcleos - 4, entre 2 e 12) · STALL_MINUTES=M · ONLY="integracao regras"
# Logs: build/checks/<data_hora>/<tarefa>.log
set -u
cd "$(dirname "$0")/.."
PROJECT=$(pwd)
GODOT="${GODOT:-godot}"
PY=python3
for c in python3 python; do if "$c" -c "import sys" >/dev/null 2>&1; then PY=$c; break; fi; done
CORES=$(nproc 2>/dev/null || echo 4)
SHARDS="${SHARDS:-$(( CORES - 4 ))}"
if [ "$SHARDS" -lt 2 ]; then SHARDS=2; fi
if [ "$SHARDS" -gt 12 ]; then SHARDS=12; fi
STALL_MINUTES="${STALL_MINUTES:-8}"
STALL_SECONDS=$(awk "BEGIN { printf \"%d\", $STALL_MINUTES * 60 }")
ONLY="${ONLY:-}"
STAMP=$(date +%Y-%m-%d_%H-%M-%S)
LOGS="$PROJECT/build/checks/$STAMP"
TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/hyakki-checks.XXXXXX")
mkdir -p "$LOGS"
START=$(date +%s)
failed=0

# setsid põe cada tarefa num grupo próprio (para encerrar a árvore toda); o Git Bash não tem.
SETSID=$(command -v setsid || true)
declare -A CMD GODOT_TASK PID ATTEMPTS LASTSIZE LASTCHANGE T0 DURATION CODE
ORDER=()

add_task() {  # nome godot(0/1) comando...
  local name=$1 godot=$2; shift 2
  if [ -n "$ONLY" ]; then
    local keep=0 w
    for w in $ONLY; do case "$name" in "$w"*) keep=1 ;; esac; done
    [ $keep -eq 1 ] || return 0
  fi
  ORDER+=("$name"); GODOT_TASK[$name]=$godot; ATTEMPTS[$name]=0
  CMD[$name]=$(printf '%q ' "$@")
}

godot_args() { echo "--headless --path $(printf '%q' "$PROJECT") --log-file $(printf '%q' "$LOGS/godot_$1.log")"; }

start_task() {
  local name=$1 log="$LOGS/$1.log"
  ATTEMPTS[$name]=$(( ${ATTEMPTS[$name]} + 1 ))
  if [ "${GODOT_TASK[$name]}" = 1 ]; then
    mkdir -p "$TMPROOT/$name"
    local dir="$TMPROOT/$name"
    # Git Bash no Windows: o Godot lê APPDATA (caminho do Windows); no Linux, XDG_DATA_HOME.
    if command -v cygpath >/dev/null 2>&1; then dir=$(cygpath -w "$dir"); fi
    ( export XDG_DATA_HOME="$dir" APPDATA="$dir" HYAKKI_CHECKS_APPDATA="$dir"
      eval "exec $SETSID ${CMD[$name]}" ) >"$log" 2>&1 &
  else
    ( eval "exec $SETSID ${CMD[$name]}" ) >"$log" 2>&1 &
  fi
  PID[$name]=$!; LASTSIZE[$name]=-1; LASTCHANGE[$name]=$(date +%s); T0[$name]=$(date +%s)
}

# Encerra a tarefa e os filhos (com setsid, o grupo inteiro; sem ele, os filhos diretos e o processo).
kill_task() {
  local p=${PID[$1]}
  kill -9 -- "-$p" 2>/dev/null || { pkill -9 -P "$p" 2>/dev/null; kill -9 "$p" 2>/dev/null; }
  if command -v taskkill >/dev/null 2>&1; then taskkill //F //T //PID "$(cat /proc/$p/winpid 2>/dev/null)" >/dev/null 2>&1; fi
  wait "$p" 2>/dev/null
}

run_parallel() {  # nomes...
  local running=("$@") name
  for name in "${running[@]}"; do start_task "$name"; done
  trap 'for n in "${running[@]}"; do kill_task "$n"; done; exit 130' INT TERM
  while [ ${#running[@]} -gt 0 ]; do
    sleep 0.5
    local still=()
    for name in "${running[@]}"; do
      if ! kill -0 "${PID[$name]}" 2>/dev/null; then
        wait "${PID[$name]}"; CODE[$name]=$?; DURATION[$name]=$(( $(date +%s) - ${T0[$name]} ))
        report "$name"; continue
      fi
      local size now; size=$(stat -c %s "$LOGS/$name.log" 2>/dev/null || echo 0); now=$(date +%s)
      if [ "$size" != "${LASTSIZE[$name]}" ]; then LASTSIZE[$name]=$size; LASTCHANGE[$name]=$now
      elif [ $(( now - ${LASTCHANGE[$name]} )) -ge "$STALL_SECONDS" ]; then
        kill_task "$name"
        if [ "${ATTEMPTS[$name]}" -lt 2 ]; then
          echo "  $name: $STALL_MINUTES min sem saída; encerrada à força e rodada de novo"
          cp "$LOGS/$name.log" "$LOGS/${name}_travou.log"; start_task "$name"
        else
          CODE[$name]=124; DURATION[$name]=$(( now - ${T0[$name]} ))
          echo "  $name: TRAVOU ($STALL_MINUTES min sem saída, encerrada à força)"; failed=1; continue
        fi
      fi
      still+=("$name")
    done
    running=("${still[@]+"${still[@]}"}")
  done
  trap - INT TERM
}

# Veredito de cada tarefa (pelo log e pelo código de saída).
report() {
  local name=$1 log="$LOGS/$1.log" ok=1 summary
  # A importação vale pelos erros de script no log (o código de saída do --import não conta).
  [ "${CODE[$name]}" = 0 ] || [ "$name" = importacao ] || ok=0
  if [ "${GODOT_TASK[$name]}" = 1 ] && grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$log"; then ok=0; fi
  case "$name" in
    integracao_*|regras)
      summary=$(grep -E "^[0-9]+ verificações, [0-9]+ falhas" "$log" | tail -1)
      [ -n "$summary" ] || { ok=0; summary="não chegou ao fim (veja o log)"; }
      grep -q "FALHOU" "$log" && ok=0 ;;
    determinismo_*)
      summary=$(grep "^FIM " "$log" | tail -1); [ -n "$summary" ] || { ok=0; summary="a partida não chegou ao FIM"; } ;;
    jornada_*)
      summary=$(grep "^FIM " "$log" | tail -1); [ -n "$summary" ] || { ok=0; summary="a partida não chegou ao FIM"; }
      grep -qE "^CHEFES reino=2 tokoyo=true vencidos=.*kappa_elder" "$log" || { ok=0; summary="$summary (sem o Tokoyo e o último chefe: $(grep '^CHEFES ' "$log" | tail -1))"; } ;;
    estresse)
      summary=$(grep -E "^DESEMPENHO|pior por sistema" "$log" | tail -1); [ -n "$summary" ] || { ok=0; summary="sem linha de DESEMPENHO"; } ;;
    importacao) summary="sem erros de script" ;;
    *) summary=$(grep -v '^\s*$' "$log" | tail -1) ;;
  esac
  if [ "$ok" = 1 ]; then printf '  %-24s %5ss  ok      %s\n' "$name" "${DURATION[$name]}" "$summary"
  else
    failed=1; printf '  %-24s %5ss  FALHOU  %s (log: %s)\n' "$name" "${DURATION[$name]}" "$summary" "$log"
    grep -E "FALHOU|SCRIPT ERROR|Parse Error|Error" "$log" | head -20 | sed 's/^/    /'
  fi
}

# --- Tarefas ---------------------------------------------------------------------------
ORDER=()
add_task importacao 1 "$GODOT" $(godot_args importacao) --import
IMPORT=("${ORDER[@]+"${ORDER[@]}"}")
ORDER=()
for k in $(seq 1 "$SHARDS"); do
  add_task "integracao_$k" 1 "$GODOT" $(godot_args "integracao_$k") --fixed-fps 60 res://tests/integration_tests.tscn -- "--shard=$k/$SHARDS"
done
add_task regras 1 "$GODOT" $(godot_args regras) --script res://tests/run_tests.gd
for speed in 1 2 3; do
  add_task "determinismo_${speed}x" 1 "$GODOT" $(godot_args "determinismo_${speed}x") --fixed-fps 60 -- --bot --seed=7 "--speed=$speed" --quit-at=90
done
add_task determinismo_3x_baixa 1 "$GODOT" $(godot_args determinismo_3x_baixa) --fixed-fps 60 -- --bot --seed=7 --speed=3 --gfx=low --quit-at=90
# Jornada pelos três níveis (RiftPortal): o bot invencível chega ao Tokoyo e vence o último chefe.
JOURNEY_END=660
for speed in 1 2 3; do
  add_task "jornada_${speed}x" 1 "$GODOT" $(godot_args "jornada_${speed}x") --fixed-fps 60 -- --bot --seed=7 --god "--speed=$speed" "--quit-at=$JOURNEY_END"
done
add_task estresse 1 "$GODOT" $(godot_args estresse) --fixed-fps 60 -- --bot --seed=7 --stress=500 --log-every=10 --quit-at=30
if command -v gdlint >/dev/null 2>&1; then
  mapfile -t GD < <(find scripts tests -name '*.gd' | sort)
  PARTS=6; i=0
  for p in $(seq 1 $PARTS); do
    part=(); for ((j = p - 1; j < ${#GD[@]}; j += PARTS)); do part+=("${GD[$j]}"); done
    add_task "lint_$p" 0 gdlint "${part[@]}"
  done
else echo "gdlint não instalado (pip install \"gdtoolkit==4.*\"); pulando"; fi
add_task py_i18n 0 "$PY" -I tools/build_i18n.py --check
add_task py_licencas 0 "$PY" -I tools/check_licenses.py
add_task py_ficha_loja 0 "$PY" -I tools/check_store_listing.py
add_task py_test_sync_site 0 "$PY" -I tools/test_sync_site.py
add_task py_test_pre_commit 0 "$PY" -I tools/test_pre_commit.py
add_task py_sync_site 0 "$PY" -I tools/sync_site.py --check
BATCH=("${ORDER[@]+"${ORDER[@]}"}")

echo "== Verificações do Hyakki ($SHARDS fatias de integração, logs em $LOGS)"
if [ ${#IMPORT[@]} -gt 0 ]; then echo "== 1. Importação"; run_parallel "${IMPORT[@]}"; fi
echo "== 2. ${#BATCH[@]} tarefas em paralelo"
[ ${#BATCH[@]} -eq 0 ] || run_parallel "${BATCH[@]}"

# --- Resumo ----------------------------------------------------------------------------
echo "== Resumo"
total=0; fails=0
for k in $(seq 1 "$SHARDS"); do
  line=$(grep -E "^[0-9]+ verificações, [0-9]+ falhas" "$LOGS/integracao_$k.log" 2>/dev/null | tail -1)
  [ -n "$line" ] && { total=$(( total + ${line%% *} )); f=${line#*, }; fails=$(( fails + ${f%% *} )); }
done
[ -f "$LOGS/integracao_1.log" ] && echo "Integração: $total verificações, $fails falhas em $SHARDS fatias"
hashes=""
for t in determinismo_1x determinismo_2x determinismo_3x determinismo_3x_baixa; do
  [ -f "$LOGS/$t.log" ] || continue
  line=$(grep "^FIM " "$LOGS/$t.log" | tail -1); echo "$t: $line"; hashes="$hashes ${line##*hash=}"
done
if [ -n "$hashes" ]; then
  if [ "$(tr ' ' '\n' <<<"$hashes" | grep -v '^$' | sort -u | wc -l)" -ne 1 ] || [ "$(wc -w <<<"$hashes")" -ne 4 ]; then
    echo "FALHOU: o estado mudou com a velocidade ou com a qualidade gráfica"; failed=1
  else echo "Determinismo: mesmo estado em 1x, 2x, 3x e 3x Baixa"; fi
fi
hashes=""
for t in jornada_1x jornada_2x jornada_3x; do
  [ -f "$LOGS/$t.log" ] || continue
  line=$(grep "^FIM " "$LOGS/$t.log" | tail -1); hashes="$hashes ${line##*hash=}"
done
if [ -n "$hashes" ]; then
  if [ "$(tr ' ' '\n' <<<"$hashes" | grep -v '^$' | sort -u | wc -l)" -ne 1 ] || [ "$(wc -w <<<"$hashes")" -ne 3 ]; then
    echo "FALHOU: jornada: o estado mudou com a velocidade"; failed=1
  else echo "Jornada: Kakuriyo, Tokoyo e o último chefe com o mesmo estado em 1x, 2x e 3x"; fi
fi
[ $failed -ne 0 ] || rm -rf "$TMPROOT"
echo "Tempo total: $(( $(date +%s) - START ))s · logs em $LOGS"
if [ $failed -ne 0 ]; then echo "FALHOU"; exit 1; fi
echo "TUDO OK"
