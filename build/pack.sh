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
set -euo pipefail

SRC=${1:-fartpack-latest}
OUT=${2:-/tmp/fartpack-latest.zip}

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
echo "zip built at: $OUT"
