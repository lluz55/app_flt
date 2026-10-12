#!/usr/bin/env bash
# Pipeline de verificação visual: compila o Flutter Web, sobe um servidor
# estático e captura screenshots com Chromium headless (não há desktop
# environment neste host).
#
#   nix develop -c bash scripts/capture.sh <tema> <nome>
#
# Ex.: nix develop -c bash scripts/capture.sh dark mobile-escuro
set -euo pipefail

THEME="${1:-dark}"
NAME="${2:-shot}"
PORT="${PORT:-8099}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/shots"

cd "$ROOT"
mkdir -p "$OUT_DIR"

echo "==> Compilando Flutter Web (FORCE_THEME=$THEME, SEED_DEMO=true)…"
flutter build web \
  --release \
  --dart-define="FORCE_THEME=$THEME" \
  --dart-define="SEED_DEMO=true" \
  2>&1 | tail -5

# Nota: em release o Flutter Web usa IndexedDB, então cada build começa limpo
# no perfil do Chromium headless.

echo "==> Subindo servidor estático em :$PORT"
python3 -m http.server "$PORT" --directory build/web >/dev/null 2>&1 &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null || true' EXIT

# Espera o servidor responder.
for _ in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then break; fi
  sleep 0.5
done

capture() {
  local out="$1" w="$2" h="$3" budget="${4:-20000}"
  echo "==> Capturando $out (${w}x${h})"
  bash "$ROOT/scripts/shot.sh" \
    "http://127.0.0.1:$PORT/" "$OUT_DIR/$out.png" "$w" "$h" "$budget" \
    2>/dev/null || echo "   (falhou: $out)"
}

# Celular (iPhone 14 Pro lógico) e desktop largo.
capture "${NAME}-mobile"  430 932
capture "${NAME}-desktop" 1440 900

echo "==> Screenshots em $OUT_DIR"
ls -la "$OUT_DIR"/*.png 2>/dev/null || true