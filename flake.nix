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

        # ── single source of truth for renaming ────────────────────────
        #
        # ── single source of truth for renaming ────────────────────────
        #
        # Edit ONE binding below to rename the whole project.  Everything
        # user-facing (flake attribute names, exe/library basename, `.so`/
        # `.rlib`/ocaml-package names, the wasm `-no-prefix`) derives from it:
        #
        #   pname "fstar-example"  ->  .#fstar-example-checked, bin/fstar-example, libfstar-example.so, ...
        #   pname "i18n"           ->  .#i18n-checked,          bin/i18n,          libi18n.so,          ...
        #
        # The F* module is intentionally a GENERIC, never-renamed name
        # (`Example` below) so a rename is ONE edit here — there is no
        # `nix flake init --name` flag.  (The module stays `Example` unless
        # you also want to rename the source module — see README step 2.)
        pname = "fstar-example";

        # F* module name — a generic placeholder, independent of `pname`.
        # It drives the extracted `.krml`/`.ml`/`.rs`/`.wasm` filenames and
        # the `<Module>_main` C symbol, all generated.  Rename it only if you
        # also rename src/Example.fst and its `module Example` header.
        module-name = "Example";

        # The package (verify + extract), in the codec/default.nix shape.
        # default.nix returns rename-agnostic { checked; krml; }; the flake
        # exposes them as packages.<pname>-checked / -krml.
        _pkg = import ./default.nix {
          inherit pkgs pname module-name;
        };

      in
      {
        packages.default = _pkg.krml;
        packages."${pname}-checked" = _pkg.checked;
        packages."${pname}-krml" = _pkg.krml;

        # The native executable, produced by the Makefile `exe` target (which
        # The native executable, produced by the Makefile `exe` target (which
        # links a GENERATED main.c driver against the extracted module and the
        # krmllib runtime).  Pre-populates the pre-built krml so `make` skips
        # F* re-extraction.  The driver is generated (see Makefile) from the
        # KaRaMeL-emitted <Module>.h, so the C symbol needs no hand-editing.
        packages."${pname}-exe" = pkgs.stdenv.mkDerivation {
          pname = "${pname}-exe";
          version = "0.1.0";
          src = ./. ;
          nativeBuildInputs = [ pkgs.gnumake ];
          # fstar is needed by the Makefile's `ULIB := $(shell $(FSTAR)
          # --locate_lib ...)` at parse time; karamel + fstar-krml by the link;
          # the pre-built krml is pre-populated.  fstar-checked is intentionally
          # absent: `make exe` does not reach `make check`, so it is dead input.
          buildInputs = [ pkgs.stdenv.cc fstar karamel fstar-krml _pkg.krml ];
          buildPhase = ''
            mkdir -p out/krml
            # Pre-populate with pre-built .krml to skip F* re-extraction.
            cp ${_pkg.krml}/*.krml out/krml/
            chmod +w out/krml/*.krml
            touch out/krml/*.krml
            make exe \
              CC="${pkgs.stdenv.cc}/bin/cc" \
              FSTAR="${fstar}/bin/fstar.exe" \
              KRML="${karamel}/bin/krml" \
              KRML_HOME="${karamel.home}" \
              KRM_LIB="${karamel.home}/krmllib" \
              KRM_INC="-I${karamel.home}/include -I${karamel.home}/krmllib/c -I${karamel.home}/krmllib/dist/minimal" \
              FSTAR_KRML="${fstar-krml}" \
              PNAME="${pname}"
          '';
          installPhase = ''
            mkdir -p $out/bin
            cp out/${pname} $out/bin/
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
        # point, so `Example.main` is exported as plain `main` — the name the
        # generated JS loader (`main.js`) looks for.  Without it the export is
        # `Example_main` and the loader reports "no main in current scope".
        packages."${pname}-wasm" = pkgs.stdenv.mkDerivation {
          name = "${pname}-wasm";
          src = ./.;
          nativeBuildInputs = [ fstar karamel ];
          buildPhase = ''
            mkdir -p wasm-out
            export KRML_HOME="${karamel.home}"
            ${karamel}/bin/krml \
              -tmpdir wasm-out \
              -backend wasm \
              -no-prefix ${module-name} \
              ${_pkg.krml}/${module-name}.krml
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
            if [ ! -f "$out/${module-name}.wasm" ]; then
              echo "ERROR: expected $out/${module-name}.wasm, but found:" >&2
              ls -1 "$out" | grep '\.wasm$' >&2 || true
              exit 1
            fi
            echo "wasm: $(ls $out/*.wasm 2>/dev/null | wc -l) .wasm file(s)"
          '';
        };

        # fsdoc: extract `(** ... *)` comments to Markdown.
        packages."${pname}-fsdoc" = pkgs.stdenv.mkDerivation {
          name = "${pname}-fsdoc";
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
        # `fstar.exe --codegen <OCaml|krml>` extracts the module to a source
        # file in the target language: OCaml → .ml, krml → .krml (the
        # intermediate IR KaRaMeL consumes).  Each runs the same
        # verify-then-extract pipeline as checked/krml.

        # OCaml source (`--codegen OCaml`), then compiled via
        # `ocamlPackages.buildDunePackage` (dune, the canonical OCaml Nix build
        # tool) against the fstar OCaml runtime (`fstar.lib`).
        packages."${pname}-ocaml" = let
          # Extract <Module>.ml + a minimal dune scaffold into a source tree
          # that buildDunePackage can consume.  The fstar runtime (`fstar.lib`)
          # is a findlib package living at ${fstar}/lib/fstar; exposed via
          # OCAMLPATH below.
          ocaml-src = pkgs.stdenv.mkDerivation {
            name = "${pname}-ocaml-src";
            src = ./. ;
            nativeBuildInputs = [ fstar ];
            buildPhase = ''
              mkdir -p $out
              export ULIB="${fstar}/lib/fstar/ulib"
              ${fstar}/bin/fstar.exe \
                --no_default_includes --include $ULIB --include ./src \
                --codegen OCaml --odir $out \
                src/${module-name}.fst || exit 1
              cat > $out/dune-project <<DUNE_PROJECT
(lang dune 3.11)
(name ${pname}-ocaml)
(package (name ${pname}-ocaml))
DUNE_PROJECT
              cat > $out/dune <<DUNE
(library
 (name ${pname})
 (public_name ${pname}-ocaml)
 (modules ${module-name})
 (libraries fstar.lib))
DUNE
            '';
            installPhase = "true";
          };
        in
        ocamlPackages.buildDunePackage {
          pname = "${pname}-ocaml";
          version = "0.1.0";
          src = ocaml-src;
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

        # NOTE: no `fstar-example-fsharp` target.  `--codegen FSharp` emits
        # `.fs`, but F*'s own repo marks the F# path untested ("None of this
        # worked" — examples/hello/README.md).  No F# runtime is packaged in
        # the fstar derivation, and the codegen emits `int` literals that don't
        # typecheck against the unshipped `bigint`-backed `FStar_UInt8`.  See
        # README "Why there is no F# target".

        # ── KaRaMeL C/Rust backends ────────────────────────────────────
        #
        # KaRaMeL `-backend` emits from the extracted .krml: `c` (.c/.h), `rust`
        # (.rs), or `wasm` (.wasm).  These consume the pre-built krml
        # output (never re-extract from source).

        # Native C library, compiled to a shared object (`.so`/`.dylib`).
        # Distinct from ${pname}-exe (which links a main driver).
        packages."${pname}-native" = pkgs.stdenv.mkDerivation {
          name = "${pname}-native";
          src = ./. ;
          nativeBuildInputs = [ fstar karamel pkgs.stdenv.cc ];
          buildPhase = ''
            mkdir -p native-out
            export KRML_HOME="${karamel.home}"
            ${karamel}/bin/krml \
              -skip-compilation \
              -tmpdir native-out \
              ${_pkg.krml}/${module-name}.krml
            cc -shared -fPIC \
              -I"${karamel.home}/include" \
              -I"${karamel.home}/krmllib/c" \
              -I"${karamel.home}/krmllib/dist/minimal" \
              native-out/${module-name}.c \
              -o native-out/lib${pname}.so
          '';
          installPhase = ''
            mkdir -p $out/lib $out/include
            cp native-out/*.so $out/lib/ 2>/dev/null
            cp native-out/${module-name}.h $out/include/ 2>/dev/null
            if [ ! -f "$out/lib/lib${pname}.so" ] && [ ! -f "$out/lib/lib${pname}.dylib" ]; then
              echo "ERROR: no shared object produced" >&2
              exit 1
            fi
          '';
        };

        # Rust source (`krml -backend rust`), compiled to an rlib via rustc.
        # `-minimal` + `-bundle <Module>=\*` drop the untranslatable KaRaMeL C
        # runtime and emit a single reachable-only .rs.
        packages."${pname}-rust" = let
          rust-src = pkgs.stdenv.mkDerivation {
            name = "${pname}-rust-src";
            src = ./. ;
            nativeBuildInputs = [ fstar karamel ];
            buildPhase = ''
              mkdir -p $out
              export KRML_HOME="${karamel.home}"
              ${karamel}/bin/krml \
                -minimal \
                -bundle ${module-name}=\* \
                -tmpdir $out \
                -backend rust \
                ${_pkg.krml}/${module-name}.krml
            '';
            installPhase = "true";
          };
        in
        pkgs.stdenv.mkDerivation {
          name = "${pname}-rust";
          src = rust-src;
          nativeBuildInputs = [ pkgs.rustc ];
          buildPhase = ''
            # KaRaMeL's rust backend names the emitted file after the MODULE
            # (`<Module>.rs`), but the crate/library is named after `pname`.
            rustc --crate-type lib ${module-name}.rs --crate-name ${pname} -o lib${pname}.rlib
          '';
          installPhase = ''
            mkdir -p $out/lib
            cp lib${pname}.rlib $out/lib/
          '';
        };

        apps = {
          default = flake-utils.lib.mkApp { drv = self.packages.${system}."${pname}-exe"; };
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
      # template".  The path is the repository root: `init` copies this repo's
      # own project (flake.nix, default.nix, Makefile, src/, scripts/) directly,
      # so a new project is created by editing `pname` (+ optionally renaming
      # the module).
      templates.default = {
        path = ./.;
        description = "Minimal verified F* project: extracts to C, Rust, OCaml, and WebAssembly (rename via one `pname` binding)";
        welcomeText = ''
          # F* verified project template

          A minimal, self-contained F* module verified and extracted to every
          supported target: C (native + exe), Rust, OCaml, and WebAssembly.

          Create a new project (see README "Create a project from this template"):

          1. nix flake init -t github:dysinger/fstar-nix-flake-template
          2. edit `pname` in flake.nix to your project name
          3. (optional) rename src/Example.fst -> src/<YourModule>.fst and its
             `module Example` header
          4. nix build

          - Build everything: nix build \
              .#fstar-example-checked .#fstar-example-krml .#fstar-example-exe \
              .#fstar-example-native .#fstar-example-rust .#fstar-example-ocaml \
              .#fstar-example-wasm .#fstar-example-fsdoc
          - Dev loop:         nix develop && make check && make exe
          - Run native exe:   nix build .#fstar-example-exe && ./result/bin/fstar-example
          - Run the wasm:     nix build .#fstar-example-wasm && cd result && node main.js
        '';
      };
    };
}
