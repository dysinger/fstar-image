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

- **"Add proper wasm back to Xeno"** — explicitly deferred to Xeno, not this
  template.
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
