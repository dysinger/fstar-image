# F* Project Template

Copyright 2026 Department of Code LLC.
SPDX-License-Identifier: AGPL-3.0-or-later

A minimal, self-contained [F*](https://www.fstar-lang.org/) project that
demonstrates the full verified-to-runnable workflow: a four-module
Boyer–Moore majority-vote library (pure spec + pure algorithm + Pulse leaf +
CLI) is checked, extracted via **Custard**, and compiled to **C** (a native
library and a standalone executable) and **OCaml** — all driven by
[Nix flakes](https://nixos.wiki/wiki/Flakes).

This is the post-KaRaMeL era of F\* (`v2026.09.20+lsp`): the Low\*/KaRaMeL
stdlib was removed upstream and replaced by **Pulse** + **Custard**.  There is
no `krml`, no `rust`/`wasm` backend, and no `Stack`/`HyperStack` effect.

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
four layers, mirroring the `fstar-codec` Types / Codec / Pulse split:

| Module | Layer | Effect | Purpose |
|--------|-------|--------|---------|
| `Majority.Types` | pure spec | `Tot` | `elem`/`count`/`majority` + `lemma_count_empty` |
| `Majority` | pure algorithm | `Tot` | `candidate_step`/`bm_scan`/`find_candidate` + lemmas |
| `Majority.Pulse` | Pulse leaf | `stt` (`fn`) | `majority_vote` over a mutable array, C/OCaml extractable |
| `Main` | CLI entry | `stt` (`fn`) | allocates a static vote table, runs the leaf, returns exit status |

- `Majority.Types` defines the mathematical notion `majority x s` (an element
  occurring strictly more than half the time) and proves `lemma_count_empty`.
- `Majority` implements `find_candidate` — the Boyer–Moore candidate-selection
  pass — and `verify` (the verification pass).  It also carries the *proven*
  bridge lemmas the Pulse leaf relies on: `candidate_step_u32` (the extractable
  `U32.t`-counter form of the one-step transition), `bm_scan` (the fold by
  index), `lemma_bm_scan_step`, and `lemma_find_candidate_slice`.
- `Majority.Pulse` re-implements the same scan over a
  `Pulse.Lib.Array.array U32.t` with a `while` loop, and its post-condition ties
  the surviving candidate back to `Majority.find_candidate` — the spec↔impl
  correspondence is discharged by the pure lemmas.
- `Main` binds a *static* vote table (`Pulse.Lib.GlobalArray`, a compile-time
  constant) and calls `majority_vote`; Custard compiles it with
  `--custard_main Main.main` into a standalone C program whose exit status
  reports whether the scan found the expected winner.

Everything verifies with **zero admits** — every lemma discharges through SMT
or a hand-written proof in `Majority.fst`.

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
    ├── Majority.Types.fst     # pure spec
    ├── Majority.fst           # pure algorithm + lemmas
    ├── Majority.Pulse.fst     # Pulse leaf (C/OCaml extractable)
    └── Main.fst               # CLI entry point (--custard_main)
```

## Targets

| Flake attribute | What it produces | Runnable? |
|-----------------|------------------|-----------|
| `.#checked` | F\* verification (`.checked` files, 0-admit) | no |
| `.#ocaml` | OCaml findlib package (`fstar-example.cmxa`) | no |
| `.#native` | C11 shared/static lib (`libfstar-example.{dylib,so,a}` + `.h`) | no |
| `.#fsharp` | .NET library assembly (`Custard.dll`) | no |
| `.#cli` | standalone C executable (`bin/fstar-example-cli`) | **yes** |

`nix build` with no argument builds the default package (`native`).

Each backend maps to one extraction mode (the same set `fstar-codec` ships,
plus the CLI):

| Backend | Mechanism | Attribute | Output |
|---------|-----------|-----------|--------|
| F\* verify | `fstar.exe` (0-admit gate) | `.#checked` | `.checked` cache |
| OCaml | `--codegen OCaml` (pure) + `--custard_backend OCaml` (Pulse) | `.#ocaml` | findlib package |
| C library | `--codegen Custard --custard_backend C` | `.#native` | `libfstar-example.*` + `.h` |
| F# library | `--codegen Custard --custard_backend FSharp` | `.#fsharp` | .NET assembly |
| C executable | Custard + `--custard_main Main.main` | `.#cli` | `bin/fstar-example-cli` |

The runtime backends exercise the Custard split exactly like `fstar-codec`:

- **OCaml** extracts the *pure spec* (`Majority.Types` + `Majority` via
  `--codegen OCaml`) *and* the Pulse leaf (`Majority.Pulse` via
  `--custard_backend OCaml`) as one dune library.
- **native (C)** extracts the *Pulse leaf* (`Majority.Pulse`, whose runtime
  body stays in `U32.t` + `Pulse.Lib.Array` + Pulse primitives) via Custard's
  `--custard_backend C`, rooted at `--custard_entry Majority.Pulse.majority_vote`.
- **fsharp** extracts the same Pulse leaf via `--custard_backend FSharp` and
  builds it with `dotnet`.
- **cli** extracts `Main` the same way but roots `--custard_main Main.main`, so
  Custard emits a standalone `main` that calls the leaf.  (This is the one
  addition over `fstar-codec`, which has no CLI.)

> To keep the Pulse leaf extractable in *all three* backends, its result type
> is the F\*-defined variant [Majority.Types.vote_result] (not the stdlib
> `option`/`tuple`, which are hand-written OCaml with no F# realization —
> Error 395).  See the Pulse-idiom note under "Extending".

### Dropped backends

Custard's `--custard_backend` enum is `["OCaml"; "FSharp"; "KrmlC";
"KrmlRust"; "C"]`.  The two `Krml*` entries route through the removed
KaRaMeL toolchain and are dead upstream (`KrmlRust` produces 431 rustc errors;
`KrmlC` is superseded by the direct `C` backend) — dropped, matching
`fstar-codec`.  There is no wasm backend in the new F\*.

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

The generated C program links the `Majority.Pulse.majority_vote` entry point
through `--custard_main Main.main`: Custard emits an `int main(void)` that
invokes `Main.main`, which runs the Boyer–Moore scan over a static vote table
and returns `0` when the expected majority element (`2`) is found.  It performs
no I/O; the exit status is the whole observable behaviour.

## Verify and extract individually

```bash
nix build .#checked   # F* verification only (no extraction)
nix build .#native    # extract the Pulse leaf to C11
nix build .#fsharp    # extract the Pulse leaf to F# -> .NET assembly
nix build .#cli       # extract Main to a standalone C program
```

`.#checked` emits a directory containing the `.checked` files for
`Majority.Types`, `Majority`, `Majority.Pulse`, and `Main`, plus the
~330 pre-verified standard-library `.checked` cache they were verified against.

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

- **Edit the logic** — modify the `Majority.*` modules with your own verified
  functions, lemmas, and scan; the `Main` module is the thin CLI wrapper.
- **Rename the module** (optional) — rename `src/Majority.Types.fst` etc. and
  their `module Majority.Types` headers; the `Makefile`'s `SRC_MODS` and
  `default.nix`'s module lists carry the order.  The Custard entry symbols
  (`--custard_entry Majority.Pulse.majority_vote`, `--custard_main Main.main`)
  follow the module names, so keep them in sync.
- **Add more modules** — list them (in dependency order, leaf modules first) in
  the `Makefile`'s `SRC_MODS`; a plain alphabetical `sort` would verify a
  dependent module before its leaf and trigger F\* Warning 247.
- **Ship a library instead of a CLI** — drop the `cli` derivation (and
  `--custard_main Main.main`); the `native` derivation (`--custard_entry`) is
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

The `Majority.Pulse` leaf followed the `fstar-codec` pattern and is worth
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
  (here [Majority.Types.vote_result]), not the stdlib `option`/`tuple` — those
  are hand-written OCaml with no F# realization and Fail with Error 395 when
  reached from a rooted entry point.  `fstar-codec` does the same
  (`decode_result_c`, `DR_Inl`/`DR_Inr`).

## Notes

- The `fstar` input is pinned to
  [`dysinger/fstar`](https://github.com/dysinger/fstar) (the `v2026.09.20+lsp`
  branch — the LSP-enabled build of the first stable Custard release).  The
  KaRaMeL install step is neutralized in the overlay (no `krml` is consumed),
  exactly as in `fstar-codec`.

## License

[AGPL-3.0-or-later](LICENSE).
