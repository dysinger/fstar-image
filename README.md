# F* Project Template

A minimal, self-contained [F*](https://www.fstar-lang.org/) project that
demonstrates the full verified-to-runnable workflow: a single verified module
is checked, extracted to C via KaRaMeL, and run as a **native executable** and
a **WebAssembly module** — all driven by [Nix flakes](https://nixos.wiki/wiki/Flakes).

The build uses the standard F* + KaRaMeL flake pattern: a nixpkgs overlay
providing `fstar`, `karamel`, `fstar-checked`, and `fstar-krml`; a `default.nix`
returning `{ hello-checked; hello-krml; }`; and a `Makefile` with `check` / `krml`
/ `exe` targets.

## What the template demonstrates

`src/Hello.fst` is a small verified module with three layers:

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
├── flake.nix          # Nix build: verify / extract / exe / wasm / fsdoc / devShell
├── default.nix        # Package: returns { hello-checked; hello-krml; }
├── Makefile           # Dev-loop: make check / make krml / make exe
├── src/
│   ├── Hello.fst      # The verified F* module (extracts to C)
│   └── main.c         # Native C driver (calls the extracted entry point)
└── scripts/
    └── fsdoc.py       # fsdoc comment extractor
```

## Using as a template

This flake is a real Nix flake template.  Start a new project from it with:

```bash
nix flake init -t github:<you>/<this-repo>     # or a local path: -t /path/to/fstar-template
nix develop      # verify/extract/dev-loop environment
nix build        # build all targets
```

The `templates.default` output points at the repository root, so `nix flake
init` copies the whole layout (flake.nix, default.nix, Makefile, src/, scripts/)
and its `welcomeText` prints the pointer to the build/run commands.  After
initializing, rename `Hello.fst` (see the "Rename the module" bullet under
[Extending](#extending)) and replace this README's front matter with your own.

## Targets

| Flake attribute | What it produces | Runnable? |
|-----------------|------------------|-----------|
| `.#hello-checked` | F\* verification (`Hello.fst.checked` + stdlib `.checked` cache) | no |
| `.#hello-krml` | KaRaMeL extraction (`Hello.krml`) | no |
| `.#hello-exe` | Native executable (`bin/hello`) | **yes** |
| `.#hello-wasm` | WebAssembly module + JS loader bundle | **yes** |
| `.#hello-fsdoc` | `fsdoc` comments → Markdown | no |

`nix build` with no argument builds the default package (`hello-krml`).

## Build everything

```bash
nix build .#hello-checked .#hello-krml .#hello-exe .#hello-wasm .#hello-fsdoc
```

## Run the native executable

```bash
nix build .#hello-exe
./result/bin/hello
echo $?   # -> 0
```

The executable links the verified module through a checked-in two-line C
driver (`src/main.c`), which KaRaMeL does not generate on its own.  The driver
calls `Hello_main` (the extracted form of `Hello.main`, which exercises the
verified operations) and forwards its exit code (`0`) to the process.  It
performs no I/O.

## Run the WebAssembly module

```bash
nix build .#hello-wasm
cd result
node main.js
# ... main found in module Hello
# ... done running main
```

The wasm backend emits `Hello.wasm` (exporting the verified `add`, `xor`, and
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
nix build .#hello-checked   # F* verification only (no extraction)
nix build .#hello-krml      # KaRaMeL extraction only (depends on checked)
```

`hello-checked` emits a directory containing `Hello.fst.checked` *plus* the
~421 pre-verified standard-library `.checked` files (the downstream
verification cache).  Your module's `.checked` is the one named
`Hello.fst.checked`.

## Document (fsdoc)

```bash
nix build .#hello-fsdoc
cat result/fstar-docs.md
```

`scripts/fsdoc.py` extracts `(** ... *)` doc comments from `src/*.fst` into a
single Markdown outline.

## Dev loop (`nix develop` + Makefile)

```bash
nix develop        # drops you in a shell with fstar.exe, kramel, python, OCaml LSP
make check         # verify
make krml          # extract to out/krml/*.krml
make exe           # emit C, compile, link -> out/hello
make clean
```

The devShell exports the environment the `Makefile` needs:

| Variable | Purpose |
|----------|---------|
| `FSTAR_KRML` | krmllib runtime `.krml` (for the `make exe` link) |
| `FSTAR_CHECKED` | pre-verified stdlib `.checked` cache |
| `KRML_HOME` | KaRaMeL home (krmllib, include headers) |
| `KRM_LIB` | krmllib directory |
| `KRM_INC` | C include flags for the generated code |

## LSP

`nix develop` provides `fstar.exe --lsp`.  Point your editor (VS Code / Emacs /
Vim) at it for hover docs, diagnostics, and completions.

> The editor LSP is a **dev-loop aid, not the verification gate** — the
> `nix build .#hello-checked` run (with a Z3 resource limit) is the source of
> truth.

## Extending

- **Edit the logic** — modify `src/Hello.fst` with your own verified functions,
  lemmas, and `main`.
- **Rename the module** — rename `src/Hello.fst` and change the single
  `hello-module` binding in `flake.nix` (it flows into `default.nix` via
  `module-name` and into the native exe + wasm derivations), then update the
  `Hello_`/`Hello_add` symbol names in `src/main.c` (extracted C symbols are
  `<Module>_<function>`).  The `Makefile` auto-discovers modules from
  `src/*.fst`, so it needs no rename edits.
- **Add more modules** — list them (in dependency order, leaf modules first) in
  `ordered-src-modules` in `default.nix`; the `Makefile` auto-discovers modules
  from `src/*.fst`.
- **Ship a library instead of an exe** — drop `src/main.c`, the `make exe`
  target, and `hello-exe`; the `hello-krml` output is the library's extracted
  `.krml`/C.

Module naming: this example is a *plain extractable* module (`module Hello`).
For stateful Low\* code (heap buffers, `Stack` effects), the ecosystem
convention is a `*.Low` suffix plus a two-layer spec/impl split.

## How the entry points work

This section explains the mechanics behind the three artifacts (`main.c`,
`.wasm`, and the JS loader bundle), so a reader can see *why* the native and
wasm paths differ.

### The module has one `main` — the two targets consume it differently

`src/Hello.fst` defines a single `main : unit -> St Int32.t` function.  All
three targets run *that same verified function*; they differ only in **who
supplies the surrounding runtime** that calls it and hands back the exit code.

| Target | Who supplies the entry point | What runs it |
|--------|------------------------------|--------------|
| `hello-exe` (`make exe`) | `src/main.c` | The OS / libc (`_start` → `main`) |
| `hello-wasm` | KaRaMeL (exports a function named `main`) | The generated JS loader (`main.js`) |

### Why the native (POSIX) target needs `main.c`

KaRaMeL's C backend extracts `Hello.main` to a C function `Hello_main()` in the
generated `Hello.c`, but it **deliberately does not emit a C `main()`**.  There
are two reasons:

1. KaRaMeL can't know how *your* program wants to wire I/O, `argc`/`argv`, or
   integrations with other host code.
2. There is often no single `main` — the extracted module may be a **library**
   whose whole purpose is to be called by *your* host program.

On a real OS the C toolchain already provides the runtime entry point
(`_start` → `__libc_start_main` → `main`), so KaRaMeL's job is only to produce
portable C; the boundary is "KaRaMeL gives you the library, the platform gives
you `main`."  `src/main.c` is that two-line bridge for this template: it calls
`Hello_main()` and forwards its exit code.

```c
#include "Hello.h"

int main(void) {
  return (int)Hello_main();
}
```

### Why the wasm target does *not* need `main.c`

A wasm module is just a bag of imports and exports — there is **no OS, no
libc, no `_start`, and no caller** that already knows to run `main`.  So
KaRaMeL's wasm backend *must* own the entire runtime, entry point included:

- It exports the extracted `Hello.main` as a wasm function literally named
  `main` (visible in the loader log as `Hello exports ... main ...`) — this is
  what the `-no-prefix Hello` flag in `flake.nix` does: it strips the
  `<Module>_` prefix so the export is `main` rather than `Hello_main`, which
  is the name `main.js` searches for.
- It generates a JS loader bundle (`main.js`, `loader.js`, `shell.js`,
  `browser.js`, `main.html`, `layouts.json`) that instantiates the module,
  wires up the imports (memory, `malloc`, etc.), finds the `main` export,
  invokes it, and propagates the exit code.

Because KaRaMeL provides *both* the entry-point convention *and* the caller in
the wasm world, no C driver is needed.  You only need the `.wasm` file plus the
JS loader to run it:

```bash
nix build .#hello-wasm
cd result && node main.js   # ... main found in module Hello
                            # ... done running main
```

This split is not KaRaMeL-specific.  Emscripten does the same: a native
`main()` becomes a wasm export and Emscripten generates a JS shim to call it,
because the two worlds have different entry-point rules.

### Proving wasm was generated (without the loader)

`main.js` is only needed to *execute* the module.  To simply confirm that valid
wasm was produced, the `.wasm` file is sufficient:

```bash
head -c4 result/Hello.wasm | xxd      # 00000000: 0061 736d  (".asm" magic)
file result/Hello.wasm                # WebAssembly (wasm) binary module ...
# or validate it:
nix shell nixpkgs#nodejs_22 -c node -e \
  'console.log(WebAssembly.validate(new Uint8Array(require("fs").readFileSync("result/Hello.wasm"))))'
```

The KaRaMeL wasm backend also emits a human-readable `Hello.wast` alongside the
binary if you want to inspect the module textually.

## Notes

- The `fstar` and `karamel` inputs are pinned to
  [`dysinger/fstar`](https://github.com/dysinger/fstar) (LSP-enabled build) and
  [`dysinger/karamel`](https://github.com/dysinger/karamel) (the `coextract`
  branch) — forks carrying patches not yet upstream.  For production you may
  prefer upstream `FStarLang/FStar` + `FStarLang/karamel` releases.

## License

[CC-BY-4.0](LICENSE).
