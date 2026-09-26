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

## Current state (resolved)

The template is a **working, reviewed flake template** that builds all five
targets and runs on aarch64-darwin. It is a git repo now (not "NOT a git repo"
as an earlier handoff claimed). Recent work (see git log) fixed reviewer
findings from a brutal pass:

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

## Targets (all verified this session)

| Flake attribute | Result |
|-----------------|--------|
| `.#hello-checked` | F* verification + stdlib `.checked` cache |
| `.#hello-krml` | KaRaMeL extraction (`Hello.krml`) |
| `.#hello-exe` | native exe `bin/hello` (exit 0) |
| `.#hello-wasm` | `Hello.wasm` + JS loader (`node main.js` exit 0) |
| `.#hello-fsdoc` | fsdoc → Markdown |
| `templates.default` | nix flake init -t |

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
   the entry point exports as `main` (what `main.js` searches for). Without it
the export is `<Module>_main` and the loader says "no main in current scope".
   Thread the prefix per-module, not a hardcoded string.
3. **Case-exact `.wasm` guard** — always compare the emitted basename against
   the expected `<Module>.wasm` (case-sensitive) and `exit 1` with the on-disk
   list on mismatch. The JS loader (`shell.js` `my_modules` + `main.js`'s
   `<Module>.wasm` read) is case+CWD sensitive.
4. **Extract the RIGHT modules.** Xeno's extraction filter is `.Low`
   (`grep '\.Low'` in each `default.nix` + the inline `tls-krml`/`xeno-pg-krml`
   derivations). The wasm target must consume those same `.krml` outputs, never
   re-extract from source.

### Task list (in dependency order)

- [ ] **T1 — Pick the pilot package.** Use `codec` (smallest: `Data.Codec`,
      `Data.Codec.Types`, `Data.Codec.Low`) — its `codec-krml` output has one
      extractable `Data.Codec.Low.krml`. Confirm `krml -backend wasm -no-prefix
      Data.Codec.Low codec-krml/Data.Codec.Low.krml` emits
      `Data.Codec.Low.wasm` + loader under a scratch dir.
- [ ] **T2 — Add a `codec-wasm` derivation** to `codec/default.nix` (or the
      top flake) mirroring `hello-wasm`: `buildInputs = [ fstar karamel
      codec-krml ]`, `-tmpdir wasm-out -backend wasm -no-prefix Data.Codec.Low
      ${codec-krml}/Data.Codec.Low.krml`, case-exact guard, `installPhase` ships
      the full loader bundle (`.wasm`, `.wast`, `main.js`, `loader.js`,
      `shell.js`, `browser.js`, `main.html`, `layouts.json`, no-ext `README`).
- [ ] **T3 — Wire it into the flake `packages`** (and `legacyPackages`) as
      `codec-wasm`, retaining the existing `codec-checked`/`codec-krml` targets
      untouched. Do NOT make it `default` yet.
- [ ] **T4 — Verify end to end**: `nix build .#codec-wasm`, confirm
      `result/*.wasm` magic `\0asm`, then `cd result && node main.js` exits 0
      (or run `WebAssembly.validate` via `nix shell nixpkgs#nodejs_22`).
- [ ] **T5 — Generalize the recipe** once T4 is green: factor the wasm
      derivation into a small helper (e.g. a `mk-krml-wasm` function taking
      `{ src; krml-drv; module; }`) so the remaining packages (`tls`,
      `xeno-pg`, …) can reuse it instead of copy-pasting the `hello-wasm`
      body N times.
- [ ] **T6 — Roll out to the packages that actually need a `main` export.**
      Not every `-krml` package has a runnable `main` (many are libraries);
      only emit `-wasm` for packages with a `*.Low.main` (or a demo driver).
      List them first; do not blindly add wasm to all ~20 packages.
- [ ] **T7 — Update Xeno's README/AGENTS** to document the wasm targets, the
      `-no-prefix` requirement, the case-sensitivity trap, and the
      `cd result && node main.js` invocation.

### Open questions to resolve during T1 (do not guess)

- Does `Data.Codec.Low` have a `main` (or only pure codecs)? If no `main`, wasm
  still emits the library exports (add/etc.) but `node main.js` will report
  "no main in current scope" — decide whether Xeno's wasm target is
  library-export or runnable-entry. The template is runnable-entry (`Hello.main`).
- For multi-module packages, does a *single* `krml -backend wasm` call accept
  the concatenated `.krml` set (like the native link's krmllib glob), or must
  each module be compiled separately and bundled? (Template does one module;
  Xeno's codec-krml has one `.Low`, but tls has many.)
