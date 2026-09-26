#!/usr/bin/env bash
SID=241920ac-55ce-46c6-aa2f-c42ebf290457
SRV="$HOME/crafty/servers/$SID"

echo "=== expiry of the CURRENTLY configured RP url ==="
python3 - <<'PY'
import urllib.parse, datetime, pathlib
p = pathlib.Path("/home/nept/crafty/servers/241920ac-55ce-46c6-aa2f-c42ebf290457/server.properties")
raw = None
for line in p.read_text().splitlines():
    if line.startswith("resource-pack="):
        raw = line.split("=", 1)[1]
        break
u = raw.replace("\\:", ":").replace("\\=", "=")
q = urllib.parse.parse_qs(urllib.parse.urlparse(u).query)
ex = q.get("ex", [None])[0]
now = datetime.datetime.now(datetime.UTC).timestamp()
if ex:
    t = int(ex, 16)
    print("  ex=0x%s -> %s UTC" % (ex, datetime.datetime.fromtimestamp(t, datetime.UTC)))
    print("  expires in: %+.1f hours" % ((t - now) / 3600))
else:
    print("  no ex= param -> never expires")
pathlib.Path("/tmp/rp_old_url.txt").write_text(u + "\n")
PY

echo
echo "=== does the CURRENT url still actually serve the file? ==="
curl -sS -o /tmp/old.zip -w '  http_status=%{http_code}  bytes=%{size_download}\n' "$(cat /tmp/rp_old_url.txt)" || true
if [ -s /tmp/old.zip ]; then
  echo "  sha1: $(sha1sum /tmp/old.zip | cut -d' ' -f1)"
  echo "  first bytes: $(head -c 60 /tmp/old.zip | tr -d '\0' | tr -c '[:print:]' '.')"
fi

echo
echo "=== so: does an expired discord url break joining? ==="
grep -E 'require-resource-pack' "$SRV/server.properties"
