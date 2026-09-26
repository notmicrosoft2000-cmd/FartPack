#!/usr/bin/env python3
"""checkmacro.py - enforce the macro-function rules this pack depends on.

#12 in BUGS-AND-FIXES.md records the lesson the hard way: a macro function with
even ONE line that references no `$(...)` is rejected by the datapack loader
with "No variables in macro", and the ENTIRE file silently stops existing. No
error at the call site, no error in game - the function just is not there, and
`checkrefs.py` reports it as uncallable or dangling rather than as a parse
error. That is a genuinely awful failure mode to debug at 2am, so it gets its
own checker rather than being left to the live-server parse lint.

A file is a macro function iff it contains `$(` anywhere. This pack's proven
style also prefixes every command line with `$` (see bar/ensure_bar), so that is
checked too - not because the game requires it on every line, but because the
files that work all do it, and a file that half-does it is a file that has
never been through a reload.

Usage: checkmacro.py <datapack-root>
"""
import pathlib
import re
import sys

MACRO_MARK = "$("
COMMENT = "#"
problems = []


def is_comment(line: str) -> bool:
    # Only a leading-# line is a comment. A mid-line # is a scoreboard name -
    # see the `core/toggle_off` and `#scan_c` history in the docs.
    return line.lstrip().startswith(COMMENT)


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    root = pathlib.Path(sys.argv[1])
    functions = sorted(root.rglob("*.mcfunction"))
    checked = 0

    for path in functions:
        text = path.read_text(encoding="utf-8")
        # A file is a macro function iff a COMMAND line contains `$(`, not merely
        # if the text does. bar/tick_gas_bar explains the macro rules in its
        # comments while being an ordinary function that calls macros, and
        # testing raw text flags every one of its lines.
        command_lines = [
            ln for ln in text.splitlines()
            if ln.strip() and not is_comment(ln)
        ]
        if not any(MACRO_MARK in ln for ln in command_lines):
            continue
        checked += 1
        rel = path.relative_to(root)
        for n, raw in enumerate(text.splitlines(), 1):
            line = raw.strip()
            if not line or is_comment(line):
                continue
            if MACRO_MARK not in line:
                problems.append(
                    f"{rel}:{n}: macro line with no $(var) - the loader drops "
                    f"the WHOLE file for this (#12)\n    {line[:100]}"
                )
            if not line.startswith("$"):
                problems.append(
                    f"{rel}:{n}: macro line does not start with '$' - every "
                    f"macro line in this pack does\n    {line[:100]}"
                )

    print(f"macro functions checked: {checked}")
    if problems:
        print(f"\nPROBLEMS: {len(problems)}")
        for p in problems:
            print(f"  {p}")
        return 1
    print("MACRO RULE: clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
