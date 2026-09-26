# F* Project Template

A minimal, self-contained [F*](https://www.fstar-lang.org/) project that
demonstrates the full verified-to-runnable workflow: a single verified module
is checked, extracted to C via KaRaMeL, and run as a **native executable** and
a **WebAssembly module** — all driven by [Nix flakes](https://nixos.wiki/wiki/Flakes).

The build is a clean, single-package reduction of the Xeno build: same overlay,
same `default.nix`/`Makefile` shape, with the multi-package/HACL*/TLS domain
content removed.

## What the template demonstrates

`src/Hello.fst` is a small verified module with three layers:

| Layer | Contents | Effect | Purpose |
|-------|----------|--------|---------|
| Operations | `add`, `xor`, `zero` | `Tot` (pure) | Extractable byte helpers |
| Proofs | `lemma_add_commutes`, `lemma_xor_involutive` | `Lemma` (ghost) | Verified properties, erased before extraction |
| Entry point | `main` | `St` (Low\*) | Runnable entry, exercises the verified operations |

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
# Hello, F*! 10 + 20 = 30
```

The executable links the verified `Hello_add` (the extracted form of
`Hello.add`) through a checked-in two-line C driver (`src/main.c`), which
KaRaMeL does not generate on its own.  The driver prints the result and
forwards `Hello_main`'s exit code to the process.

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
`loader.js`, `shell.js`, `main.html`).  `node main.js` instantiates the module
and invokes `main`; it exits `0` on success.  To run it in a browser, serve the
directory over HTTP and open `main.html`.

> **Note:** the F\* module is pure verified computation — `main` exercises the
> proven operations and returns an exit code; it performs no I/O by design.
> The native driver (`src/main.c`) demonstrates the verified code by calling
> `Hello_add` and printing the result; the wasm module runs the same verified
> `main` (exit `0`).

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
- **Rename the module** — rename `src/Hello.fst`, update `ordered-src-modules`
  in `default.nix`, the `hello-module` references in `flake.nix` and `Makefile`,
  and the `Hello_`/`Hello_add` symbol names in `src/main.c` (extracted C
  symbols are `<Module>_<function>`).
- **Add more modules** — list them (in dependency order, leaf modules first) in
  `ordered-src-modules` in `default.nix`; the `Makefile` auto-discovers modules
  from `src/*.fst`.
- **Ship a library instead of an exe** — drop `src/main.c`, the `make exe`
  target, and `hello-exe`; the `hello-krml` output is the library's extracted
  `.krml`/C.

Module naming: this example is a *plain extractable* module (`module Hello`).
For stateful Low\* code (heap buffers, `Stack` effects), the ecosystem
convention is a `*.Low` suffix plus a two-layer spec/impl split.

## Notes

- The `fstar` and `karamel` inputs are pinned to
  [`dysinger/fstar`](https://github.com/dysinger/fstar) (LSP-enabled build) and
  [`dysinger/karamel`](https://github.com/dysinger/karamel) (the `coextract`
  branch) — forks carrying patches not yet upstream.  For production you may
  prefer upstream `FStarLang/FStar` + `FStarLang/karamel` releases.

## License

[CC-BY-4.0](LICENSE).
