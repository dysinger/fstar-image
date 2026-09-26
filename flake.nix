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
              { inherit fstar karamel fstar-checked fstar-krml; })
          ];
        };

        inherit (pkgs) stdenv fstar karamel fstar-checked fstar-krml;

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
        description = "Minimal verified F* project (Hello World) that builds to a native exe and WebAssembly";
        welcomeText = ''
          # F* verified project template

          A minimal, self-contained F* module verified, extracted via KaRaMeL,
          and runnable as a native executable and a WebAssembly module.

          - Build everything:  nix build .#hello-checked .#hello-krml .#hello-exe .#hello-wasm .#hello-fsdoc
          - Dev loop:          nix develop && make check && make exe
          - Run the native exe: nix build .#hello-exe && ./result/bin/hello
          - Run the wasm:      nix build .#hello-wasm && cd result && node main.js
        '';
      };
    };
}
