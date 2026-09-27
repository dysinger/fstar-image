# F* dev-loop build (verify + KaRaMeL extract + native link).
#
# Usage: nix develop, then `make check` / `make krml` / `make exe`.
#
# The FSTAR_KRML / KRML_HOME / KRM_LIB / KRM_INC env vars are exported by the
# flake devShell (see flake.nix shellHook).  Override them here if needed.

# ── Tools ──────────────────────────────────────────────────────────

CC ?= cc
CFLAGS = -O3 -fno-strict-aliasing -ffunction-sections -fdata-sections
ifeq ($(shell uname),Darwin)
  LDFLAGS = -Wl,-dead_strip
else
  LDFLAGS = -Wl,--gc-sections
endif

OUT := out

FSTAR ?= fstar.exe
KRML  ?= krml

# These are supplied by the flake devShell's shellHook, which exports
# FSTAR_KRML / FSTAR_CHECKED / KRML_HOME / KRM_LIB / KRM_INC.  Make imports
# them from the environment as ordinary variables of the same name; passing
# e.g. `make exe KRM_LIB=/elsewhere` on the command line simply overrides the
# environment import.  No `?=` here (a same-name `?= $(VAR)` is a recursive
# self-reference when the env var is missing).  The guards below make a
# missing value fail loudly instead of silently mis-resolving.

ifeq ($(FSTAR_KRML),)
$(error FSTAR_KRML is not set; run `nix develop` (or export it yourself) before `make`)
endif
ifeq ($(KRML_HOME),)
$(error KRML_HOME is not set; run `nix develop` (or export it yourself) before `make`)
endif
ifeq ($(KRM_LIB),)
$(error KRM_LIB is not set; run `nix develop` (or export it yourself) before `make`)
endif

KRM_LIB_A ?= $(KRM_LIB)/dist/generic/libkrmllib.a

ULIB := $(shell $(FSTAR) --locate_lib 2>/dev/null || echo /none)/ulib
KRM_LIB_DIR := $(or $(KRML_HOME)/krmllib,$(KRM_LIB))

FSTAR_FLAGS = --no_default_includes \
  --include $(ULIB) \
  --include ./src \
  --include $(KRM_LIB_DIR) \
  --include $(KRM_LIB_DIR)/obj

# ── F* verification ───────────────────────────────────────────────

SRC_MODS := $(shell grep -h '^module ' src/*.fst 2>/dev/null | \
  grep -v '^module .* = ' | sed 's/^module //' | sort)
KRML_MODS := $(SRC_MODS)

# The source module name is auto-discovered from `module Foo` in src/*.fst,
# so a module rename (file + `module` header) needs NO Makefile edit.  MODULE
# is the (capitalized) module name; PNAME is the native executable basename.
# PNAME is OVERRIDEABLE (the flake's <pname>-exe derivation passes it as the
# project name); standalone `make exe` falls back to the lowercased module
# name.
MODULE := $(firstword $(SRC_MODS))
PNAME  ?= $(shell printf '%s' '$(MODULE)' | tr 'A-Z' 'a-z')

.PHONY: check krml exe clean

# F* names its cache files `<source>.checked` (e.g. src/Example.fst ->
# Example.fst.checked), so the stamp must use the .fst.checked suffix.  Using
# plain .checked here (as the original xeno/tls Makefile does) leaves `make
# check` permanently out-of-date and re-verifying every run; this diverges
# from xeno on purpose to make the advertised dev loop actually incremental.
check: $(addprefix $(OUT)/checked/,$(addsuffix .fst.checked,$(subst .,_,$(SRC_MODS))))

$(OUT)/checked/%.fst.checked: src/%.fst
	@mkdir -p $(OUT)/checked
	@test -n "$(FSTAR_CHECKED)" || { \
	  echo "ERROR: FSTAR_CHECKED is not set; run \`nix develop\` (or export it yourself) before \`make check\`" >&2; \
	  exit 1; }
	# Seed the pre-verified stdlib `.checked` cache (FSTAR_CHECKED, exported by
	# the devShell) so fstar can write our module's .checked file; without the
	# dependency .checked files, fstar emits Warning 247 and never writes the
	# stamp, leaving `make check` permanently out-of-date.
	@cp $(FSTAR_CHECKED)/*.checked $(OUT)/checked/ 2>/dev/null || true
	@echo "=== $* ==="
	$(FSTAR) $(FSTAR_FLAGS) \
	  --z3rlimit 80 \
	  --cache_checked_modules --cache_dir $(OUT)/checked \
	  --odir $(OUT)/checked $<

# ── KaRaMeL extraction ─────────────────────────────────────────────

krml: check $(addprefix $(OUT)/krml/,$(addsuffix .krml,$(subst .,_,$(KRML_MODS))))

define KRML_RULE
$(OUT)/krml/$(subst .,_,$(1)).krml: src/$(1).fst
	@mkdir -p $(OUT)/krml
	$(FSTAR) $(FSTAR_FLAGS) \
	  --cache_checked_modules --cache_dir $(OUT)/checked \
	  --odir $(OUT)/krml --codegen krml \
	  --extract_module $(1) $$<
endef
$(foreach mod,$(KRML_MODS),$(eval $(call KRML_RULE,$(mod))))

# ── Native executable ──────────────────────────────────────────────
#
# KaRaMeL emits C from the krmllib runtime + extracted module but does NOT
# emit a C `main()`.  The driver supplies it: a tiny generated main.c that
# calls the extracted entry point <Module>_main and returns its exit code.
# It is regenerated from the KaRaMeL-emitted <Module>.h header (which declares
# the exact `<Module>_main` prototype), so a rename needs no hand-edited C
# symbol.

EXE_BIN := $(OUT)/$(PNAME)

# Generated driver, derived from the header.  KaRaMeL's C mangling is
# deterministic: `Module.main` -> C symbol `Module_main` (see the
# `int32_t Example_main(void);` prototype in the emitted <Module>.h).
$(OUT)/main.c: $(addprefix $(OUT)/krml/,$(addsuffix .krml,$(subst .,_,$(KRML_MODS))))
	@mkdir -p $(OUT)
	@printf '%s\n' \
	  "/* Generated from the KaRaMeL header. Entry symbol: $(MODULE)_main */" \
	  "#include \"$(MODULE).h\"" \
	  "" \
	  "int main(void) {" \
	  "  return (int)$(MODULE)_main();" \
	  "}" > $@

exe: $(EXE_BIN)

$(EXE_BIN): $(addprefix $(OUT)/krml/,$(addsuffix .krml,$(subst .,_,$(KRML_MODS)))) $(OUT)/main.c
	@echo "=== EXE ($(CC)) ==="
	@ok=1; \
	  for d in "$(FSTAR_KRML)/krml" "$(OUT)/krml"; do \
	    if ! ls "$$d"/*.krml >/dev/null 2>&1; then \
	      echo "ERROR: no .krml files in $$d"; ok=0; \
	    fi; \
	  done; \
	  [ "$$ok" = 1 ] || exit 1
	$(KRML) -skip-compilation -ccflavor clang \
	  -tmpdir $(OUT)/krml \
	  $(FSTAR_KRML)/krml/*.krml \
	  $(addprefix $(OUT)/krml/,$(addsuffix .krml,$(subst .,_,$(KRML_MODS))))
	@rm -f $(OUT)/krml/*.o
	@for cfile in $(OUT)/krml/*.c; do \
	  $(CC) $(CFLAGS) -std=c11 -I$(OUT)/krml $(KRM_INC) \
	    -c $$cfile -o $${cfile%.c}.o; \
	done
	$(CC) $(CFLAGS) $(LDFLAGS) -std=c11 -I$(OUT)/krml $(KRM_INC) \
	  -o $@ $(OUT)/main.c \
	  $(OUT)/krml/*.o \
	  $(KRM_LIB_A)

clean:
	rm -rf $(OUT)
