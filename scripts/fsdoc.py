#!/usr/bin/env python3
"""Extract F* fsdoc comments (``(** ... *)``) into a single Markdown file.

F* does not ship a standalone fsdoc generator.  This minimal script walks the
source tree, finds every ``(** ... *)`` doc comment, and emits a Markdown
outline of documented symbols.  It is intentionally simple (a starting point),
not a full ocamldoc-grade tool.
"""
import re
import sys
from pathlib import Path

DOC_RE = re.compile(r"\(\*\*(.*?)\*\)", re.DOTALL)


def extract(path: Path) -> list[tuple[str, str]]:
    """Return (title, body) pairs for each doc comment in *path*."""
    text = path.read_text(encoding="utf-8")
    out = []
    for m in DOC_RE.finditer(text):
        raw = m.group(1).strip()
        # Drop leading `*` on continuation lines.
        lines = [ln.lstrip(" *") for ln in raw.splitlines()]
        body = "\n".join(ln.strip() for ln in lines).strip()
        if not body:
            continue
        # Use the first non-@param/@returns line as the title.
        title = body.splitlines()[0] if body else ""
        out.append((title, body))
    return out


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"usage: {argv[0]} <output.md>", file=sys.stderr)
        return 2
    out_path = Path(argv[1])
    parts: list[str] = ["# Documentation", ""]
    for src in sorted(Path("src").glob("*.fst")):
        docs = extract(src)
        if not docs:
            continue
        parts.append(f"## `{src}`")
        parts.append("")
        for title, body in docs:
            parts.append(f"### {title}")
            parts.append("")
            parts.append(body)
            parts.append("")
    out_path.write_text("\n".join(parts), encoding="utf-8")
    print(f"wrote {len(parts)} lines to {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
