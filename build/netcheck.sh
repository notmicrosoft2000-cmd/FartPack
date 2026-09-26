#!/usr/bin/env bash
echo "=== playit agent process ==="
ps aux | grep -i playit | grep -v grep | head -3 || echo "  no playit process visible to this user"

echo
echo "=== playit config locations ==="
find "$HOME" -maxdepth 5 -iname '*playit*' 2>/dev/null | head -20

echo
echo "=== playit tunnel definitions (secrets redacted) ==="
for f in $(find "$HOME" -maxdepth 5 -iname '*playit*' -type f 2>/dev/null | head -6); do
  echo "--- $f ---"
  python3 - "$f" <<'PY'
import json, re, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
except Exception as e:
    print("   (not json: %s)" % e); sys.exit()
SECRET = re.compile(r'(key|token|secret|passw|auth)', re.I)
def scrub(o, ind=0):
    pad = "   " * ind
    if isinstance(o, dict):
        for k, v in o.items():
            if SECRET.search(k):
                print(pad + "%s: <REDACTED>" % k)
            elif isinstance(v, (dict, list)):
                print(pad + "%s:" % k); scrub(v, ind + 1)
            else:
                print(pad + "%s: %s" % (k, str(v)[:90]))
    elif isinstance(o, list):
        for i, v in enumerate(o):
            print(pad + "[%d]" % i); scrub(v, ind + 1)
scrub(d)
PY
done

echo
echo "=== ~/homelab/webfiles ==="
ls -la "$HOME/homelab/webfiles/" 2>/dev/null | head -15

echo
echo "=== what is listening on 80/443/8080/8000 ==="
ss -tlnp 2>/dev/null | grep -E ':(80|443|8080|8000)[[:space:]]' || echo "  nothing on 80/443/8080/8000"

echo
echo "=== is the minecraft port reachable from OUTSIDE, or only via playit? ==="
echo "  server-ip in server.properties:"
grep -E '^(server-ip|server-port)=' "$HOME/crafty/servers/241920ac-55ce-46c6-aa2f-c42ebf290457/server.properties" | sed 's/^/    /'
