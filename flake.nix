{
  description = "Anotador — app de notas em Flutter";

  inputs = {
    nixpkgs.url = "nixpkgs";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # Pesos estáticos da Inter derivados da fonte variável.
      # O Flutter lida muito melhor com TTFs estáticos por peso.
      packages = forAllSystems (pkgs: {
        inter-static = pkgs.runCommand "inter-static"
          {
            nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.fonttools ])) ];
          } ''
          mkdir -p "$out/share/fonts"
          for spec in 400:Regular 500:Medium 600:SemiBold 700:Bold; do
            weight="''${spec%%:*}"
            name="''${spec##*:}"
            python3 -m fontTools.varLib.instancer -q \
              -o "$out/share/fonts/Inter-$name.ttf" \
              ${pkgs.inter}/share/fonts/truetype/InterVariable.ttf \
              "wght=$weight"
          done
          runHook postInstall
        '';


        # App de notas empacotado para Linux.
        #
        # Usa `buildFlutterApplication`, o builder oficial do nixpkgs para Flutter.
        # Ele resolve por conta própria o que estava quebrando a tentativa
        # artesanal: busca as dependências do pub via pub2nix (sem rede, cada
        # pacote com hash próprio) e monta os symlinks de plugin em
        # `linux/flutter/ephemeral/.plugin_symlinks/`, que o CMake exige.
        #
        # Sobre "autocontido": no sentido do Nix, o artefato é reprodutível e
        # todas as dependências ficam fixadas por hash no store — não um binário
        # isolado. O GTK3 **não** é embutido: é dependência de sistema, e as
        # libs deste nixpkgs exigem glibc 2.43+, acima do que o Ubuntu 24.04
        # (glibc 2.39) tem. Para uma máquina NixOS, `nix copy` leva o artefato
        # junto com a closure.
        anotador-linux = pkgs.flutter.buildFlutterApplication (finalAttrs: {
          pname = "anotador";
          version = "1.0.0";

          # `build/`, `.dart_tool/`, `shots/` e `linux/flutter/ephemeral/` são
          # artefatos da compilação local. Sem o filtro, eles entram na fonte
          # carregando o `CMakeCache.txt` desta máquina e symlinks de plugin que
          # só existem aqui, e o CMake aborta em cima de diretório inexistente.
          src = pkgs.lib.cleanSourceWith {
            src = ./.;
            filter = path: type:
              let
                p = toString path;
                base = baseNameOf p;
              in !(
                builtins.elem base [ "build" ".dart_tool" "shots" ".flutter-plugins-dependencies" ]
                || pkgs.lib.hasSuffix "/linux/flutter/ephemeral" p
              );
          };

          # Concatenação, e não interpolação: interpolar copiaria a fonte
          # inteira para o store e qualquer mudança não relacionada invalidaria
          # o hash.
          autoPubspecLock = finalAttrs.src + "/pubspec.lock";

          targetFlutterPlatform = "linux";

          nativeBuildInputs = with pkgs; [
            cmake
            ninja
            pkg-config
            clang
            patchelf
          ];

          # Cabeçalhos do GTK3: o runner nativo linka contra eles no build.
          buildInputs = with pkgs; [ gtk3 ];

          dontConfigure = true;

          # O sandbox do Nix não tem HOME, e o Flutter quer criar
          # `~/.config/flutter` para guardar estado persistente — sem isso o
          # build morre em `_DefaultPersistentToolState`.
          HOME = "./.home";
          XDG_CONFIG_HOME = "./.home/.config";
          XDG_CACHE_HOME = "./.home/.cache";
          # Sem isto o Flutter abre o consentimento de telemetria e sai com
          # código 69 — não há terminal para responder no sandbox.
          CI = "true";
          FLUTTER_SUPPRESS_ANALYTICS = "true";

          preBuild = ''
            mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"

            # O `pubcache` já vem completo e com hash fixado pelo pub2nix, mas o
            # Flutter chama `pub get` sozinho e vai à rede — que o sandbox não
            # tem. Resolver offline primeiro escreve o
            # `.dart_tool/package_config.json` a partir do cache, e o build
            # seguinte não precisa sair para a internet.
            flutter pub get --offline || true
          '';

          # O vazamento que a auditoria visual achou: o `RUNPATH` do binário
          # carregava o caminho absoluto de build desta máquina. O Nix já
          #_padroniza_ o RPATH via `autoPatchelfHook`, mas limpamos mesmo assim
          # para não sobrar caminho da máquina de desenvolvimento.
          postFixup = ''
            for f in "$out/bin/anotador" "$out/lib/"*.so*; do
              [ -f "$f" ] || continue
              patchelf --remove-rpath "$f" 2>/dev/null || true
            done
          '';

          # GTK3 faz parte do closure de runtime, então o hook padrão de wrap
          # já o resolve via `wrapGAppsHook`/RPATH.
          meta = with pkgs.lib; {
            description = "Anotador — app de notas local-first";
            longDescription = ''
              App de notas em Flutter com tema claro/escuro, busca sem acento,
              etiquetas com filtro combinável, lixeira com restauração e
              persistência local via hive_ce. Sem conta e sem nuvem.
            '';
            platforms = platforms.linux;
            mainProgram = "anotador";
            license = pkgs.lib.licenses.mit;
          };
        });
      });
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          name = "anotador-dev";

          packages = with pkgs; [
            flutter
            dart
            jq
            ripgrep
            git
            unzip
            xz
            which
            # Verificação visual: sem desktop environment, usamos Chromium headless.
            chromium
            # Servidor estático para conferir o build web localmente.
            python3
            curl
            inter
          ];

          shellHook = ''
            # Flutter/Dart precisam de diretórios graváveis fora do /nix/store.
            export PUB_CACHE="$HOME/.cache/anotador/pub"
            export CI=true

            mkdir -p "$PUB_CACHE"

            if command -v flutter >/dev/null 2>&1; then
              echo "anotador dev shell — flutter $(flutter --version 2>/dev/null | head -1 | awk '{print $2}')"
            else
              echo "anotador dev shell pronto"
            fi
          '';
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixpkgs-fmt);
    };
}
