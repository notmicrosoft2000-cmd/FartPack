#!/usr/bin/env python3
"""Generate world/block_name.mcfunction from tags/block/utility.json.

WHY THIS EXISTS
---------------
world/fart_block used to announce the specific block ("a crafting table
farted!"). That was 18 hard-coded `if block <id>` + tellraw pairs, one per
block, which meant the tag and the copy could drift: add a block to the tag and
you silently get a fart with no announcement.

Pass C replaced all of that with one generic "a utility block farted!" line,
which cannot drift but threw away the detail. This generator gets the detail
back WITHOUT reintroducing the drift, because the list of names is derived from
the tag itself at build time rather than maintained by hand.

The generated function only does lookups. The actual sentence lives in exactly
one place, world/fart_msg.mcfunction, a string macro.

SILENT-SAFETY: the generated file resets the name to the generic fallback
BEFORE the lookup chain, so a block that is in the tag but somehow missing here
degrades to "a utility block farted!" rather than announcing the name of
whatever block was checked previously. Getting it slightly wrong is possible;
getting it actively, confidently wrong is not.

Usage:  python3 genblocknames.py <datapack-root>
"""
import json
import os
import re
import sys

TAG = "data/fartpack/tags/block/utility.json"
OUT = "data/fartpack/function/world/block_name.mcfunction"
FALLBACK = "a utility block"


def article(name: str) -> str:
    """"a crafting table" but "an enchanting table"."""
    return ("an " if name[:1].lower() in "aeiou" else "a ") + name


def pretty(block_id: str) -> str:
    """minecraft:undyed_shulker_box -> undyed shulker box"""
    return block_id.split(":", 1)[-1].replace("_", " ")


def main() -> int:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    root = sys.argv[1]
    tag_path = os.path.join(root, TAG)
    if not os.path.isfile(tag_path):
        sys.exit("cannot find %s under %s" % (TAG, root))

    with open(tag_path) as f:
        blocks = json.load(f).get("values", [])

    # Deterministic order regardless of how the tag happens to be sorted, so the
    # generated file (and therefore the zip) is reproducible.
    blocks = sorted(set(blocks))
    bad = [b for b in blocks if not re.fullmatch(r"[a-z0-9_.-]+:[a-z0-9_/.-]+", b)]
    if bad:
        sys.exit("these tag values are not valid block ids: %s" % bad)

    lines = [
        "# GENERATED FILE - do not edit by hand.",
        "# Regenerate with: python3 build/genblocknames.py fartpack-latest",
        "# (build.sh does this automatically on every build.)",
        "#",
        "# Source of truth is tags/block/utility.json. %d blocks." % len(blocks),
        "#",
        "# Sets storage fartpack:msg name to a human phrase for the block at",
        "# ~ ~ ~, e.g. \"a crafting table\". Read afterwards by the string macro",
        "# world/fart_msg.",
        "#",
        "# The reset on the next line is load-bearing: it guarantees a block that",
        "# is in the tag but missing from this file can never inherit the name of",
        "# a previously-matched block. Missing entry -> generic message, not a",
        "# wrong name.",
        "",
        'data modify storage fartpack:msg name set value "%s"' % FALLBACK,
    ]
    for b in blocks:
        lines.append(
            'execute if block ~ ~ ~ %s run data modify storage fartpack:msg name set value "%s"'
            % (b, article(pretty(b)))
        )
    lines.append("")

    out_path = os.path.join(root, OUT)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w") as f:
        f.write("\n".join(lines))

    print("genblocknames: %d blocks -> %s" % (len(blocks), OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
