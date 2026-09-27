{
  description = "Minimal F* verified project template (hello world)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/c31cf09";
    flake-utils.url = "github:numtide/flake-utils";
    fstar = {
      url = "github:dysinger/fstar/v2025.10.06+lsp";
      flake = false;
    };
    karamel = {
      url = "github:dysinger/karamel/coextract";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (_final: prev:
              if prev.stdenv.isDarwin && prev.stdenv.isAarch64 then {
                # Skip OCaml's own testsuite on aarch64-darwin.
                ocaml-ng = prev.ocaml-ng // {
                  ocamlPackages_5_3 = prev.ocaml-ng.ocamlPackages_5_3.overrideScope (_: _: {
                    ocaml = prev.ocaml-ng.ocamlPackages_5_3.ocaml.overrideAttrs (_: {
                      checkPhase = "true";
                    });
                  });
                };
              } else { })
            (_final: prev:
              let
                z3 = prev.callPackage (inputs.fstar + "/.nix/z3.nix") { };
                ocamlPackages = prev.ocaml-ng.ocamlPackages_5_3;
                fstar = (ocamlPackages.callPackage (inputs.fstar + "/.nix/fstar.nix") {
                  version = "unknown";
                  inherit z3;
                }).overrideAttrs (old: {
                  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.git ];
                });
                gtime = prev.runCommand "gtime" { } ''
                  mkdir -p $out/bin
                  ln -s ${prev.time}/bin/time $out/bin/gtime
                '';
                # fstar-checked: ulib .checked files (pre-verified by fstar compiler).
                fstar-checked = prev.runCommand "fstar-checked"
                  { nativeBuildInputs = [ fstar ]; }
                  ''
                    mkdir -p $out
                    cp ${fstar}/lib/fstar/ulib.checked/*.checked $out/ 2>/dev/null || true
                    echo "checked: $(ls $out/*.checked 2>/dev/null | wc -l) files"
                  '';
                karamel = (prev.callPackage (inputs.karamel + "/.nix/karamel.nix") {
                  inherit fstar ocamlPackages z3;
                  version = "unknown";
                }).overrideAttrs (old: {
                  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ gtime ];
                });
                # fstar-krml: krmllib .krml + ulib .fsti/.fst (flat, for downstream
                # typecheckers and the Makefile-driven C link).
                fstar-krml = prev.runCommand "fstar-krml"
                  { nativeBuildInputs = [ fstar karamel ]; }
                  ''
                    mkdir -p $out/krml $out/extract
                    cp ${karamel.home}/krmllib/.extract/*.krml $out/krml/ 2>/dev/null || true
                    ULIB_DIR=${fstar}/lib/fstar/ulib
                    find $ULIB_DIR -name '*.fsti' -exec cp {} $out/extract/ \; 2>/dev/null || true
                    find $ULIB_DIR -name '*.fst' -exec cp {} $out/extract/ \; 2>/dev/null || true
                    echo "krml: $(ls $out/krml/*.krml 2>/dev/null | wc -l) files"
                    echo "extract: $(ls $out/extract/ 2>/dev/null | wc -l) files"
                  '';
              in
              {
                inherit fstar karamel fstar-checked fstar-krml;
                # The OCaml 5.3 package set F* itself is built against
                # (carries batteries/pprint/stdint/yojson/zarith, the deps
                # fstar.lib's OCaml runtime requires for ocamlfind linking).
                ocamlPackages = prev.ocaml-ng.ocamlPackages_5_3;
              })
          ];
        };

        inherit (pkgs) stdenv fstar karamel fstar-checked fstar-krml;
        inherit (pkgs) ocamlPackages;

        # The F* module name, threaded into downstream stages.  Changing it
        # must also update the Hello_* C symbols in src/main.c (which cannot
        # be auto-derived without codegen).
        hello-module = "Hello";

        # The package (verify + extract), in the codec/default.nix shape.
        _hello = import ./default.nix {
          inherit pkgs;
          module-name = hello-module;
        };
        inherit (_hello) hello-checked hello-krml;

      in
      {
        packages = {
          inherit hello-checked hello-krml;
          default = self.packages.${system}.hello-krml;
        };

        # The native executable, produced by the Makefile `exe` target (which
        # links the checked-in src/main.c driver against the extracted module
        # and the krmllib runtime).  Pre-populates the pre-built hello-krml so
        # `make` skips F* re-extraction.
        packages.hello-exe = pkgs.stdenv.mkDerivation {
          pname = "hello-exe";
          version = "0.1.0";
          src = ./. ;
          nativeBuildInputs = [ pkgs.gnumake ];
          # fstar is needed by the Makefile's `ULIB := $(shell $(FSTAR)
          # --locate_lib ...)` at parse time; karamel + fstar-krml by the link;
          # hello-krml is pre-populated.  fstar-checked is intentionally
          # absent: `make exe` does not reach `make check`, so it is dead input.
          buildInputs = [ pkgs.stdenv.cc fstar karamel fstar-krml hello-krml ];
          buildPhase = ''
            mkdir -p out/krml
            # Pre-populate with pre-built .krml to skip F* re-extraction.
            cp ${hello-krml}/*.krml out/krml/
            chmod +w out/krml/*.krml
            touch out/krml/*.krml
            make exe \
              CC="${pkgs.stdenv.cc}/bin/cc" \
              FSTAR="${fstar}/bin/fstar.exe" \
              KRML="${karamel}/bin/krml" \
              KRML_HOME="${karamel.home}" \
              KRM_LIB="${karamel.home}/krmllib" \
              KRM_INC="-I${karamel.home}/include -I${karamel.home}/krmllib/c -I${karamel.home}/krmllib/dist/minimal" \
              FSTAR_KRML="${fstar-krml}"
          '';
          installPhase = ''
            mkdir -p $out/bin
            cp out/hello $out/bin/
          '';
        };

        # Wasm: krml's wasm backend emits `<Module>.wasm` plus a JS loader
        # bundle.  Ship all of it (run with `node main.js`).
        #
        # KaRaMeL has a first-class wasm backend (`krml -backend wasm` / `-wasm`,
        # see `krml --help`): it emits the `<Module>.wasm` module and its JS
        # loader directly, so this derivation invokes it rather than a `make`
        # target (there is no Makefile link step for wasm).
        #
        # `-no-prefix` strips the `<Module>_` prefix from the exported entry
        # point, so `Hello.main` is exported as plain `main` — the name the
        # generated JS loader (`main.js`) looks for.  Without it the export is
        # `Hello_main` and the loader reports "no main in current scope".
        packages.hello-wasm = pkgs.stdenv.mkDerivation {
          name = "hello-wasm";
          src = ./.;
          nativeBuildInputs = [ fstar karamel ];
          buildPhase = ''
            mkdir -p wasm-out
            export KRML_HOME="${karamel.home}"
            ${karamel}/bin/krml \
              -tmpdir wasm-out \
              -backend wasm \
              -no-prefix ${hello-module} \
              ${hello-krml}/${hello-module}.krml
          '';
          installPhase = ''
            mkdir -p $out
            cp wasm-out/* $out/ 2>/dev/null
            # Guard against a case/suffix mismatch between the module name in
            # shell.js's my_modules list, the emitted .wasm filename, and the
            # JS loader's hardcoded `<Module>.wasm` reference (all
            # case-sensitive).  Compare the exact basename, not a glob, so a
            # rename that changes the on-disk case fails loudly here rather
            # than at `node main.js` runtime with "no main in current scope".
            if [ ! -f "$out/${hello-module}.wasm" ]; then
              echo "ERROR: expected $out/${hello-module}.wasm, but found:" >&2
              ls -1 "$out" | grep '\.wasm$' >&2 || true
              exit 1
            fi
            echo "wasm: $(ls $out/*.wasm 2>/dev/null | wc -l) .wasm file(s)"
          '';
        };

        # fsdoc: extract `(** ... *)` comments to Markdown.
        packages.hello-fsdoc = pkgs.stdenv.mkDerivation {
          name = "hello-fsdoc";
          src = ./.;
          nativeBuildInputs = [ pkgs.python3 ];
          buildPhase = ''
            mkdir -p $out
            ${pkgs.python3}/bin/python3 scripts/fsdoc.py $out/fstar-docs.md
          '';
          installPhase = "true";
        };

        # ── F* source extraction backends ───────────────────────────────
        #
        # `fstar.exe --codegen <OCaml|FSharp|krml>` extracts the module to a
        # source file in the target language: OCaml → .ml, F# → .fs, krml → .krml
        # (the intermediate IR KaRaMeL consumes).  Each runs the same
        # verify-then-extract pipeline as hello-checked/hello-krml.

        # OCaml source (`--codegen OCaml`), then compiled via
        # `ocamlPackages.buildDunePackage` (dune, the canonical OCaml Nix build
        # tool) against the fstar OCaml runtime (`fstar.lib`).
        packages.hello-ocaml = let
          # Extract Hello.ml + a minimal dune scaffold into a source tree that
          # buildDunePackage can consume.  The fstar runtime (`fstar.lib`) is a
          # findlib package living at ${fstar}/lib/fstar; it is exposed via
          # OCAMLPATH in the build below.
          hello-ocaml-src = pkgs.stdenv.mkDerivation {
            name = "hello-ocaml-src";
            src = ./. ;
            nativeBuildInputs = [ fstar ];
            buildPhase = ''
              mkdir -p $out
              export ULIB="${fstar}/lib/fstar/ulib"
              ${fstar}/bin/fstar.exe \
                --no_default_includes --include $ULIB --include ./src \
                --codegen OCaml --odir $out \
                src/${hello-module}.fst || exit 1
              cat > $out/dune-project <<'DUNE_PROJECT'
(lang dune 3.11)
(name hello-ocaml)
(package (name hello-ocaml))
DUNE_PROJECT
              cat > $out/dune <<'DUNE'
(library
 (name hello)
 (public_name hello-ocaml)
 (modules Hello)
 (libraries fstar.lib))
DUNE
            '';
            installPhase = "true";
          };
        in
        ocamlPackages.buildDunePackage {
          pname = "hello-ocaml";
          version = "0.1.0";
          src = hello-ocaml-src;
          # Expose the fstar OCaml runtime (fstar.lib findlib package) plus the
          # transitive deps fstar.lib's META declares: batteries pprint stdint
          # yojson zarith ppx_deriving*.  All live in ocamlPackages (5.3).
          propagatedBuildInputs = [ fstar ];
          buildInputs = with ocamlPackages; [
            batteries pprint stdint yojson zarith
            ppx_deriving ppx_deriving_yojson
          ];
          OCAMLPATH = "${fstar}/lib";
        };

        # F# source (`--codegen FSharp`).
        packages.hello-fsharp = pkgs.stdenv.mkDerivation {
          name = "hello-fsharp";
          src = ./. ;
          nativeBuildInputs = [ fstar ];
          buildPhase = ''
            mkdir -p $out
            export ULIB="${fstar}/lib/fstar/ulib"
            ${fstar}/bin/fstar.exe \
              --no_default_includes --include $ULIB --include ./src \
              --codegen FSharp --odir $out \
              src/${hello-module}.fst || exit 1
          '';
          installPhase = "true";
        };

        # ── KaRaMeL C/Rust backends ────────────────────────────────────
        #
        # KaRaMeL `-backend` emits from the extracted .krml: `c` (.c/.h), `rust`
        # (.rs), or `wasm` (.wasm).  These consume the pre-built hello-krml
        # output (never re-extract from source).

        # Native C library, compiled to a shared object (`.so`/`.dylib`).
        # Distinct from hello-exe (which links a main driver).
        packages.hello-native = pkgs.stdenv.mkDerivation {
          name = "hello-native";
          src = ./. ;
          nativeBuildInputs = [ fstar karamel pkgs.stdenv.cc ];
          buildPhase = ''
            mkdir -p native-out
            export KRML_HOME="${karamel.home}"
            ${karamel}/bin/krml \
              -skip-compilation \
              -tmpdir native-out \
              ${hello-krml}/${hello-module}.krml
            cc -shared -fPIC \
              -I"${karamel.home}/include" \
              -I"${karamel.home}/krmllib/c" \
              -I"${karamel.home}/krmllib/dist/minimal" \
              native-out/${hello-module}.c \
              -o native-out/libhello.so
          '';
          installPhase = ''
            mkdir -p $out/lib $out/include
            cp native-out/*.so $out/lib/ 2>/dev/null
            cp native-out/${hello-module}.h $out/include/ 2>/dev/null
            if [ ! -f "$out/lib/libhello.so" ] && [ ! -f "$out/lib/libhello.dylib" ]; then
              echo "ERROR: no shared object produced" >&2
              exit 1
            fi
          '';
        };

        # Rust source (`krml -backend rust`), compiled to an rlib via rustc.
        # `-minimal` + `-bundle Hello=\*` drop the untranslatable KaRaMeL C
        # runtime and emit a single reachable-only .rs.
        packages.hello-rust = let
          hello-rust-src = pkgs.stdenv.mkDerivation {
            name = "hello-rust-src";
            src = ./. ;
            nativeBuildInputs = [ fstar karamel ];
            buildPhase = ''
              mkdir -p $out
              export KRML_HOME="${karamel.home}"
              ${karamel}/bin/krml \
                -minimal \
                -bundle ${hello-module}=\* \
                -tmpdir $out \
                -backend rust \
                ${hello-krml}/${hello-module}.krml
            '';
            installPhase = "true";
          };
        in
        pkgs.stdenv.mkDerivation {
          name = "hello-rust";
          src = hello-rust-src;
          nativeBuildInputs = [ pkgs.rustc ];
          buildPhase = ''
            rustc --crate-type lib hello.rs --crate-name hello -o libhello.rlib
          '';
          installPhase = ''
            mkdir -p $out/lib
            cp libhello.rlib $out/lib/
          '';
        };

        apps = {
          default = flake-utils.lib.mkApp { drv = self.packages.${system}.hello-exe; };
        };

        devShells.default = pkgs.mkShell {
            dontDetectOcamlConflicts = true;
            shellHook = ''
              export FSTAR_KRML="${fstar-krml}"
              export FSTAR_CHECKED="${fstar-checked}"
              export KRML_HOME="${karamel.home}"
              export KRM_LIB="${karamel.home}/krmllib"
              export KRM_INC="-I${karamel.home}/include -I${karamel.home}/krmllib/c -I${karamel.home}/krmllib/dist/minimal"
            '';
            buildInputs = with pkgs; [
              fstar
              karamel
              ocaml
              ocamlPackages.ocaml-lsp
              python3
            ];
          };
      }
    ) // {
      # Nix flake template (`nix flake init -t .`).  See README "Using as a
      # template".
      templates.default = {
        path = ./.;
        description = "Minimal verified F* project: extracts to C, Rust, OCaml, F#, and WebAssembly";
        welcomeText = ''
          # F* verified project template

          A minimal, self-contained F* module verified and extracted to every
          supported target: C (native + exe), Rust, OCaml, F#, and WebAssembly.

          - Build everything:  nix build \
              .#hello-checked .#hello-krml .#hello-exe .#hello-native \
              .#hello-rust .#hello-ocaml .#hello-fsharp .#hello-wasm .#hello-fsdoc
          - Dev loop:          nix develop && make check && make exe
          - Run the native exe: nix build .#hello-exe && ./result/bin/hello
          - Run the wasm:      nix build .#hello-wasm && cd result && node main.js
        '';
      };
    };
}
