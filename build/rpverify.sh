#!/usr/bin/env bash
# Verify the freshly uploaded RP is really downloadable and byte-identical to
# what we built, BEFORE pointing the server at it. A wrong URL here locks
# everyone out of the server (require-resource-pack=true).
set -euo pipefail
SID=241920ac-55ce-46c6-aa2f-c42ebf290457
SRV="$HOME/crafty/servers/$SID"
cd /tmp
rm -rf rpverify && mkdir rpverify && cd rpverify

URL=$(cat /tmp/rp_url.txt)
echo "=== downloading the uploaded RP ==="
curl -sSL -o got.zip "$URL"
echo "  bytes : $(stat -c%s got.zip)"
echo "  sha1  : $(sha1sum got.zip | cut -d' ' -f1)"
echo "  local : $(sha1sum /tmp/fartpack_sounds.zip | cut -d' ' -f1)"
if [ "$(sha1sum got.zip | cut -d' ' -f1)" = "$(sha1sum /tmp/fartpack_sounds.zip | cut -d' ' -f1)" ]; then
  echo "  MATCH - upload is byte-identical"
else
  echo "  MISMATCH - do not point the server at this"; exit 1
fi

echo
echo "=== contents of the uploaded RP ==="
python3 -c "import zipfile;zipfile.ZipFile('got.zip').extractall('x')"
find x -type f | sort
echo
echo "  pack.mcmeta:"; sed 's/^/    /' x/pack.mcmeta
echo "  sounds.json entries:"; python3 -c "import json;print('   ',list(json.load(open('x/assets/fartpack/sounds.json')).keys()))"
echo "  fart sounds listed:"; python3 -c "import json;print('   ',len(json.load(open('x/assets/fartpack/sounds.json'))['fart.burp']['sounds']))"
echo "  ogg count: $(find x -name '*.ogg' | wc -l)"

echo
echo "=== is the URL time-limited? check the ex= param ==="
python3 - <<'PY'
import re,urllib.parse,datetime
u=open('/tmp/rp_url.txt').read().strip()
q=urllib.parse.parse_qs(urllib.parse.urlparse(u).query)
ex=q.get('ex',[None])[0]
if ex:
    t=int(ex,16)
    print("  ex=0x%s -> %s UTC" % (ex, datetime.datetime.utcfromtimestamp(t)))
    print("  delta from now: %+.1f hours" % ((t-datetime.datetime.utcnow().timestamp())/3600))
else:
    print("  no ex= param")
PY
