# Copyright 2026 Department of Code LLC.
# SPDX-License-Identifier: AGPL-3.0-or-later

{
  description = "Minimal verified F* project template (fstar-example)";

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
                # typecheckers and the C link).
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

        # The toolchain derivations the package consumes, handed to default.nix
        # by reference (they are built by the overlays above and are naturally
        # in scope here for the devShell too).
        inherit (pkgs) fstar karamel fstar-checked fstar-krml lib rustc stdenv;
        inherit (pkgs) ocamlPackages;

        # The package — all target derivations (checked / krml / exe / native /
        # rust / ocaml / wasm) live in default.nix, which takes the toolchain
        # by named argument and delegates verification/extraction to the
        # Makefile.  This flake only re-exposes them.
        _pkg = import ./default.nix {
          inherit fstar fstar-checked fstar-krml karamel lib ocamlPackages rustc stdenv;
        };

      in
      {
        packages.default = _pkg.krml;
        packages.fstar-example-checked = _pkg.checked;
        packages.fstar-example-krml = _pkg.krml;
        packages.fstar-example-exe = _pkg.exe;
        packages.fstar-example-native = _pkg.native;
        packages.fstar-example-rust = _pkg.rust;
        packages.fstar-example-ocaml = _pkg.ocaml;
        packages.fstar-example-wasm = _pkg.wasm;

        apps = {
          default = flake-utils.lib.mkApp { drv = self.packages.${system}.fstar-example-exe; };
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
      # Nix flake template (`nix flake init -t .`).  The path is the repository
      # root: `init` copies flake.nix, default.nix, Makefile, src/ directly.
      templates.default = {
        path = ./.;
        description = "Minimal verified F* project: extracts to C, Rust, OCaml, and WebAssembly";
        welcomeText = ''
          # F* verified project template

          A minimal, self-contained F* module verified and extracted to every
          supported target: C (native + exe), Rust, OCaml, and WebAssembly.

          Create a new project (see README):

          1. nix flake init -t github:dysinger/fstar-nix-flake-template
          2. rename src/Example.fst -> src/<YourModule>.fst and its
             `module Example` header (a real rename, not a one-line edit)
          3. edit `pname` in flake.nix (`pname = "fstar-example";`) to match
          4. nix build

          - Build everything: nix build \
              .#fstar-example-checked .#fstar-example-krml .#fstar-example-exe \
              .#fstar-example-native .#fstar-example-rust .#fstar-example-ocaml \
              .#fstar-example-wasm
          - Dev loop:         nix develop && make check && make krml && make exe
          - Run native exe:   nix build .#fstar-example-exe && ./result/bin/fstar-example
          - Run the wasm:     nix build .#fstar-example-wasm && cd result && node main.js
        '';
      };
    };
}
