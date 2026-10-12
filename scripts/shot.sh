#!/usr/bin/env bash
# Captura de tela via Chromium headless (não há desktop environment neste host).
#
#   nix develop -c bash scripts/shot.sh <url> <saida.png> [largura] [altura] [espera_ms]
#
# O Flutter Web precisa de tempo para montar o canvas após o load, por isso o
# --virtual-time-budget: ele avança o relógio virtual até a página assentar.
set -euo pipefail

URL="${1:?informe a URL}"
OUT="${2:?informe o arquivo de saída}"
W="${3:-430}"
H="${4:-932}"
BUDGET="${5:-15000}"

CHROME="$(command -v chromium || command -v chromium-browser || command -v google-chrome)"

if [ -z "$CHROME" ]; then
  echo "erro: chromium não encontrado no PATH (use: nix develop -c ...)" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"

HEADLESS_FLAG="--headless"
if ! "$CHROME" --headless --version >/dev/null 2>&1; then
  HEADLESS_FLAG="--headless=new"
fi

# shellcheck disable=SC2086
exec "$CHROME" $HEADLESS_FLAG \
  --disable-gpu \
  --no-sandbox \
  --disable-dev-shm-usage \
  --hide-scrollbars \
  --force-device-scale-factor=2 \
  --enable-unsafe-swiftshader \
  --use-gl=swiftshader \
  --window-size="${W},${H}" \
  --virtual-time-budget="${BUDGET}" \
  --screenshot="$OUT" \
  "$URL"