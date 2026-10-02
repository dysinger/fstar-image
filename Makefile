# Copyright 2026 Department of Code LLC.
# SPDX-License-Identifier: AGPL-3.0-or-later

# F* dev-loop build (verify).
#
# Usage: nix develop, then `make check`.
#
# FSTAR_CHECKED is exported by the flake devShell (see flake.nix shellHook).
# Override it here if needed.

# ── Tools ──────────────────────────────────────────────────────────

OUT ?= out
FSTAR ?= fstar.exe

ULIB := $(shell $(FSTAR) --locate_lib 2>/dev/null || echo /none)/ulib

# Pulse ships in the install under $(locate_lib)/pulse (sources under
# pulse/{common,pulse/lib}, `.checked` under pulse/{common.checked,
# pulse.checked}).  Example.Majority.Pulse needs these, since FSTAR_FLAGS uses
# --no_default_includes.
FLIB := $(shell $(FSTAR) --locate_lib 2>/dev/null || echo /none)
PULSE_DIRS := $(FLIB)/pulse/common\
  $(FLIB)/pulse/common.checked\
  $(FLIB)/pulse/pulse/lib\
  $(FLIB)/pulse/pulse.checked

FSTAR_FLAGS = --no_default_includes \
  --include $(ULIB) \
  $(foreach d,$(PULSE_DIRS),--include $(d)) \
  --include ./src

# ── F* verification ───────────────────────────────────────────────

# Source modules in DEPENDENCY ORDER (leaf modules first).
SRC_MODS := Example.Majority.Types Example.Majority Example.Majority.Pulse Example.Majority.CLI
TST_MODS :=

# Pulse-only modules skip re-verification (they ship pre-verified in the F*
# install); Example.Majority.Pulse opens Pulse.Lib.* which would otherwise time out
# re-verifying the whole Pulse stdlib on every `make check`.
ALREADY_CACHED := Prims,FStar,Pulse.Nolib,Pulse.Lib,Pulse.Class,PulseCore

.PHONY: check clean

check: $(addprefix $(OUT)/checked/,$(addsuffix .fst.checked,$(SRC_MODS))) \
       $(addprefix $(OUT)/checked/,$(addsuffix .fst.checked,$(TST_MODS)))

$(OUT)/checked/%.fst.checked: src/%.fst
	@mkdir -p $(OUT)/checked
	@test -n "$(FSTAR_CHECKED)" || { \
	  echo "ERROR: FSTAR_CHECKED is not set; run \`nix develop\` (or export it yourself) before \`make check\`" >&2; \
	  exit 1; }
	@cp $(FSTAR_CHECKED)/*.checked $(OUT)/checked/ 2>/dev/null || true
	@echo "=== $* ==="
	$(FSTAR) $(FSTAR_FLAGS) \
	  --z3rlimit 120 \
	  --already_cached $(ALREADY_CACHED) \
	  --cache_checked_modules --cache_dir $(OUT)/checked \
	  --odir $(OUT)/checked $<

# ── Clean ─────────────────────────────────────────────────────────

clean:
	rm -rf $(OUT) cache result result-*
