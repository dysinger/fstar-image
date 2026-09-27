# Minimal verified F* package.
#
# Takes pkgs with fstar, karamel, fstar-checked in scope (from the nixpkgs
# overlay in the top-level flake), plus the project name and the source module
# name (both derived from the single `pname` binding in flake.nix).
#
# Returns { checked; krml; } — rename-agnostic keys.  The top-level flake
# exposes them as packages.<pname>-checked / -krml.

{ pkgs, pname ? "fstar-example", module-name ? "Example" }:

let
  inherit (pkgs) stdenv fstar karamel fstar-checked;

  fstar-exe = "${fstar}/bin/fstar.exe";
  ulib = "${fstar}/lib/fstar/ulib";
  krmllib = "${karamel.home}/krmllib";

  fstar-flags = "--no_default_includes --include ${ulib} --include ./src --include ${krmllib} --include ${krmllib}/obj --z3rlimit 80";

  # Source modules in DEPENDENCY ORDER (leaf modules first).  Required so the
  # .checked files land in $out in the right order (Warning 247).  This
  # template has a single source module; its name is threaded in from the
  # top-level flake rather than hardcoded.
  ordered-src-modules = [ module-name ];

  checked = stdenv.mkDerivation {
    pname = "${pname}-checked";
    version = "0.1.0";
    src = ./.;
    nativeBuildInputs = [ fstar ];
    # Intentional (mirrors xeno/codec/default.nix): write straight to $out in
    # buildPhase and no-op installPhase — these derivations just stage a
    # directory of compiler artifacts, not a build/install split.
    buildPhase = ''
      mkdir -p $out
      cp ${fstar-checked}/*.checked $out/ 2>/dev/null || true

      for mod in ${builtins.concatStringsSep " " ordered-src-modules}; do
        echo "=== Verifying $mod ==="
        ${fstar-exe} ${fstar-flags} \
          --cache_checked_modules --cache_dir $out --odir $out \
          src/$mod.fst || exit 1
      done
      rm -f $out/*.krml $out/*.c $out/*.h 2>/dev/null || true
      echo "checked: $(ls $out/*.checked 2>/dev/null | wc -l) files"
    '';
    installPhase = "true";
  };

  krml = stdenv.mkDerivation {
    pname = "${pname}-krml";
    version = "0.1.0";
    src = ./.;
    nativeBuildInputs = [ fstar ];
    buildPhase = ''
      mkdir -p $out
      cp ${checked}/*.checked $out/ 2>/dev/null || true
      cp ${fstar-checked}/*.checked $out/ 2>/dev/null || true

      # Note: a multi-module package typically extracts only its `.Low` modules
      # (via `grep '\.Low'`).  This template's single module is a plain
      # extractable `Example` (not `Example.Low`), so that filter would find zero
      # modules and produce an empty artifact.  We therefore extract from
      # ordered-src-modules (the same list `checked` verifies).
      for mod in ${builtins.concatStringsSep " " ordered-src-modules}; do
        echo "=== Extracting $mod ==="
        ${fstar-exe} ${fstar-flags} \
          --cache_checked_modules --cache_dir $out \
          --odir $out --codegen krml \
          --extract_module $mod \
          src/$mod.fst || exit 1
      done
      rm -f $out/*.checked $out/*.c $out/*.h $out/*.exe 2>/dev/null || true
      echo "krml: $(ls $out/*.krml 2>/dev/null | wc -l) files"
    '';
    installPhase = "true";
  };
in
{
  inherit checked krml;
}
