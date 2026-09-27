# fstar-template — Session Handoff

Next-session context for the "minimal F* flake template" task.
Source of truth for the *original* (this is a reduction of it):
`/Users/user/_/xeno/flake.nix`, `/Users/user/_/xeno/codec/default.nix`,
`/Users/user/_/xeno/tls/Makefile`, `/Users/user/_/xeno/text/default.nix`.

## Goal

A **reduction** of the Xeno flake — same mechanics, same overlay, same
`default.nix` + `Makefile` shape — with only domain-specific pieces removed.
NOT a redesign. A reviewer diffing the two repos must be able to point at each
template section and see a faithful, minimal copy of the original's idioms.

## TASK (next session): DONE — usable nix flake template (in place)

> The original plan was a dedicated `template/` subdir; that was abandoned at
> the session lead's direction — the DoD is: **use this repo itself as the
> template**, and `nix flake init -t .` → rename the library name → it compiles
> against all targets first try.  The F# target is removed and stays removed.

Goal (achieved): `nix flake init -t github:<you>/<repo>` (and `-t <local-path>`)
copies this project directly; editing the single `pname` (and renaming the
module file/header) yields a buildable new F* project that compiles against all
targets first try.

### Current template machinery (what exists today)

- `templates.default = { path = ./. ; ... }` in `flake.nix` — points at the
  **repository root**, so `nix flake init -t .` copies EVERYTHING tracked:
  `.gitignore`, `AGENTS.md`, `LICENSE`, `README.md` (this repo's own long
  README), `flake.lock`, `flake.nix`, `default.nix`, `Makefile`, `scripts/`,
  `src/`.  The `result*` symlinks are git-ignored, so they are NOT copied.
- Module naming is already threaded: `flake.nix` `hello-module = "Hello"` →
  `default.nix` `module-name` → `ordered-src-modules`; the `Makefile`
  auto-discovers modules from `src/*.fst`.  Remaining hardcoded couplings:
  the `packages.hello-*` attribute **names** (not just their bodies), the
  `Hello_*` C symbols in `src/main.c` (noted as "cannot be auto-derived
  without codegen"), and `src/Hello.fst`'s `module Hello`.
- `flake.lock` is checked in and pins the `dysinger/fstar` (LSP fork) +
  `dysinger/karamel` (`coextract`) forks + nixpkgs `c31cf09`.

### Problems to solve

1. **`path = ./.` copies the repo, not a starter project.**  A consumer gets
   this repo's AGENTS.md, LICENSE, README (with the F# war story and the Xeno
   diff narrative), and the pinned lockfile.  Decide the intended "fresh
   project" surface and put it in a dedicated subdir (e.g. `./template` or
   `./template/default`) containing ONLY the starter: a **new** minimal
   `flake.nix`, `default.nix`, `Makefile`, `src/`, `scripts/`, a short `.gitignore`,
   and a short project `README` (or `welcomeText` that writes one).

2. **Renamability is the key usability bar.**  A user should be able to run
   `nix flake init -t ...`, rename the package (e.g. `frost`), and have it
   build without hand-editing flake.nix/default.nix/Makefile/main.c.  This
   means parameterizing (or at least single-sourcing) the project name so a
   single top-level `pname`/`sysName` binding flows into: flake attribute
   names, `default.nix`, the Makefile, the `.fst` module name, the `main.c`
   entry symbol, and the wasm `-no-prefix`.  Investigate whether the `Hello_*`
   C symbols in `main.c` can be generated (KaRaMeL emits `Hello.h` with the
   exact prototypes — can a small `cc`/`sed`/`generate.sh` step derive the
   symbol instead of hand-writing it?).

3. **`flake.lock`: ship or omit?**  For a *remote* template the lockfile pins
   the dysinger forks; decide whether the template's own `flake.nix` should (a)
   carry `flake.lock` for reproducibility, (b) `.gitignore` it and let users
   `nix flake update`, or (c) point inputs at upstream `FStarLang/FStar` +
   `FStarLang/karamel` instead of the forks.  This is a product decision, not
   just mechanics — note it and make the call.

4. **Nix flake-template contract.**  A `templates.<name>.path` must point at a
   directory that *itself contains a `flake.nix`* (that is what `nix flake
   init` copies and what `nix build` in the new project evaluates).  Confirm
   the copied project builds standalone after `init` (the `fstar`/`karamel`
   inputs must not accidentally resolve to `self` or a relative path back into
   this repo).  Consider adding multiple named templates later (e.g. `default`
   = exe+wasm, `library` = no `main.c`) but start with ONE clean `default`.

5. **Test the remote path end-to-end.**  `nix flake init -t
   github:<you>/<repo>` requires the changes to be **committed and pushed**;
   `nix flake init -t /local/path` tests local (but still hits the
   git-dirty/lockfile resolution paths).  Verify both, then prove the output
   builds with `nix build`, `make check`, `make exe`, and `node main.js` for the
   wasm target.

### Non-goals / guardrails

- Do NOT re-add F# (removed this session for cause — see above).
- Do NOT break the existing `.#hello-*` attributes for THIS repo; the template
  should be *a thing you can also consume from here*, and the hello example
  should keep building as-is until the template is separately validated.
- Keep each extraction target's derivation idiom (verify-then-extract,
  single-source from `hello-krml`, case-exact guards) — a "proper template" is
  about *renamability + a clean copied surface*, NOT a redesign of the build
  mechanics (respect the original Goal's "NOT a redesign" constraint).

### Open questions to resolve before/while implementing

- What should the copied starter be *named* by default if not "hello"?  Pick a
  neutral placeholder (e.g. `pname = "hello"` kept as the obvious example, or
  a `{{ projectName }}`-style token the README tells users to fill in).  Nix
  flakes have no templating/`--name` flag (`nix flake init` does not accept a
  name argument), so renaming is a manual edit followed by a build — document
  the exact steps and make them minimal (ideally one edit).
- Ship a short generated README in the template (so the new project has docs)
  vs. rely on `welcomeText` only.

## Current state (resolved)

The template is a **working, reviewed flake template** that builds all targets
and runs on aarch64-darwin.  It is a git repo now (not "NOT a git repo" as an
earlier handoff claimed).

### Flake-template conversion (this session)

`templates.default.path = ./.;` — **the repository root is the template**
(no `template/` subdir).  `nix flake init -t .` copies this project directly.

Resolved decisions (from the open questions):

- **Renamability = ONE edit.**  A single `pname` binding in `flake.nix`
  (default `"fstar-example"`) is the source of truth.  It drives every
  user-facing output: flake attribute names (`packages."${pname}-…"`),
  the native exe basename (`bin/<pname>`), the C/Rust/OCaml library names
  (`lib<pname>.so`, `lib<pname>.rlib`, `<pname>.cmxa`), and the wasm
  `-no-prefix`.
- **The F* module is a GENERIC, decoupled placeholder** named `Example`
  (`src/Example.fst`, `module Example`, `module-name = "Example"`).  It is NOT
  derived from `pname`, so renaming the project does not touch the source
  module.  Renaming the module is a separate optional step (file + `module`
  header + `module-name` binding).  KaRaMeL names extracted artifacts after
  the module (`Example.c`/`.h`/`.krml`/`.ml`/`.rs`/`.wasm`), while output
  libraries/binaries are named after `pname`.
- **The `main.c` C-symbol coupling is SOLVED**: the `Makefile` **generates**
  `out/main.c` from the KaRaMeL-emitted `<Module>.h` (which declares the exact
  `<Module>_main` prototype).  No hand-written symbol; `src/main.c` is deleted.
- **`flake.lock`**: kept committed (pinned to the `dysinger/fstar`
  `v2025.10.06+lsp` + `dysinger/karamel` `coextract` forks + nixpkgs `c31cf09`).
  Pointing at upstream `FStarLang/FStar`/`karamel` `master` was tried and
  REJECTED: upstream's `.nix/fstar.nix` has a different interface (requires a
  `karamel-src` arg the overlay does not pass), so upstream is not a drop-in.

Verified this session on aarch64-darwin: `nix flake init -t .` → change
`pname` to `i18n` (ONE edit, module stays `Example`) → `nix build` all eight
`i18n-*` targets: `-checked`, `-krml`, `-exe` (`bin/i18n`, exit 0), `-native`
(`libi18n.so` + `Example.h` declaring `int32_t Example_main(void)`), `-rust`
(`libi18n.rlib`), `-ocaml` (`i18n.cmxa`/`.cmi`), `-wasm` (`Example.wasm`
exporting `main`; `node main.js` exit 0), `-fsdoc`.

Recent work (see git log) fixed reviewer findings from a brutal pass:

- `src/Hello.fst` no longer mislabels `main` as Low*; `zero` is used and
  consistently `inline_for_extraction`.
- Module name threaded: `flake.nix` `hello-module` → `default.nix` `module-name`
  → `ordered-src-modules`. The only remaining hardcoded coupling is the
  `Hello_*` C symbols in `src/main.c` (cannot be auto-derived without codegen).
- `hello-wasm` uses KaRaMeL's first-class `krml -backend wasm` + `-no-prefix
  ${hello-module}`, with a case-exact guard so a rename/case mismatch fails at
  build time, not at `node main.js` runtime.
- `Makefile` `check` now seeds `FSTAR_CHECKED` so `make check` is genuinely
  incremental (previously always re-verified due to Warning 247). `make exe`
  has loud guards for the devShell env vars.
- `.gitignore` covers the full KaRaMeL wasm/web scatter + `*.krml`/`*.o`.
- `templates.default` output added (`nix flake init -t .` works).
- Every supported F* extraction target has a flake attribute (see below).

## Targets (all verified this session)

| Flake attribute | Result |
|-----------------|--------|
| `.#hello-checked` | F* verification + stdlib `.checked` cache |
| `.#hello-krml` | KaRaMeL extraction (`Hello.krml` — IR) |
| `.#hello-exe` | native exe `bin/hello` (exit 0) |
| `.#hello-native` | C library `libhello.so` + `Hello.h` (compiled via `cc -shared`) |
| `.#hello-rust` | Rust rlib `libhello.rlib` (compiled via `rustc --crate-type lib`) |
| `.#hello-ocaml` | OCaml findlib package `hello.cmxa`/`.cmi` (via `ocamlPackages.buildDunePackage`) |
| `.#hello-wasm` | `Hello.wasm` + JS loader (`node main.js` exit 0) |
| `.#hello-fsdoc` | fsdoc → Markdown |
| `templates.default` | nix flake init -t |

### Extraction-target matrix (the complete set)

| System | Backend | Attribute | Output |
|--------|---------|-----------|--------|
| `fstar.exe --codegen` | `OCaml` | `.#hello-ocaml` | `hello.cmxa` (findlib pkg) |
| `fstar.exe --codegen` | `krml` | `.#hello-krml` | `.krml` (IR) |
| `krml -backend` | `c` | `.#hello-native` | `libhello.so` + `.h` |
| `krml -backend` | `rust` | `.#hello-rust` | `libhello.rlib` |
| `krml -backend` | `wasm` | `.#hello-wasm` | `Hello.wasm` |

(`fstar.exe --codegen` also lists `Plugin`/`PluginNoLib`/`Extension`, but those
are compiler-plugin/extension-building modes, not output languages.)

## Important corrections to earlier handoff notes

- **wasm is NOT built via `clang --target=wasm32` here.** This template uses
  KaRaMeL's native `-backend wasm`. (Xeno did have wasm *in git history* via
  a manual `clang --target=wasm32 + wasm-ld` cross-compile — commit
  `10fde426` — but that path is not the template's model, and "add proper wasm
  back to xeno" is a separate, deferred task.)
- **`-no-prefix` is NOT inert.** It strips the `<Module>_` prefix so the wasm
  entry point exports as `main` (what `main.js` searches for); without it the
  export is `Hello_main` and the loader says "no main in current scope".
- The `Makefile` has `check` / `krml` / `exe` / `clean` targets — **not** `demo`.
  The native exe does **not** print (no I/O anywhere).

## Open / deferred (non-blocking)

- **"Add proper wasm back to Xeno"** — deferred to the Xeno repo, not this
  template. The template's `hello-wasm` derivation is the reference recipe to
  port. See the task list at the end of this file.
- The `hello-wasm` derivation is a KaRaMeL-native-backend invocation, not a
  `make` target (there is no Makefile wasm step to delegate to; the native link
  is the only Makefile step). This is intentional and documented in flake.nix.
- **"F* → F#" — REMOVED (no `hello-fsharp` target).**  F*'s own repository
  marks the F# path untested: its `fsharp/README` says "currently not tested
  by anything in this repository", and its `examples/hello/README.md` says
  "None of this worked for me. I am disabling this directory for now."
  Investigation confirmed the F# backend is genuinely unsupported: no F#
  runtime is packaged in the `fstar` derivation, and the codegen
  (`string_of_mlconstant` in `FStarC.Extraction.ML.Code.fst`) emits bare `int`
  literals that do not typecheck against the (unshipped) `bigint`-backed
  `FStar_UInt8` runtime.  Rather than ship a patch to compensate for an
  upstream-unmaintained backend, this template deliberately omits F#.  See the
  NOTE comment where `hello-fsharp` used to be in `flake.nix`.

## Definition of done

A reviewer diffing `/Users/user/_/xeno/{flake.nix,codec/default.nix,tls/Makefile}`
against the template can point to each template section and see it is a
faithful, minimal copy of the original (variable names, overlay recipe,
Makefile targets, devShell env exports all correspond), with only the
multi-package/HACL*/TLS/postgres/audio domain content removed. All targets
build and run on the dev machine.

---

## TASKS: add wasm back to Xeno (Port plan, reference = this template)

Approach **A** (decided): KaRaMeL-native `-backend wasm`, NOT the historical
`clang --target=wasm32 + wasm-ld` cross-compile (Xeno commit `10fde426`). Keep
the Nix target shape (per-package `-krml`-fed `-wasm` derivations), correct
extraction throughout.

The template's reference recipe (flake.nix `hello-wasm`):

```nix
packages.hello-wasm = pkgs.stdenv.mkDerivation {
  name = "hello-wasm";
  src = ./. ;
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
    if [ ! -f "$out/${hello-module}.wasm" ]; then
      echo "ERROR: expected $out/${hello-module}.wasm, but found:" >&2
      ls -1 "$out" | grep '\.wasm$' >&2 || true
      exit 1
    fi
    echo "wasm: $(ls $out/*.wasm 2>/dev/null | wc -l) .wasm file(s)"
  '';
};
```

### Non-negotiables (carry over from the template)

1. **`-backend wasm`**, not `-wasm` (deprecated alias) and not the
   `clang --target=wasm32` path.
2. **`-no-prefix <Module>` is REQUIRED** — it strips the `<Module>_` prefix so
   the entry point exports as `main` (what `main.js` searches for).  Without
   it the export is `<Module>_main` and the loader says "no main in current
   scope".  Thread the prefix per-module, not a hardcoded string.
   **Applies only to runnable-entry targets.** For a library (no `main`) this
   flag is not needed and the JS-loader `main`-hunting path is irrelevant —
   see the "library vs runnable" note below.
3. **Case-exact `.wasm` guard** — always compare the emitted basename against
   the expected `<Module>.wasm` (case-sensitive) and `exit 1` with the on-disk
   list on mismatch. The JS loader (`shell.js` `my_modules` + `main.js`'s
   `<Module>.wasm` read) is case+CWD sensitive.
4. **Extract the RIGHT modules.** Xeno's extraction filter is `.Low`
   (`grep '\.Low'` in each `default.nix` + the inline `tls-krml`/`xeno-pg-krml`
   derivations). The wasm target must consume those same `.krml` outputs, never
   re-extract from source.

> **Library vs runnable (critical):** Xeno's `*-krml` packages are **libraries**
> (verified codecs/serializers — no `main`).  The template's `hello-wasm` is a
> *runnable-entry* target built around `Hello.main`.  These are two different
> wasm shapes:
> - **Library wasm** (what Xeno needs): emit the module's exported
>   functions/types; there is no `main`, so `-no-prefix` is unnecessary and
>   the `node main.js` loader is the wrong runner — instead validate/inspect
>   the `.wasm` (magic bytes, `wasm-objdump -x`, `WebAssembly.validate`) and
>   call the exported functions directly from a custom JS shim.
> - **Runnable wasm** (the template's shape): a `main : St Int32.t` entry is
>   extracted, `-no-prefix` makes it export as `main`, and `node main.js` runs
>   it.
> The port must produce **library wasm** unless a package happens to have a
> demo/entry module with a `main`.

### Packaging model (authoritative — from the fstar-build skill + fstar.exe)

Xeno packages follow the F* **per-package passthru variant** model: each
package yields its `{ foo-checked, foo-krml }` outputs *plus* passthru
variants keyed on the same source.  There are **two distinct extraction
systems** with a total of **five real output languages**:

| System | Flag | Outputs |
|--------|------|---------|
| F* `fstar.exe --codegen` | `OCaml` | `.ml` |
| F* `fstar.exe --codegen` | `FSharp` | `.fs` |
| F* `fstar.exe --codegen` | `krml` | `.krml` (intermediate IR) |
| KaRaMeL `krml -backend` | `c` (default) | `.c`/`.h` |
| KaRaMeL `krml -backend` | `rust` | `.rs` |
| KaRaMeL `krml -backend` | `wasm` | `.wasm` |

(Note: `fstar.exe --codegen` also lists `Plugin`/`PluginNoLib`/`Extension`, but
those are compiler-plugin/extension-building modes — NOT output languages.
Confirmed via `fstar.exe --help` and `krml --help`.)

The per-package passthru variants map onto the real languages as:

| Passthru | Backend | Output |
|----------|---------|--------|
| `ocaml`  | `fstar.exe --codegen OCaml` | `.ml` source |
| `fsharp` | `fstar.exe --codegen FSharp` | `.fs` source |
| `opam`   | (compile `ocaml`) | compiled OCaml (`.cmxa` + `META` in site-lib) |
| `native` | `krml -backend c` (compile) | `.so` + `.h` (compiled C; **no `.krml`**) |
| `rust`   | `krml -backend rust` | `.rs` (Rust translation; `-crate`/`-fno-box`/`-bundle` are Rust-specific) |
| `wasm`   | `krml -backend wasm` | `.wasm` |

> The fstar-build skill's own table lists only `ocaml`/`opam`/`native`/`wasm`
> (4 variants) and omits BOTH `fsharp` AND `rust`.  Both are real:
> `fstar.exe --codegen FSharp` (Xeno history `10fde426` records "OCaml ✓ / F# ✓
> / WASM ✓"), and `krml -backend rust` (whose `-crate`/`-fno-box` flags confirm
> a first-class Rust backend).  Treat `fsharp` (`.fs`) and `rust` (`.rs`) as
> first-class variants alongside the rest.

So the correct Xeno shape is not a *separate* `codec-wasm` derivation that
re-implements extraction; it is the **`wasm` passthru variant** of the existing
`codec-krml` derivation — take the already-extracted `Data.Codec.Low.krml` and
run `krml -backend wasm` on it to emit `Data.Codec.Low.wasm`.  This mirrors
`native` (which compiles the `.krml` to `.so`/`.h`) and keeps extraction
correctly single-sourced from `codec-krml`.  (`rust` would similarly be a
passthru of `codec-krml` via `krml -backend rust`; `fsharp` a passthru of the
`fstar.exe --codegen FSharp` source extraction, sibling of `ocaml`.)

### Task list (in dependency order)

- [ ] **T1 — Pilot on `codec` as a LIBRARY (no `main`).**  Confirm
      `krml -backend wasm codec-krml/Data.Codec.Low.krml` (NO `-no-prefix`)
      emits `Data.Codec.Low.wasm` with the `Data.Codec.Low.*` exports (decode/
      encode), and validate via `wasm-objdump -x` / `WebAssembly.validate` —
      NOT via `node main.js` (there is nothing to run).
- [ ] **T2 — Add the `wasm` passthru variant** to `codec/default.nix` (next to
      `native`, if present): take `${codec-krml}`'s `Data.Codec.Low.krml`,
      `-tmpdir wasm-out -backend wasm <that>.krml`, case-exact guard,
      `installPhase` ships `Data.Codec.Low.wasm` (+ `.wast`).  No `-no-prefix`,
      no `main.js` loader (library).
- [ ] **T3 — Wire it in** as `codec-wasm` in `packages`/`legacyPackages`,
      leaving `codec-checked`/`codec-krml` untouched. Not `default`.
- [ ] **T4 — Verify**: `.wasm` magic `\0asm`, `wasm-objdump -x` shows the
      expected `Data.Codec.Low.*` exports (no `main`), and optionally
      `WebAssembly.validate`.
- [ ] **T5 — Generalize**: factor `mk-krml-wasm { krml-drv; module; }`
      (no `-no-prefix`) as the shared passthru helper, keyed off the existing
      `-krml` output — NOT off source.
- [ ] **T6 — Roll out to library packages** that have a `*.Low` extractable
      surface; skip any package with zero extractable modules.  (Optional,
      separate: a single demo package that bundles a `main` wrapper if a
      runnable wasm is ever wanted — that is the `hello-wasm` shape, not the
      library shape.)
- [ ] **T7 — Document** the library-wasm targets (`wasm-objdump -x` to inspect
      exports, `WebAssembly.validate` to check well-formedness) — do not tell
      users to `node main.js` on a library.

### Open questions to resolve during T1 (do not guess)

- Multi-`.krml` packages (e.g. `tls` has many `.Low` modules): does a single
  `krml -backend wasm` call accept the concatenated `.krml` set, or must each
  module be emitted separately?  (Template is single-module; library-wise the
  `.Low` count is what matters.)
- Whether to also ship the JS loader bundle for library targets, or only
  `.wasm`/`.wast` + a note that consumers instantiate it directly (no `main`).
