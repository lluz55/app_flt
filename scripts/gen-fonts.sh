#!/usr/bin/env bash
# Copia os pesos estáticos da Inter (derivação `inter-static` do flake)
# para assets/fonts/, para o Flutter usar as fontes empacotadas.
#
#   bash scripts/gen-fonts.sh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Construindo .#inter-static…"
out="$(nix build --no-link --print-out-paths .#inter-static | tail -1)"

mkdir -p assets/fonts
cp -f "$out/share/fonts/"*.ttf assets/fonts/

echo "Fonts em assets/fonts:"
ls -la assets/fonts/