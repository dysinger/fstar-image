# Copyright 2026 Department of Code LLC.
# SPDX-License-Identifier: AGPL-3.0-or-later

# Minimal verified F* project (library + CLI), Custard/post-KaRaMeL era.
#
# Takes the F* toolchain as concrete derivations (no `pkgs` blob, no overlay
# assumption).  Module names and their dependency order live in the Makefile;
# `checked` delegates to `make check`.
#
# The example is a Boyer–Moore majority-vote library plus a command-line
# executable that exercises it:
#
#   - `Majority.Types`  — pure spec: the candidate/count types + lemmas
#   - `Majority`        — pure Boyer–Moore algorithm + correctness lemmas
#   - `Majority.Pulse`  — Pulse leaf: majority_vote over a Pulse array
#   - `Main`            — `main : unit -> Int32.t` CLI entry point
#
# Artifacts:
#   - `checked` — F* verification of src/ + test/ (the 0-admit gate).
#   - `ocaml`   — findlib package of the pure spec (Types + Majority).
#   - `native`  — C11 shared/static lib of the Pulse leaf (`Majority.Pulse`,
#                 `--custard_backend C`).
#   - `cli`     — a packaged native executable (`Main`, `--custard_main`).
#
# Returns { checked; ocaml; native; cli; }.

{
  fstar,
  fstar-checked,
  lib,
  ocamlPackages,
  stdenv,
  dotnet,
}:

let
  inherit (stdenv) mkDerivation;

  pname = "fstar-example";

  pure-modules = [
    "Majority.Types"
    "Majority"
  ];

  fstar-exe = "${fstar}/bin/fstar.exe";
  flib = "${fstar}/lib/fstar";
  ulib = "${flib}/ulib";
  pulse-incs = [
    "${flib}/pulse/common"
    "${flib}/pulse/common.checked"
    "${flib}/pulse/pulse/lib"
    "${flib}/pulse/pulse.checked"
  ];

  meta = {
    license = lib.licenses.agpl3Plus;
    maintainers = [
      {
        name = "Tim Dysinger";
        email = "tim@dysinger.net";
      }
    ];
  };

  make-env = ''
    export FSTAR="${fstar-exe}"
    export FSTAR_CHECKED="${fstar-checked}"
  '';

  checked = mkDerivation {
    pname = "${pname}-checked";
    version = "0.1.0";
    src = ./.;
    nativeBuildInputs = [
      fstar
      fstar-checked
    ];
    inherit meta;
    buildPhase = ''
      ${make-env}
      make check OUT="$out"
      if [ -d "$out/checked" ]; then mv "$out"/checked/*.checked "$out"/ 2>/dev/null || true; rmdir "$out/checked"; fi
    '';
    installPhase = "true";
  };

  # ── OCaml source backend ────────────────────────────────────────────

  ocaml-lib-name = builtins.replaceStrings [ "-" ] [ "_" ] pname;
  ocaml-modules = map (m: builtins.replaceStrings [ "." ] [ "_" ] m) pure-modules;

  ocaml-src = mkDerivation {
    name = "${pname}-ocaml-src";
    src = ./.;
    nativeBuildInputs = [ fstar fstar-checked ];
    buildPhase = ''
      mkdir -p $out cache
      cp ${fstar-checked}/*.checked cache/ 2>/dev/null || true
      for m in ${builtins.concatStringsSep " " pure-modules}; do
        ${fstar-exe} \
          --no_default_includes --include $ULIB --include ./src \
          --cache_checked_modules --cache_dir cache --odir cache \
          src/$m.fst || exit 1
        ${fstar-exe} \
          --no_default_includes --include $ULIB --include ./src --include cache \
          --cache_checked_modules --cache_dir cache \
          --codegen OCaml --odir $out \
          src/$m.fst || exit 1
      done
      cat > $out/dune-project <<DUNE_PROJECT
(lang dune 3.11)
(name ${pname}-ocaml)
(package (name ${pname}-ocaml))
DUNE_PROJECT
      cat > $out/dune <<DUNE
(library
 (name ${ocaml-lib-name})
 (public_name ${pname}-ocaml)
 (modules ${builtins.concatStringsSep " " ocaml-modules})
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
      batteries
      pprint
      stdint
      yojson
      zarith
      ppx_deriving
      ppx_deriving_yojson
    ];
    OCAMLPATH = "${fstar}/lib";
  };

  # ── native (C) backend — Pulse leaf extracted to C11 ────────────────

  native = mkDerivation {
    pname = "${pname}-native";
    version = "0.1.0";
    src = ./.;
    nativeBuildInputs = [ fstar fstar-checked ];
    inherit meta;
    buildPhase = ''
      mkdir -p $out cache
      PULSE_INCS=""
      for d in ${lib.concatStringsSep " " pulse-incs}; do
        PULSE_INCS="$PULSE_INCS --include $d"
      done
      cp ${fstar-checked}/*.checked cache/ 2>/dev/null || true
      for m in Majority.Types Majority Majority.Pulse; do
        ${fstar-exe} \
          --no_default_includes --include "$ULIB" $PULSE_INCS --include ./src \
          --already_cached Prims,FStar,Pulse.Nolib,Pulse.Lib,Pulse.Class,PulseCore \
          --z3rlimit 120 \
          --cache_checked_modules --cache_dir cache --odir cache \
          src/$m.fst || exit 1
      done
      ${fstar-exe} \
        --no_default_includes --include "$ULIB" $PULSE_INCS --include ./src --include cache \
        --already_cached Prims,FStar,Pulse.Nolib,Pulse.Lib,Pulse.Class,PulseCore \
        --cache_checked_modules --cache_dir cache \
        --codegen Custard --custard_backend C --custard_monomorphize_types true \
        --custard_entry Majority.Pulse.majority_vote \
        --odir $out \
        src/Majority.Pulse.fst || exit 1
      cc -c -Wall -Wextra -Werror -std=c11 -O2 -fPIC -I $out $out/Custard.c -o $out/Custard.o
      if [ "$(uname -s)" = Darwin ]; then
        cc -dynamiclib $out/Custard.o -o $out/libfstar-example.dylib
      else
        cc -shared $out/Custard.o -o $out/libfstar-example.so
      fi
      ar rcs $out/libfstar-example.a $out/Custard.o
      cp $out/Custard.h $out/fstar-example.h
    '';
    installPhase = "true";
  };

  # ── cli — packaged command-line executable ─────────────────────────

  cli = mkDerivation {
    pname = "${pname}-cli";
    version = "0.1.0";
    src = ./.;
    nativeBuildInputs = [ fstar fstar-checked stdenv.cc ];
    inherit meta;
    buildPhase = ''
      mkdir -p $out cache
      PULSE_INCS=""
      for d in ${lib.concatStringsSep " " pulse-incs}; do
        PULSE_INCS="$PULSE_INCS --include $d"
      done
      cp ${fstar-checked}/*.checked cache/ 2>/dev/null || true
      for m in Majority.Types Majority Majority.Pulse Main; do
        ${fstar-exe} \
          --no_default_includes --include "$ULIB" $PULSE_INCS --include ./src \
          --already_cached Prims,FStar,Pulse.Nolib,Pulse.Lib,Pulse.Class,PulseCore \
          --z3rlimit 120 \
          --cache_checked_modules --cache_dir cache --odir cache \
          src/$m.fst || exit 1
      done
      ${fstar-exe} \
        --no_default_includes --include "$ULIB" $PULSE_INCS --include ./src --include cache \
        --already_cached Prims,FStar,Pulse.Nolib,Pulse.Lib,Pulse.Class,PulseCore \
        --cache_checked_modules --cache_dir cache \
        --codegen Custard --custard_backend C --custard_monomorphize_types true \
        --custard_main Main.main \
        --odir $out \
        src/Main.fst || exit 1
      cc -Wall -Wextra -Werror -std=c11 -O2 -I $out $out/Custard.c -o $out/fstar-example
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp $out/fstar-example $out/bin/
    '';
  };

in
{
  inherit
    checked
    ocaml
    native
    cli
    ;
}
