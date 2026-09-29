# TASKS — fstar-nix-flake-template roll-forward to F\* v2026.09.20

The template is currently **KaRaMeL/Low\* era** (F\* `v2025.10.06+lsp`, the
`karamel` input, `krml`/`rust`/`wasm` targets, `open FStar.HyperStack.ST`,
`St` effect).  It must be rolled forward to **F\* v2026.09.20+lsp**, which
*deleted* the KaRaMeL/Low\* stdlib and shipped **Custard + Pulse**.  Then the
single `Example.fst` is replaced with a realistic 4-module library + CLI
pattern (Boyer–Moore majority vote on a Pulse array — the official Pulse
extraction tutorial problem).

**MANDATE:** wrap every `fstar.exe`/`nix build`/`make` in a hard timeout guard
(≤ 10 min fstar, ≤ 15 min nix).  A stuck process (0% CPU stopped, or 100% CPU
spin) is a hang — kill + diagnose, don't wait.  `nix build` is the gate, not
the LSP.

> ### Status snapshot (buttoned up, end of THIS session)
>
> **DONE:** Phase 1 (Karamel removal + roll-forward, commit `57c61d8`) and the
> **two pure modules** `Majority.Types` + `Majority` (0-admit, verified GREEN).
>
> **Architecture note (the three-backend split — same as fstar-codec):**
> `Tot` is FINE everywhere and is the xeno convention (1096 uses, incl. the
> codec spec).  It does NOT block extraction.  What blocks C/F# is *pure types*
> (`Seq`/`list`/`nat`/`int`) in runtime bodies:
> - `Majority.Types` + `Majority` (pure, `Seq`/`list`/`nat`) → **OCaml** only,
>   via `--codegen OCaml`.
> - `Majority.Pulse` (`fn`, `A.array U32.t`) → **C + OCaml + F#** via Custard.
>   Its *spec* may use `Seq`/`find_candidate` (erased in the `ensures`), but its
>   *runtime body* must stay in `U32.t` + `A.array` + Pulse primitives.
>
> **NEXT SESSION (in order):**
> 1. **T2.3** — implement the real `Majority.Pulse` loop (currently a stub).
>    Use the fstar-codec technique: `fn` + `A.pts_to b s0` view, `Tot (option
>    elem)` with a *bare-variable* `decreases` (`decreases ls`), NOT
>    `decreases (n - i)`.  (The xeno codebase does use arithmetic `decreases
>    m + 1 - k`, so if that form errors, it's the v2026.09.20 parse — prefer
>    the bare-variable / list-subterm form from fstar-codec.)
> 2. **T2.4 + Phase 3** — write `Main` (CLI) and confirm the `cli` derivation
>    (already wired in `default.nix`/`flake.nix`) extracts the executable.
> 3. **Phase 4** — README/AGENTS rewrite, full `nix build .#checked .#ocaml
>    .#native .#cli` + `nix run .#fstar-example-cli`, `nix flake init -t .`
>    smoke test.

## Phase 1 — Roll the toolchain forward (delete KaRaMeL) — ✅ DONE

- [x] **T1.1 — Drop the `karamel` input + all its artifacts.**  Remove from
      `flake.nix`: the `karamel` flake input, the `karamel` / `fstar-krml`
      overlay derivations, `KRM_LIB`/`KRM_INC`/`KRML_HOME`/`FSTAR_KRML` env
      plumbing, the `gtime` shim.  Keep only `fstar` + `fstar-checked`.
- [x] **T1.2 — Pin `fstar` to `github:dysinger/fstar/v2026.09.20+lsp`.**
      Add the `buildPhase`/`installPhase` overrides from `fstar-codec`
      (`--z3rlimit 20 --retry 3` bootstrap; the no-op `karamel/Makefile` +
      `FSTAR_USE_KRML_EXE=1` stub); `ocamlPackages = ocaml-ng.ocamlPackages_5_3`.
- [x] **T1.3 — Delete the dead backends.**  Remove `krml`/`rust`/`wasm`/
      `native`(KaRaMeL C)/`exe`(KaRaMeL driver) derivations from `default.nix`
      and their Makefile targets.  The new backends are `checked` +
      `ocaml`(pure spec) + `native`(Custard C of the Pulse leaf) + `cli`
      (a packaged command-line executable) + `fsharp` (optional, parallel to
      fstar-codec).
- [x] **T1.4 — Rewrite the Makefile** for the Custard/Pulse era: no `KRML_*`
      guards, `--z3rlimit 120`, the four `pulse/*` `--include` paths, and an
      explicit `SRC_MODS` (not the alphabetical glob — leaf-first order).

## Phase 2 — Replace `Example.fst` with the 4-module Boyer–Moore example

The new shape (modeled on fstar-codec's Types/Codec/Pulse split):

- [x] **T2.1 — `Majority.Types`** (pure spec + types) — ✅ DONE, 0-admit.
  `elem`/`count`/`majority` + `lemma_count_empty`, verified GREEN this session.
- [x] **T2.2 — `Majority`** (pure algorithm) — ✅ DONE (mostly), 0-admit.
  `candidate_step`/`find_candidate`/`verify` verified GREEN.  **NOTE:** the
  deep "candidate is the only possible majority" invariant is *stated in
  prose* + exercised on vectors, NOT proven symbolically (the pairing proof
  is the interesting exercise, deliberately left to a reader).
- [ ] **T2.3 — `Majority.Pulse`** (`#lang-pulse`) — ⚠️ STUB, next session.
  The file is committed but its `majority_vote` body does NOT scan; it needs
  a real Pulse `while`/`for` loop with an invariant tying `cand'` to
  `Majority.find_candidate` over the prefix.  (The `decreases`/`Tot` idiom
  that works is the fstar-codec form: `: Tot (option elem) (decreases ls)`
  with a bare variable, NOT `decreases (n - i)` — that syntax is rejected
  in v2026.09.20.)
- [ ] **T2.4 — `Main`** (CLI entry point) — not started, next session.

## Phase 3 — Package the CLI executable

- [ ] **T3.1 — Add a `cli` derivation** in `default.nix`: extract `Main`
      (Custard `--custard_backend C`, `--custard_main Main.main`) → compile
      to a native binary → `installPhase` puts it in `$out/bin/<pname>`.
- [ ] **T3.2 — Wire it through flake** `packages.<pname>-cli` + an `apps`
      entry so `nix run .#<pname>-cli` works.
- [ ] **T3.3 — The CLI links the library** (calls `Majority.Pulse`'s
      `majority_vote`), proving the library↔CLI split extracts cleanly.

## Phase 4 — Finish + verify

- [ ] **T4.1 — Rewrite README.md** for the new 4-module + CLI story (drop all
      KaRaMeL/wasm/rust prose; document `checked`/`ocaml`/`native`/`cli`).
- [ ] **T4.2 — Rewrite AGENTS.md "Current focus"** + the DoD to reflect the
      roll-forward (remove the KaRaMeL-era narrative).
- [ ] **T4.3 — Full build gate.**  `nix build .#checked .#ocaml .#native .#cli`
      (and `.#fsharp` if kept) all GREEN; `nix run .#cli` exits 0; `make check`
      in `nix develop` GREEN.  `grep -rn 'HyperStack\|LowStar\|karamel\|krml\|Stack' src/` empty.
- [ ] **T4.4 — `nix flake init -t .` smoke test** — init into a fresh dir,
      rename, and confirm it still builds (the renamability bar).

## Definition of done

- Template builds + runs against F\* v2026.09.20+lsp with **no** KaRaMeL/Low\*.
- `Example.fst` replaced by Types/facade/Pulse + CLI Boyer–Moore example.
- `nix build` of all targets GREEN; `nix run` of the CLI works; 0-admit.
- `nix flake init -t .` → rename → build works first try.
