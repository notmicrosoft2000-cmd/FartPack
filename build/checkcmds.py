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

# --- second check: every `execute` chain must carry its `run` ---------------
#
# Found by the live parse lint on v28, which rejected
#     execute if score @s fart.shovecd matches 1..4 return 0
# with "Incorrect argument for command...ches 1..4 return 0<--[HERE]" and
# aborted the deploy. The caret sits past the end of the line, so the message
# does not name the missing token. Asked directly over RCON, the server accepts
# the same line with `run` inserted and rejects it without.
#
# WHY ADD IT HERE RATHER THAN TRUSTING THE LIVE LINT: the live lint caught it
# this time, but it needs a server, takes minutes, and runs at the very end of
# the deploy chain. This is a two-second static check. #30's lesson was that a
# gate which only works on the happy path is a gate that stops working exactly
# when it is needed, so it is worth catching the earliest possible.
#
# SCOPE, stated honestly: this asserts that EVERY `execute` line in this pack
# ends in `run <command>`. That is a convention this pack follows without
# exception, not a rule vanilla imposes - vanilla permits a bounded set of
# subcommands in the no-`run` form. So this check has no false positives here
# and would produce them in a pack written to the other convention; it is a
# convention check wearing a lint's clothes, and is labelled as one below.
#
# It also cannot tell whether the command after `run` is itself well formed. The
# parse lint remains the only thing that answers that, and the two are additive.
EXECUTE = re.compile(r"^execute\s")


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
    exec_checked = 0

    for path in sorted(root.rglob("*.mcfunction")):
        rel = path.relative_to(root)
        for n, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            line = strip_comment(raw.strip()).lstrip("$").strip()
            if not line:
                continue

            # -- execute/run, checked on EVERY line whether or not it is a
            # scoreboard line, so neither check can mask the other
            if EXECUTE.match(line):
                exec_checked += 1
                if not re.search(r"\brun\b", line):
                    problems.append(
                        f"{rel}:{n}: `execute` chain has no `run`\n"
                        f"    {raw.strip()[:110]}\n"
                        f"    the server rejects this form; it wants "
                        f"`... run <command>`. Confirmed over RCON on v28."
                    )

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
    print(f"execute chains checked: {exec_checked}  (convention: every one ends in `run`)")
    if problems:
        print(f"\nPROBLEMS: {len(problems)}")
        for p in problems:
            print(f"  {p}")
        return 1
    print("SCOREBOARD ARITY: clean")
    print("EXECUTE/RUN: clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
