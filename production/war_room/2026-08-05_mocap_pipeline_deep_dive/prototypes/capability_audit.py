"""Read-only audit: does every declared setting / advertised capability have a consumer?

Diagnostic only. Writes nothing, changes nothing. This is the prototype of the
"capability contract test" proposed in the 2026-08-05 pipeline decree.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(r"C:\Users\caleb\mocap-toolkit")
ADDON = ROOT / "addon"
PKG = ROOT / "mocap_toolkit"
TESTS = ROOT / "tests"

PROP_RE = re.compile(r"^\s{4}(\w+):\s*(?:Bool|Collection|Enum|Float|Int|Pointer|String)Property\(", re.M)


def settings_props() -> list[str]:
    src = (ADDON / "props.py").read_text(encoding="utf-8")
    # only the MOCAP_Settings block
    start = src.index("class MOCAP_Settings")
    return PROP_RE.findall(src[start:])


def corpus(exclude: set[str]) -> list[tuple[Path, str]]:
    out = []
    for base in (ADDON, PKG, TESTS, ROOT / "tools"):
        if not base.exists():
            continue
        for p in base.rglob("*.py"):
            if p.name in exclude or "__pycache__" in p.parts:
                continue
            out.append((p, p.read_text(encoding="utf-8", errors="replace")))
    return out


def main() -> int:
    props = settings_props()
    # A declaration and a UI row are not consumers.
    body = corpus(exclude={"props.py", "ui.py"})
    ui_only = corpus(exclude={"props.py"})

    unconsumed, ui_row_only = [], []
    for name in props:
        pat = re.compile(rf"\b{re.escape(name)}\b")
        hits = [p for p, s in body if pat.search(s)]
        if hits:
            continue
        if any(pat.search(s) for p, s in ui_only if p.name == "ui.py"):
            ui_row_only.append(name)
        else:
            unconsumed.append(name)

    print(f"MOCAP_Settings properties declared : {len(props)}")
    print(f"  with a real consumer             : {len(props) - len(unconsumed) - len(ui_row_only)}")
    print(f"  DRAWN IN UI, CONSUMED NOWHERE    : {len(ui_row_only)}")
    for n in ui_row_only:
        print(f"      !! {n}")
    print(f"  DECLARED, NEVER REFERENCED       : {len(unconsumed)}")
    for n in unconsumed:
        print(f"      !! {n}")

    # backend capability strings
    print()
    caps = set()
    for p, s in corpus(exclude=set()):
        if "backends" in p.parts or "backend" in p.name:
            caps |= set(re.findall(r"[\"'](feature\.[\w.]+)[\"']", s))
            caps |= set(re.findall(r"[\"'](output\.[\w.]+)[\"']", s))
    print(f"advertised capability strings found : {len(caps)}")
    for c in sorted(caps):
        n = sum(1 for p, s in corpus(exclude=set()) if c in s)
        flag = "  <-- ADVERTISED ONLY" if n <= 1 else ""
        print(f"    {c:28s} referenced in {n} file(s){flag}")

    return 1 if (unconsumed or ui_row_only) else 0


if __name__ == "__main__":
    sys.exit(main())
