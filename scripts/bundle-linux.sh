#!/usr/bin/env bash
# Torna o bundle do Linux autocontido.
#
# `flutter build linux` produz um diretório com o binário e as duas bibliotecas
# do Flutter, e **não** com GTK3. O GTK é dependência de sistema, então o bundle
# só roda num host que já tenha `libgtk-3.so.0` instalado. Fora do NixOS dá erro
# de "libgtk-3.so.0 not found" mesmo com o `libflutter_linux_gtk.so` presente ao
# lado — aquele é o motor do Flutter, e ele próprio declara `NEEDED libgtk-3`.
#
# Este script copia a árvore completa de dependências para dentro de `lib/` e
# reescreve o RPATH de tudo para `$ORIGIN`, de modo que o diretório resultante
# roda sozinho, sem GTK no sistema e sem o nix store por perto.
#
# Uso:
#   nix develop -c bash scripts/bundle-linux.sh
#   ./build/linux/x64/release/bundle/anotador

set -euo pipefail

BUNDLE="${1:-build/linux/x64/release/bundle}"
LIB="$BUNDLE/lib"

# Bibliotecas que todo Linux tem e que não fazem sentido embutir: embutir a
# glibc quebra a compatibilidade, porque a libc do build seria usada no lugar da
# do host.
KEEP_ON_HOST='^(libc|libm|libdl|libpthread|librt|libresolv|libgcc_s|ld-linux[^/]*)\.so'

copy_deps() {
  local bin="$1"
  local line soname path base

  # `ldd` imprime "nome => caminho (endereço)"; o caminho é o que queremos.
  while read -r line; do
    path="${line##*=> }"
    path="${path%% (*}"
    [[ "$path" == "$line" ]] && continue          # linha sem "=>" (ex.: loader)
    [[ -f "$path" ]] || continue
    base="$(basename "$path")"
    soname="$base"

    if [[ "$soname" =~ $KEEP_ON_HOST ]]; then
      continue
    fi

    if [[ ! -e "$LIB/$soname" ]]; then
      cp -L "$path" "$LIB/$soname"
      # As libs do nix store vêm 444; o patchelf precisa escrever no lugar.
      chmod u+w "$LIB/$soname"
      # Cada lib precisa achar as irmãs no mesmo diretório.
      patchelf --remove-rpath "$LIB/$soname" 2>/dev/null || true
      patchelf --set-rpath '$ORIGIN' "$LIB/$soname"
      # A árvore é recursiva: as libs copiadas também podem ter NEEDED.
      copy_deps "$LIB/$soname"
    fi
  done < <(ldd "$bin" 2>/dev/null)
}

# Ponto de entrada: os três artefatos que o Flutter gera.
for root in "$BUNDLE/anotador" "$LIB/libflutter_linux_gtk.so" "$LIB/libapp.so"; do
  [[ -f "$root" ]] || { echo "faltando: $root (rode 'flutter build linux' antes)" >&2; exit 1; }
  copy_deps "$root"
done

# O RPATH tem que ser relativo a cada arquivo, e não igual para todos: `$ORIGIN`
# é o diretório do próprio objeto. O binário está na raiz do bundle, então
# precisa de `$ORIGIN/lib`; as duas libs do Flutter já moram em `lib/`, então
# para elas `$ORIGIN` **é** `lib` — escrever `$ORIGIN/lib` ali faz o loader
# procurar em `lib/lib/`, que não existe.
patchelf --remove-rpath "$BUNDLE/anotador" 2>/dev/null || true
patchelf --set-rpath '$ORIGIN/lib' "$BUNDLE/anotador"

for root in "$LIB/libflutter_linux_gtk.so" "$LIB/libapp.so"; do
  patchelf --remove-rpath "$root" 2>/dev/null || true
  patchelf --set-rpath '$ORIGIN' "$root"
done

echo "bundle autocontido: $(du -sh "$BUNDLE" | cut -f1) em $(ls "$LIB" | wc -l) libs"