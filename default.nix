# Copyright 2026 Department of Code LLC.
# SPDX-License-Identifier: AGPL-3.0-or-later

# Minimal verified F* package (runnable single-module example).
#
# Takes the F* / KaRaMeL toolchain as concrete derivations — no `pkgs` blob,
# no overlay assumption, no module-name argument.  Module names and their
# dependency order live in the Makefile (the no-nix build); `checked`, `krml`,
# and `exe` delegate to `make`, exporting the toolchain paths the Makefile
# already reads (FSTAR / KRML / FSTAR_KRML / FSTAR_CHECKED / KRML_HOME /
# KRM_LIB / KRM_INC).  The remaining backends (native / rust / ocaml / wasm)
# consume the extracted `.krml` directly.
#
# The single source module is discovered from `src/*.fst` (not passed in); its
# name drives the extracted filenames and the C entry symbol, so renaming the
# module is renaming `src/Example.fst` + its `module Example` header — nothing
# else.
#
# Returns an attrset keyed by package name; the flake re-exposes them as
# packages.<name>.

{ fstar, fstar-checked, fstar-krml, karamel, lib, ocamlPackages, rustc, stdenv }:

let
  inherit (stdenv) mkDerivation;

  pname = "fstar-example";

  # The single F* module, discovered from the source tree (basename of the
  # `.fst` file).  No `module-name` argument, no rename magic.
  src-module =
    let
      fst-files = builtins.filter
        (n: builtins.match ".*\.fst" n != null)
        (builtins.attrNames (builtins.readDir ./src));
    in
    assert builtins.length fst-files == 1;
    builtins.replaceStrings [ ".fst" ] [ "" ] (builtins.head fst-files);

  fstar-exe = "${fstar}/bin/fstar.exe";
  krml-exe = "${karamel}/bin/krml";

  meta = {
    license = lib.licenses.agpl3Plus;
    maintainers = [{
      name = "Tim Dysinger";
      email = "tim@dysinger.net";
    }];
  };

  # The toolchain environment the Makefile reads (see its guards).
  make-env = ''
    export FSTAR="${fstar-exe}"
    export KRML="${krml-exe}"
    export FSTAR_KRML="${fstar-krml}"
    export FSTAR_CHECKED="${fstar-checked}"
    export KRML_HOME="${karamel.home}"
    export KRM_LIB="${karamel.home}/krmllib"
    export KRM_INC="-I${karamel.home}/include -I${karamel.home}/krmllib/c -I${karamel.home}/krmllib/dist/minimal"
  '';

  # ── F* verification / extraction via the Makefile ─────────────────

  checked = mkDerivation {
    pname = "${pname}-checked";
    version = "0.1.0";
    src = ./.;
    nativeBuildInputs = [ fstar karamel fstar-krml fstar-checked ];
    inherit meta;
    buildPhase = ''
      ${make-env}
      make check OUT="$out"
      # The Makefile lays out $(OUT)/checked/*.checked; flatten to $out/*.checked
      # so `checked` ships the same flat artifact the old default.nix did.
      if [ -d "$out/checked" ]; then mv "$out"/checked/*.checked "$out"/ 2>/dev/null || true; rmdir "$out/checked"; fi
    '';
    installPhase = "true";
  };

  krml = mkDerivation {
    pname = "${pname}-krml";
    version = "0.1.0";
    src = ./.;
    nativeBuildInputs = [ fstar karamel fstar-krml fstar-checked ];
    inherit meta;
    buildPhase = ''
      ${make-env}
      make krml OUT="$out"
      # Flatten $(OUT)/krml/*.krml to $out/*.krml and drop the intermediate
      # $(OUT)/checked/ (the downstream backends read the .krml flat).
      if [ -d "$out/krml" ]; then mv "$out"/krml/*.krml "$out"/ 2>/dev/null || true; rmdir "$out/krml"; fi
      rm -rf "$out/checked"
    '';
    installPhase = "true";
  };

  exe = mkDerivation {
    pname = "${pname}-exe";
    version = "0.1.0";
    src = ./.;
    nativeBuildInputs = [ stdenv.cc fstar karamel fstar-krml fstar-checked ];
    inherit meta;
    buildPhase = ''
      ${make-env}
      make exe OUT="$out" PNAME="${pname}"
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp $out/${pname} $out/bin/
      rm -f "$out/${pname}" "$out/main.c"
      rm -rf "$out/checked" "$out/krml"
    '';
  };

  # ── KaRaMeL C / Rust / wasm backends ─────────────────────────────
  #
  # No Makefile targets for these; they consume the extracted `.krml` (the
  # `${src-module}.krml` in `krml`'s output).

  native = mkDerivation {
    name = "${pname}-native";
    src = ./.;
    nativeBuildInputs = [ fstar karamel stdenv.cc ];
    inherit meta;
    buildPhase = ''
      mkdir -p native-out
      export KRML_HOME="${karamel.home}"
      ${krml-exe} \
        -skip-compilation \
        -tmpdir native-out \
        ${krml}/${src-module}.krml
      # Shared-object suffix per platform (.dylib on macOS, .so elsewhere).
      if [ "$(uname)" = Darwin ]; then so_ext=dylib; else so_ext=so; fi
      cc -shared -fPIC \
        -I"${karamel.home}/include" \
        -I"${karamel.home}/krmllib/c" \
        -I"${karamel.home}/krmllib/dist/minimal" \
        native-out/${src-module}.c \
        -o native-out/lib${pname}."$so_ext"
    '';
    installPhase = ''
      mkdir -p $out/lib $out/include
      cp native-out/*.so native-out/*.dylib $out/lib/ 2>/dev/null || true
      cp native-out/${src-module}.h $out/include/ 2>/dev/null
      if [ ! -f "$out/lib/lib${pname}.so" ] && [ ! -f "$out/lib/lib${pname}.dylib" ]; then
        echo "ERROR: no shared object produced" >&2
        exit 1
      fi
    '';
  };

  wasm = mkDerivation {
    name = "${pname}-wasm";
    src = ./.;
    nativeBuildInputs = [ fstar karamel ];
    inherit meta;
    buildPhase = ''
      mkdir -p wasm-out
      export KRML_HOME="${karamel.home}"
      ${krml-exe} \
        -tmpdir wasm-out \
        -backend wasm \
        -no-prefix ${src-module} \
        ${krml}/${src-module}.krml
    '';
    installPhase = ''
      mkdir -p $out
      cp wasm-out/* $out/ 2>/dev/null
      # Case-exact guard: the shell.js module list, the emitted .wasm filename
      # and the JS loader's hardcoded `<Module>.wasm` reference must agree.
      if [ ! -f "$out/${src-module}.wasm" ]; then
        echo "ERROR: expected $out/${src-module}.wasm, but found:" >&2
        ls -1 "$out" | grep '\.wasm$' >&2 || true
        exit 1
      fi
      echo "wasm: $(ls $out/*.wasm 2>/dev/null | wc -l) .wasm file(s)"
    '';
  };

  # ── Rust source backend ──────────────────────────────────────────
  #
  # `krml -backend rust` names the emitted file after the MODULE
  # (`<Module>.rs`); the crate is named after `pname` with hyphens replaced by
  # underscores (rustc forbids '-' in a crate name; the `.rlib` filename keeps
  # the hyphen).  `-minimal` + `-bundle <Module>=\*` drop the untranslatable
  # KaRaMeL C runtime and emit a single reachable-only `.rs`.

  rust-src = mkDerivation {
    name = "${pname}-rust-src";
    src = ./.;
    nativeBuildInputs = [ fstar karamel ];
    buildPhase = ''
      mkdir -p $out
      export KRML_HOME="${karamel.home}"
      ${krml-exe} \
        -minimal \
        -bundle ${src-module}=\* \
        -tmpdir $out \
        -backend rust \
        ${krml}/${src-module}.krml
    '';
    installPhase = "true";
  };

  rust = mkDerivation {
    name = "${pname}-rust";
    src = rust-src;
    nativeBuildInputs = [ rustc ];
    inherit meta;
    buildPhase = ''
      CRATE="$(printf '%s' '${pname}' | tr '-' '_')"
      rustc --crate-type lib ${src-module}.rs --crate-name "$CRATE" -o lib${pname}.rlib
    '';
    installPhase = ''
      mkdir -p $out/lib
      cp lib${pname}.rlib $out/lib/
    '';
  };

  # ── OCaml source backend ─────────────────────────────────────────
  #
  # `fstar.exe --codegen OCaml` extracts `<Module>.ml`; dune compiles it
  # against the fstar OCaml runtime (`fstar.lib`).  dune library names forbid
  # '-', so the `(name ...)` uses an underscored form while `public_name`/the
  # findlib package keep the hyphen.

  ocaml-lib-name = builtins.replaceStrings [ "-" ] [ "_" ] pname;

  ocaml-src = mkDerivation {
    name = "${pname}-ocaml-src";
    src = ./.;
    nativeBuildInputs = [ fstar ];
    buildPhase = ''
      mkdir -p $out
      export ULIB="${fstar}/lib/fstar/ulib"
      ${fstar-exe} \
        --no_default_includes --include $ULIB --include ./src \
        --codegen OCaml --odir $out \
        src/${src-module}.fst || exit 1
      cat > $out/dune-project <<DUNE_PROJECT
(lang dune 3.11)
(name ${pname}-ocaml)
(package (name ${pname}-ocaml))
DUNE_PROJECT
      cat > $out/dune <<DUNE
(library
 (name ${ocaml-lib-name})
 (public_name ${pname}-ocaml)
 (modules ${src-module})
 (libraries fstar.lib))
DUNE
    '';
    installPhase = "true";
  };

  ocaml = ocamlPackages.buildDunePackage {
    pname = "${pname}-ocaml";
    version = "0.1.0";
    src = ocaml-src;
    inherit meta;
    propagatedBuildInputs = [ fstar ];
    buildInputs = with ocamlPackages; [
      batteries pprint stdint yojson zarith
      ppx_deriving ppx_deriving_yojson
    ];
    OCAMLPATH = "${fstar}/lib";
  };
in
{
  inherit checked krml exe native rust ocaml wasm;
}
