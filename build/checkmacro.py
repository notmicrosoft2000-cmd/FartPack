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

# --- second check: a macro's $(arg) must be written by SOMETHING ------------
#
# Found on v28, in my own new code. player/heal is
#     $data merge entity @s {Health:$(hp)}
# and player/press computed the number into the scoreboard holder #php and then
# called it:
#     function fartpack:player/heal with storage fartpack:data macro
# Nothing in the entire pack had ever written `fartpack:data macro.hp`. The macro
# would have failed at expansion with "Missing argument hp" once a second, the
# file loads cleanly, and every other check in this repo reports it as healthy:
# the macro rule holds, the function is called, the line parses. The mechanic was
# dead and nothing said so.
#
# The rule it broke is the same one already written in player/heal's own comment -
# "the caller stores the value" - which is the problem. A rule that lives only in
# a comment is documentation, not a gate, and this pack has been bitten by
# comment-only rules before.
#
# SCOPE, because a check that guesses is worse than no check. This asks the
# narrowest question that catches the real bug: across the WHOLE pack, does any
# line write this argument into the storage this macro is called with? It does
# not try to prove the write happens on the same tick, in the same function, or
# before the call - a pack may legitimately populate a storage from a caller two
# levels up, and trying to model that produces false positives, which is how a
# checker gets switched off.
#
# THE ADDRESSING, measured on the live server rather than assumed, because the
# first version of this check got it wrong and reported 8 false positives on a
# clean pack - it was not discriminating at all, and would have passed the bug it
# was written for exactly as readily as the fix for it.
#
# `with storage` takes an OPTIONAL second token that is a sub-path prefix, and
# the macro's arguments resolve at storage + prefix + name. Established by
# measurement, both directions:
#   * writing `fartpack:data macro.pid` and calling
#     `... with storage fartpack:data macro` -> $(pid) RESOLVED, $(cap) reported
#     "Missing argument cap". So the arg came from data.macro.pid, not data.pid.
#   * `fartpack:msg` holding {name:...}: `with storage fartpack:msg` worked;
#     `with storage fartpack:msg macro` answered "Found no elements matching
#     macro", i.e. it went looking for msg.macro and did not find it.
# So a write `store result storage S Q` supplies argument `a` of a call
# `with storage S P` exactly when Q == "P.a" (with P empty, Q == "a").
#
# TWO THINGS IT THEREFORE CANNOT SEE, both stated rather than papered over:
#   * a storage written by another datapack, or by anything outside this pack
#   * `with scoreboard` calls, where an argument is a score rather than a storage
#     key and the two are not the same thing - those are skipped, not judged
CALL = re.compile(
    r"\bfunction\s+([a-z0-9_.-]+:[a-z0-9_./-]+)\s+with\s+storage\s+"
    r"([a-z0-9_.-]+:[a-z0-9_./-]+)(?:\s+([a-z0-9_./-]+))?")
# `store result storage <id> <path>` and `data modify storage <id> <path>`.
STORE_PATH = re.compile(
    r"\b(?:store\s+result|modify)\s+storage\s+"
    r"([a-z0-9_.-]+:[a-z0-9_./-]+)\s+([a-z0-9_./\[\]-]+)")
# A whole-value write AT THE PREFIX. `data modify storage S P set value {}` CLEARS
# the object - it supplies nothing - and treating a clear as a supply is what
# would have made this check permanently unable to fail, since core/bootstrap
# clears `fartpack:data macro` on every version bump. Only a non-empty literal is
# treated as supplying every key, and that is deliberately generous.
CLEAR_OR_SET = re.compile(
    r"\bmodify\s+storage\s+([a-z0-9_.-]+:[a-z0-9_./-]+)\s+([a-z0-9_./-]+)\s+set\s+value\s+"
    r"(\{\s*\}|\[\s*\]|.)")
# An EMPTY literal - {} or [] - is a clear. Anything else is a real value, and
# which keys it contains is not worth parsing out of a JSON blob: treating it as
# supplying every key is the generous direction, and generosity here costs a
# missed report rather than a false alarm. The emptiness test is a full match on
# the literal, not a look at its first character - `{"pid":1}` also opens with a
# brace, and the first-character version silently classified every real
# assignment as a clear.
EMPTY_LITERAL = re.compile(r"[\{\[]\s*[\}\]]\Z")
ARG = re.compile(r"\$\(([^)]+)\)")


def is_comment(line: str) -> bool:
    # Only a leading-# line is a comment. A mid-line # is a scoreboard name -
    # see the `core/toggle_off` and `#scan_c` history in the docs.
    return line.lstrip().startswith(COMMENT)


def command_lines(path: pathlib.Path):
    """(line-number, text) for every command line, comments and blanks removed."""
    for n, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if line and not is_comment(line):
            yield n, line


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    root = pathlib.Path(sys.argv[1])
    functions = sorted(root.rglob("*.mcfunction"))
    checked = 0

    # First pass: what does each function need, and what does each storage hold?
    # Second pass: judge the calls against that. Both passes are needed because a
    # macro's argument is supplied by a different file from the one that needs
    # it, which is the whole point.
    needs = {}       # function id  -> set of $(arg)
    supplies = {}    # storage id   -> set of dotted paths that are written
    prefix_all = {}  # storage id   -> set of prefixes written NON-EMPTY in one go
    calls = []       # (file, line-number, function id, storage id, prefix, text)
    for path in functions:
        args = set()
        for n, line in command_lines(path):
            if MACRO_MARK in line:
                args |= set(ARG.findall(line))
            for m in CALL.finditer(line):
                calls.append((path, n, m.group(1), m.group(2), m.group(3) or "", line))
            for m in STORE_PATH.finditer(line):
                supplies.setdefault(m.group(1), set()).add(m.group(2))
            for m in CLEAR_OR_SET.finditer(line):
                if not EMPTY_LITERAL.match(m.group(3)):
                    prefix_all.setdefault(m.group(1), set()).add(m.group(2))
        if args:
            m = re.match(r"^data/([^/]+)/function/(.+)$",
                         str(path.relative_to(root))[:-len(".mcfunction")])
            if m:
                needs[f"{m.group(1)}:{m.group(2)}"] = args

    argchecked = 0
    for path, n, fid, store, prefix, line in calls:
        if fid not in needs:
            continue
        argchecked += 1
        have = supplies.get(store, set())
        if prefix in prefix_all.get(store, set()):
            continue                               # the whole object was set at once
        want = {f"{prefix}.{a}" if prefix else a for a in needs[fid]}
        missing = want - have
        if missing:
            rel = path.relative_to(root)
            where = f"{store} {prefix}".strip()
            problems.append(
                f"{rel}:{n}: calls {fid} with storage {where}, but no line in "
                f"the pack ever writes {', '.join(sorted(missing))} there\n"
                f"    {line[:100]}\n"
                f"    the macro will fail to expand with 'Missing argument' "
                f"every time it is called, and nothing else here would notice"
            )

    for path in functions:
        text = path.read_text(encoding="utf-8")
        # A file is a macro function iff a COMMAND line contains `$(`, not merely
        # if the text does. bar/tick_gas_bar explains the macro rules in its
        # comments while being an ordinary function that calls macros, and
        # testing raw text flags every one of its lines.
        command = [ln for _, ln in command_lines(path)]
        if not any(MACRO_MARK in ln for ln in command):
            continue
        checked += 1
        rel = path.relative_to(root)
        for n, line in command_lines(path):
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
    print(f"macro calls with storage checked for supplied args: {argchecked}")
    if problems:
        print(f"\nPROBLEMS: {len(problems)}")
        for p in problems:
            print(f"  {p}")
        return 1
    print("MACRO RULE: clean")
    print("MACRO ARGS: clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
