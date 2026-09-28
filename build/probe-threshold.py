#!/usr/bin/env python3
"""probe-threshold.py - find the RCON command length at which this server drops
the connection, by binary search over generated `give` lines.

Why bother finding the exact number, when "somewhere between 846 and 2149" is
already enough to act on? Because the number has to go INTO the lint as a
documented constant, and a constant nobody measured is a guess that rots the
moment the server version or the RCON library changes. A gate that says "lines
over N chars are not checked" is only honest if N is a real, measured boundary
rather than the length of the longest line that happened to work once.

The search uses real `give ... written_book` commands padded with real pages, not
opaque filler, so the threshold is a property of the COMMAND and not of some
artefact of how the padding was built. If a filler command of the same length
survives and a give command does not, that is a different limit entirely and this
script says so rather than reporting a single number.

Usage: probe-threshold.py [low] [high]     (defaults 400..4096)
"""
import sys

import importlib.util
import os
import sys

# probe-booklen.py has a hyphen in its name, so it cannot be imported normally and
# renaming it would break the command lines already written down in notes. Load it
# by path instead of adding an underscore alias that would be a second name for one
# file - two names for one probe is how you end up editing the copy nobody runs.
_spec = importlib.util.spec_from_file_location(
    "booklen", os.path.join(os.path.dirname(os.path.abspath(__file__)), "probe-booklen.py"))
p = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(p)


def make_give(target_len):
    """A syntactically real written_book give, padded with pages until the whole
    command line is `target_len` characters. Never shorter than a legal book."""
    base = ('execute as @a run give @a minecraft:written_book'
            '[minecraft:written_book_content={title:"t",author:"a",pages:[')
    tail = "]}] 1"
    page = "'{\"text\":\"%s\"}'"
    room = target_len - len(base) - len(tail) - len(page % "")
    if room < 0:
        raise SystemExit("target %d too short for a legal book" % target_len)
    per_page = room - 5          # 5 = the ", " between pages
    npages = max(1, per_page // 8)
    pages = ",".join([page % ("x" * 8)] * npages)
    cmd = base + pages + tail
    return cmd


def survives(target_len):
    cmd = make_give(target_len)
    state, _ = p.ask(cmd)
    return state, len(cmd)


if __name__ == "__main__":
    low = int(sys.argv[1]) if len(sys.argv) > 1 else 400
    high = int(sys.argv[2]) if len(sys.argv) > 2 else 4096

    # The control first, always. A threshold measured through a broken transport
    # is a threshold on nothing.
    ctl, _ = p.ask("scoreboard players get #loaded fart.var")
    print("=== control ===")
    print("  scoreboard players get  ->  %s" % ctl)
    if ctl != "ANSWERED":
        raise SystemExit("CONTROL FAILED - transport is unhealthy, refusing to measure")
    print("  healthy, measuring.\n")

    print("=== probing for the boundary ===")
    slo, _ = survives(low)
    shi, _ = survives(high)
    print("  %5d chars -> %s" % (low, slo))
    print("  %5d chars -> %s" % (high, shi))

    if slo == "LOST" or shi != "LOST":
        print()
        print("  The endpoints do not straddle a boundary, so there is no clean")
        print("  threshold to report. Not a failure - it means the limit is either")
        print("  below %d or absent, and the lint should not claim a cutoff." % low)
        raise SystemExit(0)

    lo, hi = low, high
    while hi - lo > 8:
        mid = (lo + hi) // 2
        st, actual = survives(mid)
        print("  %5d chars -> %-8s (command was %d)" % (mid, st, actual))
        if st == "LOST":
            hi = mid
        else:
            lo = mid
    print()
    print("  BOUNDARY: %d chars survives, %d chars is dropped." % (lo, hi))
    print("  The lint should treat any line above ~%d chars as UNCHECKABLE over" % lo)
    print("  RCON and say so, rather than reporting a parse failure it never got to")
    print("  ask about.")
