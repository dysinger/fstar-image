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
#   - `Example.Majority.Types`  — pure spec: the candidate/count types + lemmas
#   - `Example.Majority`         — pure Boyer–Moore algorithm + correctness lemmas
#   - `Example.Majority.Pulse`   — Pulse leaf: majority_vote over a Pulse array
#   - `Example.Majority.CLI`     — `main : unit -> Int32.t` CLI entry point
#
# Artifacts:
#   - `checked` — F* verification of src/ + test/ (the 0-admit gate).
#   - `ocaml`   — findlib package of the pure spec (Types + Majority).
#   - `native`  — C11 shared/static lib of the Pulse leaf (`Example.Majority.Pulse`,
#                 `--custard_backend C`).
#   - `cli`     — a packaged native executable (`Example.Majority.CLI`, `--custard_main`).
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

  pname = "example";

  pure-modules = [
    "Example.Majority.Types"
    "Example.Majority"
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
    nativeBuildInputs = [
      fstar
      fstar-checked
    ];
    buildPhase = ''
            export ULIB="${ulib}"
            mkdir -p $out cache
            cp ${fstar-checked}/*.checked cache/ 2>/dev/null || true
            # 1) Extract the pure spec (Example.Majority.Types + Example.Majority) via legacy
            #    `--codegen OCaml` (one file per invocation, dependency order).
            for m in ${builtins.concatStringsSep " " pure-modules}; do
              ${fstar-exe} \
                --no_default_includes --include "$ULIB" --include ./src \
                --cache_checked_modules --cache_dir cache --odir cache \
                src/$m.fst || exit 1
              ${fstar-exe} \
                --no_default_includes --include "$ULIB" --include ./src --include cache \
                --cache_checked_modules --cache_dir cache \
                --codegen OCaml --odir $out \
                src/$m.fst || exit 1
            done
            # 2) Extract the Pulse leaf (Example.Majority.Pulse), OCaml backend.
            PULSE_INCS=""
            for d in ${lib.concatStringsSep " " pulse-incs}; do
              PULSE_INCS="$PULSE_INCS --include $d"
            done
            ${fstar-exe} \
              --no_default_includes --include "$ULIB" $PULSE_INCS --include ./src \
              --already_cached Prims,FStar,Pulse.Nolib,Pulse.Lib,Pulse.Class,PulseCore \
              --z3rlimit 120 \
              --cache_checked_modules --cache_dir cache --odir cache \
              src/Example.Majority.Pulse.fst || exit 1
            ${fstar-exe} \
              --no_default_includes --include "$ULIB" $PULSE_INCS --include ./src --include cache \
              --already_cached Prims,FStar,Pulse.Nolib,Pulse.Lib,Pulse.Class,PulseCore \
              --cache_checked_modules --cache_dir cache \
              --codegen Custard --custard_backend OCaml --custard_monomorphize_types true \
              --custard_entry Example.Majority.Pulse.majority_vote \
              --odir $out \
              src/Example.Majority.Pulse.fst || exit 1
            # One dune library: pure spec + Pulse leaf together.
            cat > $out/dune-project <<DUNE_PROJECT
      (lang dune 3.11)
      (name ${pname}-ocaml)
      (package (name ${pname}-ocaml))
      DUNE_PROJECT
            cat > $out/dune <<DUNE
      (library
       (name ${ocaml-lib-name})
       (public_name ${pname}-ocaml)
       (modules ${builtins.concatStringsSep " " ocaml-modules} Custard)
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
    nativeBuildInputs = [
      fstar
      fstar-checked
    ];
    inherit meta;
    buildPhase = ''
      export ULIB="${ulib}"
      mkdir -p $out cache
      PULSE_INCS=""
      for d in ${lib.concatStringsSep " " pulse-incs}; do
        PULSE_INCS="$PULSE_INCS --include $d"
      done
      cp ${fstar-checked}/*.checked cache/ 2>/dev/null || true
      for m in Example.Majority.Types Example.Majority Example.Majority.Pulse; do
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
        --custard_entry Example.Majority.Pulse.majority_vote \
        --odir $out \
        src/Example.Majority.Pulse.fst || exit 1
      cc -c -Wall -Wextra -Werror -std=c11 -O2 -fPIC -I $out $out/Custard.c -o $out/Custard.o
      if [ "$(uname -s)" = Darwin ]; then
        cc -dynamiclib $out/Custard.o -o $out/lib${pname}.dylib
      else
        cc -shared $out/Custard.o -o $out/lib${pname}.so
      fi
      ar rcs $out/lib${pname}.a $out/Custard.o
      cp $out/Custard.h $out/${pname}.h
    '';
    installPhase = "true";
  };

  # ── F# (.NET) backend ─────────────────────────────────────────────
  #
  # Same flat pattern as `native`/codec: verify → extract F# → build
  # with `dotnet`.  Rooted at the single entry point (majority_vote), which
  # returns `vote_result` (an F*-defined variant, realizable in F#), so no
  # tuple-returning proof
  # lemmas are pulled in.

  fsharp = mkDerivation {
    pname = "${pname}-fsharp";
    version = "0.1.0";
    src = ./.;
    nativeBuildInputs = [
      fstar
      fstar-checked
      dotnet
    ];
    inherit meta;
    buildPhase = ''
      mkdir -p $out cache src-out
      export DOTNET_CLI_TELEMETRY_OPTOUT=1
      export DOTNET_NOLOGO=1
      export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
      export HOME=$NIX_BUILD_TOP
      export ULIB="${ulib}"
      PULSE_INCS=""
      for d in ${lib.concatStringsSep " " pulse-incs}; do
        PULSE_INCS="$PULSE_INCS --include $d"
      done
      cp ${fstar-checked}/*.checked cache/ 2>/dev/null || true
      for m in Example.Majority.Types Example.Majority Example.Majority.Pulse; do
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
        --codegen Custard --custard_backend FSharp --custard_monomorphize_types true \
        --custard_entry Example.Majority.Pulse.majority_vote \
        --odir src-out \
        src/Example.Majority.Pulse.fst || exit 1
      dotnet build src-out/Custard.fsproj -c Release -o $out || exit 1
    '';
    installPhase = "true";
  };

  # ── cli — packaged command-line executable ─────────────────────────

  cli = mkDerivation {
    pname = "${pname}-cli";
    version = "0.1.0";
    src = ./.;
    nativeBuildInputs = [
      fstar
      fstar-checked
      stdenv.cc
    ];
    inherit meta;
    buildPhase = ''
      export ULIB="${ulib}"
      mkdir -p $out cache
      PULSE_INCS=""
      for d in ${lib.concatStringsSep " " pulse-incs}; do
        PULSE_INCS="$PULSE_INCS --include $d"
      done
      cp ${fstar-checked}/*.checked cache/ 2>/dev/null || true
      for m in Example.Majority.Types Example.Majority Example.Majority.Pulse Example.Majority.CLI; do
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
        --custard_main Example.Majority.CLI.main \
        --odir $out \
        src/Example.Majority.CLI.fst || exit 1
      mkdir -p $out/bin
      cc -Wall -Wextra -Werror -std=c11 -O2 -I $out $out/Custard.c -o $out/bin/${pname}-cli
    '';
    installPhase = "true";
  };

in
{
  inherit
    checked
    ocaml
    native
    fsharp
    cli
    ;
}
