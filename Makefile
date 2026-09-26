# hello — dev-loop build (F* verify + KaRaMeL extract + native link).
#
# A minimal subset of the canonical Xeno Makefile (see tls/Makefile), with the
# HACL*/TLS/vector domain content removed.
#
# Usage: nix develop, then `make check` / `make krml` / `make exe`.
#
# The FSTAR_KRML / KRML_HOME / KRM_LIB / KRM_INC env vars are exported by the
# flake devShell (see flake.nix shellHook).  Override them here if needed.

# ── Tools ──────────────────────────────────────────────────────────

CC ?= cc
CFLAGS = -O3 -fno-strict-aliasing
LDFLAGS =

OUT := out

FSTAR ?= fstar.exe
KRML  ?= krml

KRM_LIB   ?= $$KRM_LIB
KRM_INC   ?= $$KRM_INC
KRML_HOME ?= $$KRML_HOME

FSTAR_KRML    ?= $$FSTAR_KRML
FSTAR_CHECKED ?= $$FSTAR_CHECKED

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

.PHONY: check krml exe clean

check: $(addprefix $(OUT)/checked/,$(addsuffix .checked,$(subst .,_,$(SRC_MODS))))

$(OUT)/checked/%.checked: src/%.fst
	@mkdir -p $(OUT)/checked
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
# KaRaMeL emits C from the krmllib runtime + extracted modules but does NOT
# emit a C `main()`.  The checked-in src/main.c driver supplies it: it calls
# the extracted entry point Hello_main (the C form of Hello.main) and returns
# its exit code.

EXE_BIN := $(OUT)/hello

exe: $(EXE_BIN)

$(EXE_BIN): $(addprefix $(OUT)/krml/,$(addsuffix .krml,$(subst .,_,$(KRML_MODS)))) src/main.c
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
	  $(CC) $(CFLAGS) -std=c11 -I $(OUT)/krml $(KRM_INC) \
	    -c $$cfile -o $${cfile%.c}.o; \
	done
	$(CC) $(CFLAGS) $(LDFLAGS) -std=c11 -I $(OUT)/krml $(KRM_INC) \
	  -o $@ src/main.c \
	  $(OUT)/krml/*.o \
	  $(KRM_LIB_A)

clean:
	rm -rf $(OUT)
