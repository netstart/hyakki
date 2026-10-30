#!/usr/bin/env bash
# Instala os hooks git versionados do Hyakki (tools/githooks) neste clone.
# Uso: tools/install_hooks.sh
set -e
cd "$(dirname "$0")/.."
git config core.hooksPath tools/githooks
echo "OK hooks instalados: core.hooksPath = tools/githooks (pre-commit protege os arquivos do site e sincroniza o app-ads.txt)"
