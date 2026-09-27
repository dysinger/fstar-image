# F* Project Template

Copyright 2026 Department of Code LLC.
SPDX-License-Identifier: AGPL-3.0-or-later

## Getting started

```bash
# 1. Initialize a new F* project (copies the template into the current dir).
nix flake init -t github:dysinger/fstar-nix-flake-template

# 2. Name it: rename src/Example.fst -> src/<Name>.fst, its `module Example`
#    header, and the literal names in flake.nix (see below).

# 3. Build it.
nix build

# 4. Drop into the dev loop (fstar.exe, krml, OCaml LSP already on PATH).
nix develop
```

---

A minimal, self-contained [F*](https://www.fstar-lang.org/) project that
demonstrates the full verified-to-runnable workflow: a single verified module
is checked, extracted to C via KaRaMeL, and run as a **native executable** and
a **WebAssembly module** — all driven by [Nix flakes](https://nixos.wiki/wiki/Flakes).

The build is three layers, one per environment:

| File | Responsibility | Works without flakes? |
|------|----------------|-----------------------|
| `flake.nix` | inputs/outputs + `devShell` only | no (needs flakes) |
| `default.nix` | builds the targets (all of them) | yes (`nix-build` / `import`) |
| `Makefile` | the shell-script build (module order) | yes (plain `fstar`/`karamel` on PATH) |

The nixpkgs overlay (in `flake.nix`) builds `fstar`, `karamel`,
`fstar-checked`, and `fstar-krml` from the pinned forks; the flake passes them
to `default.nix` by named argument.  `default.nix` delegates verification and
extraction to the `Makefile` (`make check` / `make krml` / `make exe`), which
owns the module list and its dependency order.  The editor LSP
(`fstar.exe --lsp`) is a dev-loop aid only — `nix build` is the verification
gate.

## What the template demonstrates

`src/Example.fst` is a small verified module with three layers:

| Layer | Contents | Effect | Purpose |
|-------|----------|--------|---------|
| Operations | `add`, `xor`, `zero` | `Tot` (pure) | Extractable byte helpers |
| Proofs | `lemma_add_commutes`, `lemma_xor_involutive` | `Lemma` (ghost) | Verified properties, erased before extraction |
| Entry point | `main` | `St` (stateful) | Runnable entry, exercises the verified operations |

- `lemma_add_commutes` proves `add a b == add b a` (byte addition commutes).
- `lemma_xor_involutive` proves `xor (xor a b) b == a` (XOR is its own inverse),
  forwarding to the standard library lemma `FStar.UInt.logxor_inv`.
- `main` calls the verified `add`/`xor` and returns the exit code `0`.  It does
  **not** call the lemmas: lemmas are compile-time proofs, erased before C
  extraction, so a runnable entry point uses the verified *operations*.

The module verifies with **zero admits** — every lemma discharges through SMT
or a standard-library lemma.

## Prerequisites

[Nix](https://nixos.org/download/) with flakes enabled, plus an internet
connection to fetch `nixpkgs`, `fstar`, and `karamel`.

## Layout

```
.
├── flake.nix          # inputs/outputs + devShell (flakes only)
├── default.nix        # builds every target (checked/krml/exe/native/rust/ocaml/wasm)
├── Makefile           # the no-nix shell build (owns module order)
└── src/
    └── Example.fst    # The verified F* example module (extracts to C / OCaml / Rust / ...)
```

(The native C driver `main.c` is **generated** by the `-exe` derivation from
the KaRaMeL-emitted header — see "How the entry points work" below — so there
is no checked-in `src/main.c` and no hand-edited `<Module>_main` symbol.)

## Create a new project from this template

```bash
# 1. Initialize a new project (copies this repo's files into the current dir).
nix flake init -t github:dysinger/fstar-nix-flake-template

# 2. Rename the module (a real rename, not a config edit):
#    - src/Example.fst -> src/<Name>.fst and its `module Example` header
#    - the `pname = "fstar-example"` binding in default.nix
#    - the literal flake attribute names in flake.nix
#      (`packages.fstar-example-checked`, ..., `apps.default`)

# 3. Build everything.
nix build
```

The package name lives in `default.nix`'s `pname`; the flake re-exposes the
package under literal attribute names that must match it.  A rename is honest:
edit the module source, `default.nix`'s `pname`, and the flake attribute keys
together.  There is no `nix flake init --name` flag and no rename magic.

## Targets

| Flake attribute | What it produces | Runnable? |
|-----------------|------------------|-----------|
| `.#fstar-example-checked` | F\* verification (`Example.fst.checked` + stdlib `.checked` cache) | no |
| `.#fstar-example-krml` | KaRaMeL extraction (`Example.krml` — intermediate IR) | no |
| `.#fstar-example-exe` | Native executable (`bin/fstar-example`) | **yes** |
| `.#fstar-example-native` | Native C library (`libfstar-example.so` + `Example.h`) | no |
| `.#fstar-example-rust` | Rust library (`libfstar-example.rlib`) | no |
| `.#fstar-example-ocaml` | OCaml findlib package (`fstar-example.cmxa` + `fstar-example.cmi`) | no |
| `.#fstar-example-wasm` | WebAssembly module + JS loader bundle | **yes** |

`nix build` with no argument builds the default package (`fstar-example-krml`).

Every supported F* extraction target has a flake attribute:

| System | Backend | Attribute | Output |
|--------|---------|-----------|--------|
| F* `fstar.exe --codegen` | `OCaml` | `.#fstar-example-ocaml` | `fstar-example.cmxa` (findlib pkg) |
| F* `fstar.exe --codegen` | `krml` | `.#fstar-example-krml` | `.krml` (IR) |
| KaRaMeL `krml -backend` | `c` | `.#fstar-example-native` | `libfstar-example.so` + `.h` |
| KaRaMeL `krml -backend` | `rust` | `.#fstar-example-rust` | `libfstar-example.rlib` |
| KaRaMeL `krml -backend` | `wasm` | `.#fstar-example-wasm` | `Example.wasm` |

### Why there is no F# target

`fstar.exe --codegen FSharp` exists and emits a `.fs` file, but this template
**deliberately omits it**.  F*'s own repository marks the F# path as
unmaintained:

- its `fsharp/README` says the F# runtime is *"currently not tested by anything
  in this repository"*; and
- its `examples/hello/README.md` says *"None of this worked for me. I am
  disabling this directory for now."*

Beyond that, the backend is effectively unbuildable with the current
`fstar`/`karamel` inputs:

1. **No packaged runtime.**  F* ships an F# runtime only as *source* under
   `fsharp/base/` (`Prims.fs`, `FStar_UInt8.fs`, `FStar_Int32.fs`, ...); that
   directory is not installed into the `fstar` derivation, so the symbols the
   extracted `.fs` references (`FStar_UInt8`, `FStar_Int32`, `Prims`) have no
   `.dll` to link against.
2. **Codegen/literal mismatch.**  `string_of_mlconstant` in
   `FStarC.Extraction.ML.Code.fst` emits bare `int` literals (e.g. `0x00`) for
   `Int8` constants, while the unshipped `FStar_UInt8.fs` realizes `uint8` as
   `Prims.int` (= `bigint`).  The extracted output does not typecheck against
   its own runtime.
3. **Deprecated syntax.**  The codegen emits `#light "off"` (deprecated since
   F# 2.0), which requires `--mlcompatibility`; even then the above mismatch
   remains.

If upstream F* later ships a supported F# backend + runtime, add a
`fstar-example-fsharp` derivation mirroring the `fstar-example-ocaml` shape (extract `--codegen
FSharp`, then `dotnet build` against the runtime).  Until then, no F# target.

## Build everything

```bash
nix build \
  .#fstar-example-checked .#fstar-example-krml .#fstar-example-exe .#fstar-example-native \
  .#fstar-example-rust .#fstar-example-ocaml .#fstar-example-wasm
```

## Run the native executable

```bash
nix build .#fstar-example-exe
./result/bin/fstar-example
echo $?   # -> 0
```

The executable links the verified module through a small C driver that the
`-exe` derivation **generates** from the KaRaMeL-emitted `Example.h` header
(which declares the exact `Example_main` prototype).  The driver calls
`Example_main` (the extracted form of `Example.main`, which exercises the
verified operations) and forwards its exit code (`0`) to the process.  It
performs no I/O.

## Run the WebAssembly module

```bash
nix build .#fstar-example-wasm
cd result
node main.js
# ... main found in module Example
# ... done running main
```

The wasm backend emits `Example.wasm` (exporting the verified `add`, `xor`, and
the `main` entry point) plus a small KaRaMeL JS loader bundle (`main.js`,
`loader.js`, `shell.js`, `browser.js`, `main.html`, `layouts.json`, plus a
`README` file with no extension).  `node main.js` instantiates the module
and invokes `main`; it exits `0` on success.  To run it in a browser, serve the
directory over HTTP and open `main.html`.

> **Note:** the F\* module is pure verified computation — `main` exercises the
> proven operations and returns an exit code; it performs no I/O, and neither
> does the native driver.  Both targets run the same verified `main` and exit
> `0` without printing.

## Verify and extract individually

```bash
nix build .#fstar-example-checked   # F* verification only (no extraction)
nix build .#fstar-example-krml      # KaRaMeL extraction only (depends on checked)
```

`fstar-example-checked` emits a directory containing `Example.fst.checked` *plus* the
~421 pre-verified standard-library `.checked` files (the downstream
verification cache).  Your module's `.checked` is the one named
`Example.fst.checked`.

## Dev loop (`nix develop` + Makefile)

```bash
nix develop        # drops you in a shell with fstar.exe, kramel, python, OCaml LSP
make check         # verify
make krml          # extract to out/krml/*.krml
make exe           # emit C, compile, link -> out/fstar-example
make clean
```

For fast interactive checking use the editor LSP (`fstar.exe --lsp`, see
below) — the LSP is a dev-loop aid, not a second build system.  The `nix build
.#fstar-example-checked` run (with a Z3 resource limit) is the authoritative
gate.

The `nix develop` devShell exports the environment the `Makefile` (and the
`-exe`/`-native` derivations and a manual `fstar.exe`/`krml` invocation) need:

| Variable | Purpose |
|----------|---------|
| `FSTAR_KRML` | krmllib runtime `.krml` (for the native C link) |
| `FSTAR_CHECKED` | pre-verified stdlib `.checked` cache |
| `KRML_HOME` | KaRaMeL home (krmllib, include headers) |
| `KRM_LIB` | krmllib directory |
| `KRM_INC` | C include flags for the generated code |

## LSP

`nix develop` provides `fstar.exe --lsp`.  Point your editor (VS Code / Emacs /
Vim) at it for hover docs, diagnostics, and completions.

> The editor LSP is a **dev-loop aid, not the verification gate** — the
> `nix build .#fstar-example-checked` run (with a Z3 resource limit) is the source of
> truth.

## Extending

- **Edit the logic** — modify `src/Example.fst` with your own verified functions,
  lemmas, and `main`.
- **Rename the module** (optional) — the verified module is a generic
  placeholder named `Example`.  To rename it, do two things together:
  rename `src/Example.fst` → `src/<Mod>.fst` and change its `module Example`
  header → `module <Mod>`.  The `Makefile` and `default.nix` discover the
  module name from the source tree, so no nix argument needs editing.  The
  C entry symbol (`<Module>_main`) needs no hand-edit — the `Makefile` (and the
  `-exe` derivation) generate `main.c` from the KaRaMeL-emitted header.
  (Renaming the *project* — `pname` — is separate: edit `pname` in
  `flake.nix`.)
- **Add more modules** — list them (in dependency order, leaf modules first) in
  the `Makefile`'s `SRC_MODS` (the Makefile owns module order); a plain
  alphabetical `sort` would verify a dependent module before its leaf and
  trigger F* Warning 247.
- **Ship a library instead of an exe** — drop the `make exe` target and the
  `${pname}-exe` derivation; the `${pname}-krml` output is the library's
  extracted `.krml`/C.  When the package has `.Low` modules, `make krml` (and
  the `default.nix` `krml` derivation) extract only those `.Low` modules
  automatically; a plain extractable module with no `.Low` (like `Example`)
  extracts as itself.

Module naming: this example is a *plain extractable* module (`module Example`).
For stateful Low\* code (heap buffers, `Stack` effects), the ecosystem
convention is a `*.Low` suffix plus a two-layer spec/impl split.  A namespaced
module (`module Data.Codec.Types`) is fully supported: F\* preserves the dots
in the `.fst.checked` cache filename (`Data.Codec.Types.fst.checked`) while the
KaRaMeL extraction name turns dots into underscores (`Data_Codec_Types.krml`).

## How the entry points work

This section explains the mechanics behind the three artifacts (`main.c`,
`.wasm`, and the JS loader bundle), so a reader can see *why* the native and
wasm paths differ.

### The module has one `main` — the two targets consume it differently

`src/Example.fst` defines a single `main : unit -> St Int32.t` function.  All
three targets run *that same verified function*; they differ only in **who
supplies the surrounding runtime** that calls it and hands back the exit code.

| Target | Who supplies the entry point | What runs it |
|--------|------------------------------|--------------|
| `fstar-example-exe` | generated `main.c` (from `Example.h`) | The OS / libc (`_start` → `main`) |
| `fstar-example-wasm` | KaRaMeL (exports a function named `main`) | The generated JS loader (`main.js`) |

### Why the native (POSIX) target needs `main.c`

KaRaMeL's C backend extracts `Example.main` to a C function `Example_main()` in the
generated `Example.c`, but it **deliberately does not emit a C `main()`**.  There
are two reasons:

1. KaRaMeL can't know how *your* program wants to wire I/O, `argc`/`argv`, or
   integrations with other host code.
2. There is often no single `main` — the extracted module may be a **library**
   whose whole purpose is to be called by *your* host program.

On a real OS the C toolchain already provides the runtime entry point
(`_start` → `__libc_start_main` → `main`), so KaRaMeL's job is only to produce
portable C; the boundary is "KaRaMeL gives you the library, the platform gives
you `main`."  The `-exe` derivation generates that two-line bridge for this
template (from the `<Module>_main` prototype in the emitted header): it calls
`Example_main()` and forwards its exit code.

```c
#include "Example.h"

int main(void) {
  return (int)Example_main();
}
```

### Why the wasm target does *not* need `main.c`

A wasm module is just a bag of imports and exports — there is **no OS, no
libc, no `_start`, and no caller** that already knows to run `main`.  So
KaRaMeL's wasm backend *must* own the entire runtime, entry point included:

- It exports the extracted `Example.main` as a wasm function literally named
  `main` (visible in the loader log as `Example exports ... main ...`) — this is
  what the `-no-prefix Example` flag in `flake.nix` does: it strips the
  `<Module>_` prefix so the export is `main` rather than `Example_main`, which
  is the name `main.js` searches for.
- It generates a JS loader bundle (`main.js`, `loader.js`, `shell.js`,
  `browser.js`, `main.html`, `layouts.json`) that instantiates the module,
  wires up the imports (memory, `malloc`, etc.), finds the `main` export,
  invokes it, and propagates the exit code.

Because KaRaMeL provides *both* the entry-point convention *and* the caller in
the wasm world, no C driver is needed.  You only need the `.wasm` file plus the
JS loader to run it:

```bash
nix build .#fstar-example-wasm
cd result && node main.js   # ... main found in module Example
                            # ... done running main
```

This split is not KaRaMeL-specific.  Emscripten does the same: a native
`main()` becomes a wasm export and Emscripten generates a JS shim to call it,
because the two worlds have different entry-point rules.

### Proving wasm was generated (without the loader)

`main.js` is only needed to *execute* the module.  To simply confirm that valid
wasm was produced, the `.wasm` file is sufficient:

```bash
head -c4 result/Example.wasm | xxd      # 00000000: 0061 736d  (".asm" magic)
file result/Example.wasm                # WebAssembly (wasm) binary module ...
# or validate it:
nix shell nixpkgs#nodejs_22 -c node -e \
  'console.log(WebAssembly.validate(new Uint8Array(require("fs").readFileSync("result/Example.wasm"))))'
```

The KaRaMeL wasm backend also emits a human-readable `Example.wast` alongside the
binary if you want to inspect the module textually.

## Notes

- The `fstar` and `karamel` inputs are pinned to
  [`dysinger/fstar`](https://github.com/dysinger/fstar) (LSP-enabled build) and
  [`dysinger/karamel`](https://github.com/dysinger/karamel) (the `coextract`
  branch) — forks carrying patches not yet upstream.  For production you may
  prefer upstream `FStarLang/FStar` + `FStarLang/karamel` releases.

## License

[CC-BY-4.0](LICENSE).
