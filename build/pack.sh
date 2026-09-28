#!/usr/bin/env bash
# pack.sh - build the datapack zip deterministically.
#
# Why this file exists: the zip used to be assembled ad hoc, and its sha1 was
# quoted in notes as if it identified "the v26 build". That only held because
# the commands happened to produce the same bytes twice. Nothing enforced it,
# so a rebuild after an unrelated edit could silently change the artifact - and
# since the lint/deploy handshake compares hashes, a non-reproducible zip makes
# that gate lie in the other direction (falsely reporting a mismatch).
#
# Determinism rules, all of them load-bearing:
#   * files are added in sorted path order
#   * every entry gets a fixed timestamp (1980-01-01, the zip epoch)
#   * deflate level is pinned rather than left to the local zlib default
#   * unix mode and create_system pinned, so the host does not leak in
#   * no zip comment, no extra fields, no directory entries
#
# Note there is deliberately NO build stamp inside the zip. Content already
# determines bytes here, so a stamp would only make the artifact differ between
# two builds of the same source - which is the exact property the lint/deploy
# hash handshake depends on.
#
# Only python3 is guaranteed on the build host, and the same is true of the
# server - which has neither zip nor unzip. So zipping and unzipping both go
# through zipfile, and this file is the single definition of the artifact.
#
# THE OUTPUT PATH IS IN THE REPO, NOT /tmp, AND THAT IS NOT COSMETIC. This used
# to default to /tmp/fartpack-latest.zip, which left TWO files called
# "fartpack-latest.zip" in play: the one this script writes, and a stale one
# sitting in the working directory. Nothing about the name says which is which,
# so the stale one got hashed, "determinism-checked" (twice, against itself, which
# is not a check at all), uploaded and shipped - while the freshly built artifact
# was never looked at. The stale copy was from the day before and contained the
# v26 four-field `+= #famt` bug that #30 fixed, so the lint failed 8 lines that
# had already been fixed in the tree and the real cause was upstream of the pack.
# The deploy gate caught it; nothing before the gate could have. See #34.
#
# One path, in the repo, next to the source it is built from, and the SELF-CHECK
# at the end asserts the bytes inside the zip are the bytes of the tree - so
# "the artifact is the source" is a checked fact rather than an assumption.
set -euo pipefail

SRC=${1:-fartpack-latest}
OUT=${2:-$PWD/fartpack-latest.zip}

[ -d "$SRC" ] || { echo "FATAL: $SRC is not a directory"; exit 1; }
[ -f "$SRC/pack.mcmeta" ] || { echo "FATAL: $SRC/pack.mcmeta missing"; exit 1; }

mkdir -p "$(dirname "$OUT")"

python3 - "$SRC" "$OUT" <<'PY'
import pathlib, sys, zipfile

src, out = pathlib.Path(sys.argv[1]), sys.argv[2]

# Fixed timestamp: the zip format cannot represent anything before 1980, and a
# constant is what makes two builds of identical content byte-identical.
STAMP = (1980, 1, 1, 0, 0, 0)

files = sorted(
    (p for p in src.rglob("*") if p.is_file()),
    key=lambda p: p.relative_to(src).as_posix(),
)
if not files:
    sys.exit("FATAL: no files under %s" % src)

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for p in files:
        arc = p.relative_to(src).as_posix()
        info = zipfile.ZipInfo(arc, date_time=STAMP)
        info.compress_type = zipfile.ZIP_DEFLATED
        # 0644, and mark as a regular file. create_system=3 is unix, which keeps
        # the external attributes byte-identical across hosts.
        info.create_system = 3
        info.external_attr = (0o100644 & 0xFFFF) << 16
        z.writestr(info, p.read_bytes())

print("packed %d files -> %s" % (len(files), out))
PY

echo "sha1: $(sha1sum "$OUT" | cut -d' ' -f1)"
echo
echo "--- contents (first 12) ---"
python3 -c "import zipfile,sys; n=zipfile.ZipFile(sys.argv[1]).namelist(); print('\n'.join(n[:12])); print('  ... %d entries total' % len(n))" "$OUT"
echo
echo "--- required entries present? ---"
python3 - "$OUT" <<'PY'
import sys, zipfile
n = set(zipfile.ZipFile(sys.argv[1]).namelist())
bad = 0
for want in ("pack.mcmeta", "data/fartpack/function/tick.mcfunction",
             "data/fartpack/function/core/bootstrap.mcfunction"):
    ok = want in n
    print("  %-5s %s" % ("ok" if ok else "MISS", want))
    bad += not ok
# A datapack is silently ignored by the game if pack_format is missing or the
# layout is wrong, so a light structural assertion is worth more than a hash.
sys.exit(bad)
PY
echo
echo "--- SELF-CHECK: is the artifact actually the tree? ---"
# This is the check that would have caught the stale-zip incident, and it is the
# only one that can: a hash tells you an artifact is stable, never that it is
# CURRENT. Both were true of the file that got shipped - perfectly reproducible,
# twice in a row, and from the day before.
#
# So read the zip back and compare it to the source, file by file, in both
# directions: every entry must match its file on disk, and every file on disk
# must appear. A one-directional check would pass on a zip that is missing
# something, which is the half of the problem that actually breaks a datapack -
# a function that silently is not there.
python3 - "$SRC" "$OUT" <<'PY'
import pathlib, sys, zipfile

src, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])

want = {}
for p in src.rglob("*"):
    if p.is_file():
        want[p.relative_to(src).as_posix()] = p.read_bytes()

with zipfile.ZipFile(out) as z:
    got = {n: z.read(n) for n in z.namelist()}

missing = sorted(set(want) - set(got))   # in the tree, absent from the zip
extra   = sorted(set(got) - set(want))   # in the zip, absent from the tree
differ  = sorted(n for n in set(want) & set(got) if want[n] != got[n])

for label, names in (("MISSING FROM ZIP", missing), ("EXTRA IN ZIP", extra),
                     ("CONTENT DIFFERS", differ)):
    for n in names:
        print("  %-17s %s" % (label, n))

if missing or extra or differ:
    print("  SELF-CHECK FAILED: the zip is not the source tree. Do not ship it.")
    sys.exit(1)
print("  ok   %d files, every one byte-identical to the tree, nothing extra" % len(want))
PY

echo
# One greppable line naming the artifact and its hash. The deploy handshake
# compares hashes, and that comparison is only meaningful if both sides are
# talking about the same file - so the path is printed, not assumed.
echo "ARTIFACT: $OUT"
echo "SHA1: $(sha1sum "$OUT" | cut -d' ' -f1)"
echo "zip built at: $OUT"
