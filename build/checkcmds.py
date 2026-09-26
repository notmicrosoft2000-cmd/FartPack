#!/usr/bin/env python3
"""checkcmds.py - static arity check for scoreboard commands.

#30: v26 shipped with five broken lines in player/apply_gas and three more
across admin/recalc and admin/cap, all the same mistake:

    scoreboard players operation @s fart.pressure += #famt

`scoreboard players operation` takes FIVE fields - target, target objective,
operator, source, source objective. I wrote four, dropping the source
objective, and the game rejects it with "Unknown or incomplete command" whose
caret points at the END of the line, so the message names neither the missing
field nor the line. Both files failed to load, so the gas bar silently stopped
filling for every player, and the only evidence anywhere was one ERROR line in
the log.

Worse, the live parse lint reported `PARSE FAILURES: 0`. It was not wrong about
what it checked - it was reading a stale tarball (see the note in lint.sh), so
it had validated v25. A gate that silently checks the wrong artifact is worse
than no gate, because it is trusted.

This checker is static and needs no server, so it cannot be stale. It does not
attempt to be a general datapack parser - it checks arity for the scoreboard
subcommands whose field count is fixed, which is where the demonstrated failure
was.

Handles the three things that make a line awkward to count: a leading `$` macro
marker, an `execute ... run` wrapper, and `$(arg0)`-style tokens (each of which
is exactly one field, not zero).

Usage: checkcmds.py <datapack-root>
"""
import pathlib
import re
import sys

# subcommand -> exact field count AFTER the subcommand
ARITY = {
    "operation": 5,
    "set": 3,
    "add": 3,
    "remove": 3,
    "reset": 2,
    "enable": 2,
    "disable": 2,
    "get": 2,
    "list": 0,
}

SCOREBOARD = re.compile(r"\bscoreboard\s+players\s+(\w+)\b")


def strip_comment(line: str) -> str:
    # Only a LEADING # is a comment. A mid-line # is a scoreboard name.
    return "" if line.lstrip().startswith("#") else line


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    root = pathlib.Path(sys.argv[1])
    problems = []
    checked = 0

    for path in sorted(root.rglob("*.mcfunction")):
        rel = path.relative_to(root)
        for n, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            line = strip_comment(raw.strip()).lstrip("$").strip()
            if not line:
                continue
            m = SCOREBOARD.search(line)
            if not m:
                continue
            sub = m.group(1)
            if sub not in ARITY:
                continue
            # Everything after the subcommand is the field list. Selector
            # brackets and $(...) contain no spaces, so a plain split is
            # correct here - which is the whole reason this is checkable.
            tail = line[m.end():].split()
            checked += 1
            want = ARITY[sub]
            if len(tail) != want:
                problems.append(
                    f"{rel}:{n}: `scoreboard players {sub}` has "
                    f"{len(tail)} field(s), needs {want}\n"
                    f"    {raw.strip()[:110]}"
                )

    print(f"scoreboard command lines checked: {checked}")
    if problems:
        print(f"\nPROBLEMS: {len(problems)}")
        for p in problems:
            print(f"  {p}")
        return 1
    print("SCOREBOARD ARITY: clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
