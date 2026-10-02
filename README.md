# example — minimal verified F* project template

Copyright 2026 Department of Code LLC.
SPDX-License-Identifier: AGPL-3.0-or-later

A minimal, self-contained [F*](https://www.fstar-lang.org/) project that
demonstrates the full verified-to-runnable workflow: a four-module
Boyer–Moore majority-vote library (pure spec + pure algorithm + Pulse leaf +
CLI) is checked, extracted via **Custard**, and compiled to **C** (a native
library and a standalone executable) and **OCaml** — all driven by
[Nix flakes](https://nixos.wiki/wiki/Flakes).

This is the Custard era of F\* (`v2026.09.20+lsp`): the Low\* stdlib was
removed upstream and replaced by **Pulse** + **Custard**, the direct-C11
extractor with no separate toolchain or runtime.

## Getting started

```bash
# 1. Initialize a new F* project (copies the template into the current dir).
nix flake init -t github:dysinger/fstar-nix-flake-template

# 2. Rename it (see "Renaming" below): rename the module files, their
#    `module X` headers, and the `pname` in default.nix.

# 3. Build everything.
nix build \
  .#checked .#ocaml .#native .#fsharp .#cli

# 4. Run the CLI.
nix run .#cli     # exits 0

# 5. Drop into the dev loop (fstar.exe + OCaml LSP on PATH).
nix develop
```

## The three build layers

| File | Responsibility | Works without flakes? |
|------|----------------|-----------------------|
| `flake.nix` | inputs/outputs + `devShell` only | no (needs flakes) |
| `default.nix` | builds every target | yes (`nix-build` / `import`) |
| `Makefile` | the shell build (module order + flags) | yes (plain `fstar.exe` on PATH) |

The nixpkgs overlay (in `flake.nix`) builds `fstar` and `fstar-checked` from
the pinned fork; the flake passes them to `default.nix` by named argument.
`default.nix` delegates verification to the `Makefile` (`make check`), which
owns the module list and its dependency order.  The editor LSP
(`fstar.exe --lsp`) is a dev-loop aid only — `nix build` is the verification
gate.

## What the template demonstrates

The example is a **Boyer–Moore majority-vote** algorithm — the canonical
linear-time, constant-space scan for a sequence's majority element — split into
four layers, mirroring the `codec` Types / Codec / Pulse split:

| Module | Layer | Effect | Purpose |
|--------|-------|--------|---------|
| `Example.Majority.Types` | pure spec | `Tot` | `elem`/`count`/`majority` + `lemma_count_empty` |
| `Example.Majority` | pure algorithm | `Tot` | `candidate_step`/`bm_scan`/`find_candidate` + lemmas |
| `Example.Majority.Pulse` | Pulse leaf | `stt` (`fn`) | `majority_vote` over a mutable array, C/OCaml extractable |
| `Example.Majority.CLI` | CLI entry | `stt` (`fn`) | allocates a static vote table, runs the leaf, returns exit status |

- `Example.Majority.Types` defines the mathematical notion `majority x s` (an element
  occurring strictly more than half the time) and proves `lemma_count_empty`.
- `Example.Majority` implements `find_candidate` — the Boyer–Moore candidate-selection
  pass — and `verify` (the verification pass).  It also carries the *proven*
  bridge lemmas the Pulse leaf relies on: `candidate_step_u32` (the extractable
  `U32.t`-counter form of the one-step transition), `bm_scan` (the fold by
  index), `lemma_bm_scan_step`, and `lemma_find_candidate_slice`.
- `Example.Majority.Pulse` re-implements the same scan over a
  `Pulse.Lib.Array.array U32.t` with a `while` loop, and its post-condition ties
  the surviving candidate back to `Example.Majority.find_candidate` — the spec↔impl
  correspondence is discharged by the pure lemmas.
- `Example.Majority.CLI` binds a *static* vote table (`Pulse.Lib.GlobalArray`, a compile-time
  constant) and calls `majority_vote`; Custard compiles it with
  `--custard_main Example.Majority.CLI.main` into a standalone C program whose exit status
  reports whether the scan found the expected winner.

Everything verifies with **zero admits** — every lemma discharges through SMT
or a hand-written proof in `Example.Majority.fst`.

## Prerequisites

[Nix](https://nixos.org/download/) with flakes enabled, plus an internet
connection to fetch `nixpkgs` and the pinned `fstar` fork.

## Layout

```
.
├── flake.nix          # inputs/outputs + devShell (flakes only)
├── default.nix        # builds every target (checked/ocaml/native/fsharp/cli)
├── Makefile           # the no-nix shell build (owns module order)
└── src/
    ├── Example.Majority.Types.fst   # pure spec
    ├── Example.Majority.fst         # pure algorithm + lemmas
    ├── Example.Majority.Pulse.fst   # Pulse leaf (C/OCaml extractable)
    └── Example.Majority.CLI.fst     # CLI entry point (--custard_main)
```

## Targets

| Flake attribute | What it produces | Runnable? |
|-----------------|------------------|-----------|
| `.#checked` | F\* verification (`.checked` files, 0-admit) | no |
| `.#ocaml` | OCaml findlib package (`example.cmxa`) | no |
| `.#native` | C11 shared/static lib (`libexample.{dylib,so,a}` + `example.h`) | no |
| `.#fsharp` | .NET library assembly (`Custard.dll`) | no |
| `.#cli` | standalone C executable (`bin/example-cli`) | **yes** |

`nix build` with no argument builds the default package (`native`).

Each backend maps to one extraction mode (the same set `codec` ships,
plus the CLI):

| Backend | Mechanism | Attribute | Output |
|---------|-----------|-----------|--------|
| F\* verify | `fstar.exe` (0-admit gate) | `.#checked` | `.checked` cache |
| OCaml | `--codegen OCaml` (pure) + `--custard_backend OCaml` (Pulse) | `.#ocaml` | findlib package |
| C library | `--codegen Custard --custard_backend C` | `.#native` | `libexample.*` + `.h` |
| F# library | `--codegen Custard --custard_backend FSharp` | `.#fsharp` | .NET assembly |
| C executable | Custard + `--custard_main Example.Majority.CLI.main` | `.#cli` | `bin/example-cli` |

The runtime backends exercise the Custard split exactly like `codec`:

- **OCaml** extracts the *pure spec* (`Example.Majority.Types` + `Example.Majority` via
  `--codegen OCaml`) *and* the Pulse leaf (`Example.Majority.Pulse` via
  `--custard_backend OCaml`) as one dune library.
- **native (C)** extracts the *Pulse leaf* (`Example.Majority.Pulse`, whose runtime
  body stays in `U32.t` + `Pulse.Lib.Array` + Pulse primitives) via Custard's
  `--custard_backend C`, rooted at `--custard_entry Example.Majority.Pulse.majority_vote`.
- **fsharp** extracts the same Pulse leaf via `--custard_backend FSharp` and
  builds it with `dotnet`.
- **cli** extracts `Example.Majority.CLI` the same way but roots
  `--custard_main Example.Majority.CLI.main`, so
  Custard emits a standalone `main` that calls the leaf.  (This is the one
  addition over `codec`, which has no CLI.)

> To keep the Pulse leaf extractable in *all three* backends, its result type
> is the F\*-defined variant [Example.Majority.Types.vote_result] (not the stdlib
> `option`/`tuple`, which are hand-written OCaml with no F# realization —
> Error 395).  See the Pulse-idiom note under "Extending".

## Build everything

```bash
nix build \
  .#checked .#ocaml .#native .#fsharp .#cli
```

## Run the CLI

```bash
nix run .#cli
echo $?   # -> 0
```

The generated C program links the `Example.Majority.Pulse.majority_vote` entry point
through `--custard_main Example.Majority.CLI.main`: Custard emits an `int main(void)` that
invokes `Example.Majority.CLI.main`, which runs the Boyer–Moore scan over a static vote table
and returns `0` when the expected majority element (`2`) is found.  It performs
no I/O; the exit status is the whole observable behaviour.

## Verify and extract individually

```bash
nix build .#checked   # F* verification only (no extraction)
nix build .#native    # extract the Pulse leaf to C11
nix build .#fsharp    # extract the Pulse leaf to F# -> .NET assembly
nix build .#cli       # extract Example.Majority.CLI to a standalone C program
```

`.#checked` emits a directory containing the `.checked` files for
`Example.Majority.Types`, `Example.Majority`, `Example.Majority.Pulse`, and `Example.Majority.CLI`, plus the
~337 pre-verified standard-library `.checked` cache they were verified against.

## Dev loop (`nix develop` + Makefile)

```bash
nix develop        # drops you into a shell with fstar.exe + OCaml LSP
make check         # verify all four modules (0-admit)
make clean
```

For fast interactive checking use the editor LSP (`fstar.exe --lsp`, see
below) — the LSP is a dev-loop aid, not a second build system.  The `nix build
.#checked` run (with a Z3 resource limit) is the authoritative gate.

The `nix develop` devShell exports one environment variable the `Makefile`
needs:

| Variable | Purpose |
|----------|---------|
| `FSTAR_CHECKED` | pre-verified stdlib `.checked` cache (from the `fstar` install) |

## LSP

`nix develop` provides `fstar.exe --lsp`.  Point your editor (VS Code / Emacs /
Vim) at it for hover docs, diagnostics, and completions.

> The editor LSP is a **dev-loop aid, not the verification gate** — the
> `nix build .#checked` run (with a Z3 resource limit) is the source of truth.

## Extending

- **Edit the logic** — modify the `Example.Majority.*` modules with your own verified
  functions, lemmas, and scan; the `Example.Majority.CLI` module is the thin CLI wrapper.
- **Rename the module** (optional) — rename `src/Example.Majority.Types.fst` etc. and
  their `module Example.Majority.Types` headers; the `Makefile`'s `SRC_MODS` and
  `default.nix`'s module lists carry the order.  The Custard entry symbols
  (`--custard_entry Example.Majority.Pulse.majority_vote`, `--custard_main Example.Majority.CLI.main`)
  follow the module names, so keep them in sync.
- **Add more modules** — list them (in dependency order, leaf modules first) in
  the `Makefile`'s `SRC_MODS`; a plain alphabetical `sort` would verify a
  dependent module before its leaf and trigger F\* Warning 247.
- **Ship a library instead of a CLI** — drop the `cli` derivation (and
  `--custard_main Example.Majority.CLI.main`); the `native` derivation (`--custard_entry`) is
  already the "library" shape, exposing a C entry point for a hand-written
  host.

### Renaming the project

`nix flake init -t .` copies the repository root.  To rename the example,
edit one `pname` binding in `default.nix` (it flows into the package names and
the library artifacts), and rename the four `src/*.fst` files + their
`module ...` headers.  The flake attributes are named by deliverable with no
project prefix (`checked`/`ocaml`/`native`/`fsharp`/`cli`), so they need no
renaming.

### The Pulse idiom (pinned here)

The `Example.Majority.Pulse` leaf followed the `codec` pattern and is worth
imitating closely:

- **Array**: `A.array U32.t` (`Pulse.Lib.Array`), view `A.pts_to b s`
  (`s : Seq.seq U32.t` erased).  Read `b.(j)`, with `j : SizeT.t`; convert
  `U32.t` offsets with `US.uint32_to_sizet`.
- **Loops**: the native Pulse `while` loop with an `exists*` invariant naming
  the per-iteration state (here, `candidate`/`counter`/`index`) and a `pure`
  fact tying it to the pure spec fold.  The loop is a `divergent` computation,
  so any `fn` containing one must be marked `divergent`.
- **Spec tie-in**: the loop invariant expresses the *suffix* scan
  (`bm_scan s0 (U32.v i) (U32.v n) vc (U32.v vcc)`) rather than re-deriving the
  prefix from scratch each iteration; the one-step unfold is a pure lemma
  (`lemma_bm_scan_step`) with an SMTPat, and the final candidate is tied to
  `find_candidate` by `lemma_find_candidate_slice`.
- **Extraction-safety**: the runtime body stays in `U32.t` + array + Pulse
  primitives; `Seq`/`nat`/`list` appear only in erased specs and `Lemma`s,
  never in extracted bodies (Error 368 otherwise).
- **F#-extractability**: the leaf's result type must be an F\*-defined variant
  (here [Example.Majority.Types.vote_result]), not the stdlib `option`/`tuple` — those
  are hand-written OCaml with no F# realization and Fail with Error 395 when
  reached from a rooted entry point.  `codec` does the same
  (`decode_result_c`, `DR_Inl`/`DR_Inr`).

## Notes

- The `fstar` input is pinned to
  [`dysinger/fstar`](https://github.com/dysinger/fstar) (the `v2026.09.20+lsp`
  branch — the LSP-enabled build of the first stable Custard release).

## License

[AGPL-3.0-or-later](LICENSE).
