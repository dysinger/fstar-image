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

---

# NEXT SESSION — adversarial review findings (verbatim from the review agent)

An independent review agent followed the README end-to-end (local `nix flake
init -t`, build every target, `nix run`, dev loop, a real rename) and produced
this no-holds-barred feedback.  These are **open tasks for next session**.
Each is quoted from the review; the number is the reviewer's item id.

## Blockers (stop a user cold)

- [ ] **R1 — The template is not shipped / uncommitted.**  The whole
      Custard/Pulse roll-forward is uncommitted (`M README.md`, `M default.nix`,
      `M flake.nix`, `A src/Main.fst`, `M src/Majority.Pulse.fst`,
      `M src/Majority.Types.fst`, `M src/Majority.fst`; last commit `ca62cb3`),
      and the branch is `[ahead 2]` of `origin/master` (unpushed).  So the
      README's first command, `nix flake init -t github:dysinger/fstar-nix-flake-template`,
      serves a broken tree: `src/Main.fst` is missing at HEAD while
      `default.nix:218` + `flake.nix` wire it; committed `Majority.Pulse.fst`
      is an explicit `⚠️ TODO(next session)` STUB.
      **→ commit + push the roll-forward before any remote-init path works.**
- [ ] **R2 — Renaming fails first try (contradicts the renamability bar).**
      Following "Renaming the project" (one `pname` edit + rename 4 files +
      `module` headers) then `nix build .#checked` fails:
      `make: *** No rule to make target '.../checked/Majority.Types.fst.checked'`.
      The build hardcodes module names all over `default.nix` that the rename
      instructions never mention: `pure-modules` (lines 42–43), `for m in
      Majority.Types Majority Majority.Pulse` loops (184, 237), `for m in
      ... Main` (274), `src/Majority.Pulse.fst` (124, 132, 199), `src/Main.fst`
      (289), `--custard_entry Majority.Pulse.majority_vote` (130, 197, 250),
      `--custard_main Main.main` (287), and `Makefile` `SRC_MODS` (line 36).

## Correctness bugs

- [ ] **R3 — `pname` does NOT flow into artifacts (README falsehood).**
      `default.nix` hardcodes `libfstar-example.{dylib,so,a}` (202/204/206),
      `fstar-example.h` (207), `-o $out/fstar-example` (290), `bin/fstar-example-cli`
      (294) independent of `pname`.  Rename `pname`→`frost` and you still get
      `libfstar-example.*` and `fstar-example-cli`.
- [ ] **R4 — README claims `fstar-example.cmxa` (hyphen), artifact is
      `fstar_example.cmxa` (underscore)** from `ocaml-lib-name =
      replaceStrings ["-"] ["_"] pname`; and the findlib package name is
      `fstar-example-ocaml`, not `fstar-example`.
- [ ] **R5 — `default.nix` fsharp comment is self-contradictory.**  Lines
      215–216 say `majority_vote` "returns `option U32.t` (realizable in F#)";
      it actually returns `vote_result`, and the README correctly says
      `option`/`tuple` fail with Error 395.  Stale leftover asserting the
      opposite.
- [ ] **R6 — `welcomeText` omits `.#fsharp`** from its "Build everything" list
      (`.#checked .#ocaml .#native .#cli`), while README includes all five.
- [ ] **R7 — README `.checked` count off**: claims "~330", real output is
      333 stdlib + 4 project = 337.
- [ ] **R8 — `nix run .#cli` is a package-app fallback, not a declared app.**
      `flake.nix` declares only `apps.default`; there is no `apps.cli`.  Works
      by Nix 2.33 single-bin fallback, but the flake structure doesn't match
      the README's mental model.

## Warnings

- [ ] **R9 — `nix flake init` ships internal session docs to the consumer.**
      The fresh project contains `AGENTS.md` (21KB internal handoff: references
      `/Users/user/_/xeno/`, the fstar-codec story, "F# target is removed and
      stays removed" — but F# now exists) and `TASKS.md` (stale "currently
      KaRaMeL/Low\* era" — already rolled forward).  Both ship falsehoods and
      reference deleted files (`scripts/`, `src/main.c`, `src/Example.fst`,
      `src/Hello.fst`).
- [ ] **R10 — Example module names generate warnings every build.**  `Main.fst`
      collides with Pulse's `main`: Warning 274 "'pulse.' shadows module
      'main'" (in `.#native`, `.#cli`, `make check`).  `Majority.Types` emits
      Warning 274 "'majority.' shadows module 'pulse'" + Warning 285 "No modules
      in namespace MT" at `Majority.fst(39,5)`.
- [ ] **R11 — `.#ocaml` emits Warning 8 [partial-match] `VR_NoMajority`** from
      generated `Majority_Types.ml` projector `__proj__VR_Majority__item__cand`;
      plus a dune `Cache directories could not be created
      /homeless-shelter/.cache/dune` warning (unset HOME).
- [ ] **R12 — `.#cli` ships a duplicate binary** (`$out/fstar-example` from
      `cc -o` line 290 AND `$out/bin/fstar-example-cli` from the installPhase
      `cp`).
- [ ] **R13 — `fstar-example.h` include guard is `__CUSTARD_H`** (mismatched
      with filename); `Custard.h`/`Custard.c` ship alongside.
- [ ] **R14 — `n < 4294967295` is a spec-vs-impl fidelity gap, only lightly
      flagged.**  Pure `find_candidate`/`majority` work over arbitrary
      `nat`, but verified Pulse `majority_vote` only claims correctness for
      `U32.v n < 4294967295` (from `candidate_step_u32`'s `cnt + 1 < 2^32`).
      Honest but not surfaced in the README.

## Suggestions (polish / hygiene / UX)

- [ ] **R15 — Ship a clean `template/` subdir, not the repo root.**  Use
      `templates.default.path = ./template` containing ONLY a starter
      (flake.nix, default.nix, Makefile, `src/`, short `.gitignore`, short
      README) — not AGENTS.md/TASKS.md/LICENSE/README/flake.lock noise
      (AGENTS.md's own "Problems to solve" item #1 already flagged this).
- [ ] **R16 — Make `pname` the single source of truth** (or honestly document
      that renaming touches the module lists, custard entry/main symbols,
      `SRC_MODS`, AND the hardcoded `libfstar-example.*`/`fstar-example-cli`
      names in `default.nix`).
- [ ] **R17 — Rename `Main` → non-colliding (e.g. `CLI`/`Driver`)** to kill
      Warning 274; drop the `module MT = Majority.Types` alias or suppress
      Warning 285.
- [ ] **R18 — Commit + push the Custard roll-forward** so the `github:` init
      path works.
- [ ] **R19 — Fix the stale/false copy:** fsharp comment (`option U32.t`→
      `vote_result`), README `cmxa` hyphen/underscore, welcomeText `.#fsharp`
      omission, "~330" vs 333 count.
- [ ] **R20 — Verify x86_64-linux portability** (not exercisable on this
      aarch64-darwin host): `uname -s` branch for `.dylib`/`.so` is correct,
      but `libfstar-example.a`/`fstar-example.h`/`fstar-example-cli` names are
      unconditionally hyphen/hardcoded regardless of platform or `pname`;
      `ocaml-ng.ocamlPackages_5_3` + `dotnet-sdk_10` availability on
      x86_64-linux nixpkgs `c31cf09` is unverified.

> **Reviewer's summary (verbatim):** "A stranger following the README today
> would fail at step 1.  The `github:` init path serves a tree that's missing
> `src/Main.fst` and ships a stub `Majority.Pulse` (the whole Custard
> roll-forward is uncommitted *and* 2 commits unpushed).  Even using the local
> working tree, the renamability bar is broken: a rename per the README leaves
> ~15 hardcoded references in `default.nix` and the `Makefile`.  The build
> itself, when run unrenamed from the working tree, does succeed across all
> five targets and the CLI exits 0 — but it emits warnings from the example's
> own module naming, and several docs/artifacts are false or stale."
