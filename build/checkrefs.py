#!/usr/bin/env python3
"""Check that every `function` reference in the pack resolves to a real file.

Why this exists: `run function fartpack:typo/here` is not a parse error. The
datapack loads, the objective reports zero failures, and the branch simply never
does anything. It is indistinguishable from "working as intended" until someone
is standing in the rain wondering why the sky is quiet. Same failure shape as the
generated block-name lookup in #23, so it gets the same treatment.

Also checks the reverse direction that actually matters for removals: a function
file that exists but is never called from anywhere is dead code (that is how the
Pass A pile-up happened).

Usage:  python3 build/checkrefs.py [pack-dir]
Exit 0 if clean, 1 if any dangling or dead references.
"""
import os
import re
import sys
from collections import defaultdict

PACK = sys.argv[1] if len(sys.argv) > 1 else "fartpack-latest"
FUNCDIR = os.path.join(PACK, "data", "fartpack", "function")

if not os.path.isdir(FUNCDIR):
    sys.exit(f"no function directory at {FUNCDIR}")

# Every real function path, e.g. "fartpack:world/tick"
existing = set()
for root, _dirs, files in os.walk(FUNCDIR):
    for f in files:
        if f.endswith(".mcfunction"):
            rel = os.path.relpath(os.path.join(root, f), FUNCDIR)
            existing.add("fartpack:" + rel.replace(os.sep, "/")[: -len(".mcfunction")])

# Vanilla / non-pack functions we are happy to call. Anything not in this list and
# not in `existing` is treated as dangling, so an unrecognised external call fails
# loudly instead of being waved through.
EXTERNAL = {"minecraft:tick", "minecraft:load"}

CALL = re.compile(r"\b(?:run\s+)?function\s+([a-zA-Z0-9_./-]+:[a-zA-Z0-9_./-]+)")

referenced = defaultdict(list)   # target -> [(caller, lineno)]
callers = set()

for root, _dirs, files in os.walk(FUNCDIR):
    for f in sorted(files):
        if not f.endswith(".mcfunction"):
            continue
        path = os.path.join(root, f)
        rel = "fartpack:" + os.path.relpath(path, FUNCDIR).replace(os.sep, "/")[: -len(".mcfunction")]
        callers.add(rel)
        with open(path, encoding="utf-8") as fh:
            for n, line in enumerate(fh, 1):
                # ONLY a `#` in the leading whitespace is a comment. Mid-line, `#` is
                # a scoreboard fake-player name -- `#scan_c`, `#loaded`, `#rc` -- and
                # stripping from the first `#` silently deletes the entire 30-tick
                # cycle from the analysis, which reports the most-called functions in
                # the pack as dead. Minecraft's own rule is that a comment must start
                # the line.
                code = "" if line.lstrip().startswith("#") else line
                for m in CALL.finditer(code):
                    referenced[m.group(1)].append((rel, n))

dangling = []
for target, sites in sorted(referenced.items()):
    if target in existing or target in EXTERNAL:
        continue
    for caller, n in sites:
        dangling.append((caller, n, target))

# Dead code: a function nothing calls and which is not a tag/load entry point.
# load.json / tick.json name their own entry points, so read those in.
entrypoints = set()
for tagname in ("load", "tick"):
    p = os.path.join(PACK, "data", "minecraft", "tags", "function", tagname + ".json")
    if os.path.exists(p):
        import json
        for v in json.load(open(p)).get("values", []):
            entrypoints.add(v)

# Advancement rewards are entry points as well. items/on_kibble and items/on_tonic
# are reached ONLY this way - nothing calls them, they fire when the player eats
# the item. Treating them as dead would have me deleting working features.
#
# Also manual entry points: run by a player or admin typing /function, never called
# by the pack. They are unreachable by design and must be listed here or this tool
# reports working features as dead:
#   /function fartpack:items         -> a sample of both consumables
#   /function fartpack:items/give    -> the same, inner function
#   /function fartpack:player/fart   -> "I need to go right now", skips the timer
#   /function fartpack:admin/*       -> the per-player config commands (v26)
# The admin/* set is typed by an operator with arguments, e.g.
#   /function fartpack:admin/rate Steve 2
# so nothing in the pack can ever call it. show_one, resync_bar, recalc and
# defaults are reached from those macros and are listed because checkrefs walks
# function calls, not the fact that a macro's caller supplies the arguments.
MANUAL = {
    "fartpack:items",
    "fartpack:items/give",
    "fartpack:player/fart",
    "fartpack:admin/cap",
    "fartpack:admin/defaults",
    "fartpack:admin/every",
    "fartpack:admin/pow",
    "fartpack:admin/rate",
    "fartpack:admin/recalc",
    "fartpack:admin/rel",
    "fartpack:admin/reset",
    "fartpack:admin/resync_bar",
    "fartpack:admin/set_max",
    "fartpack:admin/show",
    "fartpack:admin/show_one",
}
entrypoints |= MANUAL
import glob
for adv in glob.glob(os.path.join(PACK, "data", "**", "advancement", "**", "*.json"), recursive=True):
    try:
        j = json.load(open(adv))
    except Exception:
        continue
    fn = (j.get("rewards") or {}).get("function")
    if fn:
        entrypoints.add(fn)
        for r in (j.get("criteria") or {}).values():
            fn2 = (r.get("rewards") or {}).get("function")
            if fn2:
                entrypoints.add(fn2)

# Forward reachability from the entry points. A function is live if the entry
# points can reach it through the call graph. Doing this forwards matters: the
# obvious backwards shortcut ("is it called by something live?") needs the same
# fixpoint but is far easier to get subtly wrong, and getting it wrong reports
# working code as dead.
calls = defaultdict(set)
for target, sites in referenced.items():
    for caller, _n in sites:
        calls[caller].add(target)

reachable = set(entrypoints)
stack = list(entrypoints)
while stack:
    cur = stack.pop()
    for t in calls.get(cur, ()):
        if t in existing and t not in reachable:
            reachable.add(t)
            stack.append(t)

dead = existing - reachable

print(f"functions on disk:            {len(existing)}")
print(f"entry points from tags:       {len(entrypoints)}  {sorted(entrypoints)}")
print(f"distinct call targets:        {len(referenced)}")
print()

if dangling:
    print(f"DANGLING CALLS: {len(dangling)}")
    for caller, n, target in dangling:
        print(f"  {caller}:{n}  ->  {target}")
    print()
else:
    print("DANGLING CALLS: 0")
    print()

deadcallers = sorted(dead)
if deadcallers:
    print(f"UNCALLABLE FUNCTIONS: {len(deadcallers)}")
    for f in deadcallers:
        print(f"  {f}")
    print()
    print("  Unreachable from load/tick, an advancement reward, or the MANUAL list in")
    print("  this script. Harmless at runtime, but this is how Pass A accumulated 6")
    print("  dead files - delete it, wire it up, or add it to MANUAL if it is a")
    print("  /function command a player is meant to type.")
else:
    print("UNCALLABLE FUNCTIONS: 0")
print()

ok = not dangling
print("RESULT:", "clean" if ok else "FAIL - fix dangling calls before deploying")
sys.exit(0 if ok else 1)
