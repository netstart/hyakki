#!/usr/bin/env bash
# Verificações do Hyakki para Linux/CI (mesmo conteúdo de tools/run_checks.ps1), em paralelo:
# importação primeiro; depois, ao mesmo tempo, a integração em N fatias (--shard=k/N), testes de
# regras, determinismo 1x/2x/3x e 3x Baixa (com o bot padrão e com o arsenal de fogo, gelo e
# clones, --arsenal=...), a jornada do bot pelos três níveis (Kakuriyo, Tokoyo e
# o último chefe, mesmo estado em 1x/2x/3x), estresse, gdlint em partes e os checks em Python
# (textos, licenças, ficha da loja, site irmão netstart.github.io: app-ads.txt gerado do ID do
# AdMob, política e página do jogo lá, sem cópias em docs/). Com tela (DISPLAY/WAYLAND_DISPLAY ou
# Windows; NO_WINDOW=1 pula), também sem --headless: os traços do Stroke iguais aos do motor
# (tests/stroke_pixel_tests.tscn), o mesmo quadro da partida pelos dois caminhos (tests/game_bench.tscn
# --compare-shots --strict) e a navegação entre os menus sem piscar (tests/nav_bench.tscn
# --strict-flicker, em NAV_SHARDS processos).
#
# Ordem e prioridade: começam da mais longa para a mais curta; a jornada roda com a prioridade
# normal e as outras com nice 10 (SAME_PRIORITY=1 desliga), para ela ter um núcleo inteiro.
#
# Cada Godot roda com XDG_DATA_HOME próprio (user:// isolado: nunca o perfil real, e as fatias
# não disputam arquivos). Tarefa sem saída nova por STALL_MINUTES (padrão 8, regra do AGENTS.md)
# é encerrada à força e rodada de novo uma vez; travou de novo = falha. Qualquer falha reprova.
#
# Uso: GODOT=/caminho/godot tools/run_checks.sh
#      SHARDS=N (padrão: núcleos - 4, entre 2 e 12) · STALL_MINUTES=M · ONLY="integracao regras"
#      NO_WINDOW=1 · NAV_SHARDS=N (padrão 3) · SAME_PRIORITY=1
#      MAX_PARALLEL=N (padrão: núcleos − 2, limitado pela memória: (disponível − RESERVE_MB) /
#      GODOT_MEMORY_MB, padrões 4096 e 600) · a fila começa pela mais longa; vaga liberada puxa a próxima
# Logs: build/checks/<data_hora>/<tarefa>.log
set -u
cd "$(dirname "$0")/.."
PROJECT=$(pwd)
GODOT="${GODOT:-godot}"
PY=python3
for c in python3 python; do if "$c" -c "import sys" >/dev/null 2>&1; then PY=$c; break; fi; done
CORES=$(nproc 2>/dev/null || echo 4)
# Memória disponível (MB) pelo /proc/meminfo (Linux e Git Bash); sem ele, não limita.
avail_mb() { awk '/^MemAvailable:/ { printf "%d", $2 / 1024; f = 1 } END { if (!f) print 999999 }' /proc/meminfo 2>/dev/null || echo 999999; }
GODOT_MEMORY_MB="${GODOT_MEMORY_MB:-600}"
RESERVE_MB="${RESERVE_MB:-4096}"
# Teto de processos ao mesmo tempo: núcleos − 2 e o que a memória comporta; o resto espera na fila.
if [ -z "${MAX_PARALLEL:-}" ]; then
  MAX_PARALLEL=$(( CORES - 2 )); by_mem=$(( ($(avail_mb) - RESERVE_MB) / GODOT_MEMORY_MB ))
  [ "$by_mem" -lt "$MAX_PARALLEL" ] && MAX_PARALLEL=$by_mem
fi
[ "$MAX_PARALLEL" -lt 2 ] && MAX_PARALLEL=2
SHARDS="${SHARDS:-$(( MAX_PARALLEL - 4 ))}"
if [ "$SHARDS" -lt 2 ]; then SHARDS=2; fi
if [ "$SHARDS" -gt 12 ]; then SHARDS=12; fi
STALL_MINUTES="${STALL_MINUTES:-8}"
STALL_SECONDS=$(awk "BEGIN { printf \"%d\", $STALL_MINUTES * 60 }")
ONLY="${ONLY:-}"
NAV_SHARDS="${NAV_SHARDS:-3}"
SAME_PRIORITY="${SAME_PRIORITY:-0}"
WINDOW=1
if [ "${NO_WINDOW:-0}" = 1 ]; then WINDOW=0
elif [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ] && ! command -v cygpath >/dev/null 2>&1; then
  WINDOW=0; echo "sem tela (DISPLAY): pulando as tarefas com janela"
fi
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
# Sem --headless (a tarefa desenha de verdade).
window_args() { echo "--path $(printf '%q' "$PROJECT") --log-file $(printf '%q' "$LOGS/godot_$1.log")"; }
# Prioridade: só a jornada (a tarefa mais longa, que não se divide) fica na normal.
nice_for() {
  case "$1" in jornada_*) return ;; esac
  if [ "$SAME_PRIORITY" != 1 ] && command -v nice >/dev/null 2>&1; then echo "nice -n 10"; fi
}

start_task() {
  local name=$1 log="$LOGS/$1.log"
  ATTEMPTS[$name]=$(( ${ATTEMPTS[$name]} + 1 ))
  if [ "${GODOT_TASK[$name]}" = 1 ]; then
    mkdir -p "$TMPROOT/$name"
    local dir="$TMPROOT/$name"
    # Git Bash no Windows: o Godot lê APPDATA (caminho do Windows); no Linux, XDG_DATA_HOME.
    if command -v cygpath >/dev/null 2>&1; then dir=$(cygpath -w "$dir"); fi
    ( export XDG_DATA_HOME="$dir" APPDATA="$dir" HYAKKI_CHECKS_APPDATA="$dir"
      eval "exec $SETSID $(nice_for "$name") ${CMD[$name]}" ) >"$log" 2>&1 &
  else
    ( eval "exec $SETSID $(nice_for "$name") ${CMD[$name]}" ) >"$log" 2>&1 &
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

PEAK_RUNNING=0; MIN_AVAIL=999999
run_parallel() {  # nomes, na ordem de início (a mais longa primeiro)
  local queue=("$@") running=() name
  trap 'for n in "${running[@]+"${running[@]}"}"; do kill_task "$n"; done; exit 130' INT TERM
  while [ ${#running[@]} -gt 0 ] || [ ${#queue[@]} -gt 0 ]; do
    # Vagas livres puxam a fila (um Godot só entra se a memória comportar, mas nunca para tudo).
    while [ ${#queue[@]} -gt 0 ] && [ ${#running[@]} -lt "$MAX_PARALLEL" ]; do
      local avail; avail=$(avail_mb); [ "$avail" -lt "$MIN_AVAIL" ] && MIN_AVAIL=$avail
      if [ ${#running[@]} -gt 0 ] && [ "${GODOT_TASK[${queue[0]}]}" = 1 ] && [ $(( avail - GODOT_MEMORY_MB )) -lt "$RESERVE_MB" ]; then break; fi
      start_task "${queue[0]}"; running+=("${queue[0]}"); queue=("${queue[@]:1}")
    done
    [ ${#running[@]} -gt "$PEAK_RUNNING" ] && PEAK_RUNNING=${#running[@]}
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
    integracao_*|regras|pixels_stroke)
      summary=$(grep -E "^[0-9]+ verificações, [0-9]+ falhas" "$log" | tail -1)
      [ -n "$summary" ] || { ok=0; summary="não chegou ao fim (veja o log)"; }
      grep -q "FALHOU" "$log" && ok=0 ;;
    determinismo_*|arsenal_*)
      summary=$(grep "^FIM " "$log" | tail -1); [ -n "$summary" ] || { ok=0; summary="a partida não chegou ao FIM"; } ;;
    jornada_*)
      summary=$(grep "^FIM " "$log" | tail -1); [ -n "$summary" ] || { ok=0; summary="a partida não chegou ao FIM"; }
      grep -qE "^CHEFES reino=2 tokoyo=true vencidos=.*kappa_elder" "$log" || { ok=0; summary="$summary (sem o Tokoyo e o último chefe: $(grep '^CHEFES ' "$log" | tail -1))"; } ;;
    pixels_partida)
      summary=$(grep "^COMPARA " "$log" | tail -1); [ -n "$summary" ] || { ok=0; summary="sem a linha COMPARA"; }
      grep -q "FALHOU" "$log" && ok=0 ;;
    navegacao_*)
      summary=$(grep -E "^[0-9]+ casos medidos, [0-9]+ acima dos limites" "$log" | tail -1)
      [ -n "$summary" ] || { ok=0; summary="não chegou ao fim (veja o log)"; }
      grep -q "FALHOU" "$log" && ok=0 ;;
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
# Da mais longa para a mais curta: a jornada primeiro, depois as fatias e as partidas do bot.
JOURNEY_END=660
for speed in 1 2 3; do
  add_task "jornada_${speed}x" 1 "$GODOT" $(godot_args "jornada_${speed}x") --fixed-fps 60 -- --bot --seed=7 --god "--speed=$speed" "--quit-at=$JOURNEY_END"
done
for k in $(seq 1 "$SHARDS"); do
  add_task "integracao_$k" 1 "$GODOT" $(godot_args "integracao_$k") --fixed-fps 60 res://tests/integration_tests.tscn -- "--shard=$k/$SHARDS"
done
for speed in 1 2 3; do
  add_task "determinismo_${speed}x" 1 "$GODOT" $(godot_args "determinismo_${speed}x") --fixed-fps 60 -- --bot --seed=7 "--speed=$speed" --quit-at=90
done
add_task determinismo_3x_baixa 1 "$GODOT" $(godot_args determinismo_3x_baixa) --fixed-fps 60 -- --bot --seed=7 --speed=3 --gfx=low --quit-at=90
# Fogo, gelo e clones: o arsenal novo forçado (armas, evoluções e as três uniões), mesmo estado em 1x, 2x, 3x e na Baixa.
ARSENAL="--arsenal=horokubiya,tsurara,kage_bunshin,kagutsuchi,yukionna,senkage,onmyo_taikyoku,kitsune_yomeiri,hyokyo"
for speed in 1 2 3; do
  add_task "arsenal_${speed}x" 1 "$GODOT" $(godot_args "arsenal_${speed}x") --fixed-fps 60 -- --bot --seed=7 "$ARSENAL" "--speed=$speed" --quit-at=60
done
add_task arsenal_3x_baixa 1 "$GODOT" $(godot_args arsenal_3x_baixa) --fixed-fps 60 -- --bot --seed=7 "$ARSENAL" --speed=3 --gfx=low --quit-at=60
add_task estresse 1 "$GODOT" $(godot_args estresse) --fixed-fps 60 -- --bot --seed=7 --stress=500 --log-every=10 --quit-at=30
add_task regras 1 "$GODOT" $(godot_args regras) --script res://tests/run_tests.gd
if [ "$WINDOW" = 1 ]; then
  for k in $(seq 1 "$NAV_SHARDS"); do
    add_task "navegacao_$k" 1 "$GODOT" $(window_args "navegacao_$k") res://tests/nav_bench.tscn -- --strict-flicker --cycles=1 "--shard=$k/$NAV_SHARDS"
  done
  add_task pixels_stroke 1 "$GODOT" $(window_args pixels_stroke) res://tests/stroke_pixel_tests.tscn
  add_task pixels_partida 1 "$GODOT" $(window_args pixels_partida) res://tests/game_bench.tscn -- --bot --seed=7 --stress=500 --bench-seconds=4 --strict "--compare-shots=$LOGS/pixels_partida"
fi
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

echo "== Verificações do Hyakki ($SHARDS fatias de integração, até $MAX_PARALLEL processos ao mesmo tempo, logs em $LOGS)"
if [ ${#IMPORT[@]} -gt 0 ]; then echo "== 1. Importação"; run_parallel "${IMPORT[@]}"; fi
echo "== 2. ${#BATCH[@]} tarefas, até $MAX_PARALLEL ao mesmo tempo"
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
for t in arsenal_1x arsenal_2x arsenal_3x arsenal_3x_baixa; do
  [ -f "$LOGS/$t.log" ] || continue
  line=$(grep "^FIM " "$LOGS/$t.log" | tail -1); echo "$t: $line"; hashes="$hashes ${line##*hash=}"
done
if [ -n "$hashes" ]; then
  if [ "$(tr ' ' '\n' <<<"$hashes" | grep -v '^$' | sort -u | wc -l)" -ne 1 ] || [ "$(wc -w <<<"$hashes")" -ne 4 ]; then
    echo "FALHOU: com fogo, gelo e clones, o estado mudou com a velocidade ou com a qualidade gráfica"; failed=1
  else echo "Fogo, gelo e clones: mesmo estado em 1x, 2x, 3x e 3x Baixa"; fi
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
slow=$(for n in "${!DURATION[@]}"; do echo "${DURATION[$n]} $n"; done | sort -rn | head -5 | awk '{printf "%s%s %ss", (NR > 1 ? ", " : ""), $2, $1}')
[ -z "$slow" ] || echo "Mais lentas: $slow"
echo "Pico: $PEAK_RUNNING tarefas ao mesmo tempo (teto $MAX_PARALLEL); menor memória disponível $MIN_AVAIL MB (reserva $RESERVE_MB MB)"
[ $failed -ne 0 ] || rm -rf "$TMPROOT"
echo "Tempo total: $(( $(date +%s) - START ))s · logs em $LOGS"
if [ $failed -ne 0 ]; then echo "FALHOU"; exit 1; fi
echo "TUDO OK"
