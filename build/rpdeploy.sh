#!/usr/bin/env bash
# Roll out the new resource pack. The sha1 in server.properties only takes
# effect on restart, so this patches then bounces the server via the Crafty API.
set -euo pipefail
SID=241920ac-55ce-46c6-aa2f-c42ebf290457
SRV="$HOME/crafty/servers/$SID"
LOG="$SRV/logs/latest.log"
RP_URL=$(cat /tmp/rp_url.txt)
RP_SHA=$(sha1sum /tmp/fartpack_sounds.zip | cut -d' ' -f1)

echo "=== PREFLIGHT: enforce 0 players online (this actually aborts) ==="
ONLINE=$(python3 /tmp/rcon.py 'list' 2>/dev/null | grep -oE 'There are [0-9]+ of' | grep -oE '[0-9]+')
echo "  players online: $ONLINE"
if [ "${ONLINE:-99}" != "0" ]; then
  echo "  ABORT: $ONLINE player(s) online. Not restarting on top of someone."
  exit 1
fi

echo
echo "=== PREFLIGHT: the RP URL must still be alive and correct ==="
curl -sS -o /tmp/pre.zip -w '  http=%{http_code} bytes=%{size_download}\n' "$RP_URL"
GOT=$(sha1sum /tmp/pre.zip | cut -d' ' -f1)
echo "  downloaded sha1: $GOT"
echo "  expected  sha1: $RP_SHA"
[ "$GOT" = "$RP_SHA" ] || { echo "  ABORT: URL does not serve the pack we built"; exit 1; }

echo
echo "=== mark the log so we only inspect the new run ==="
MARK=$(wc -l < "$LOG")
echo "  log line count before: $MARK"
echo "$MARK" > /tmp/logmark

echo
echo "=== patch server.properties ==="
python3 /tmp/craftyrestart.py patch "$RP_URL" "$RP_SHA"

echo
echo "=== restart via Crafty API ==="
python3 /tmp/craftyrestart.py restart

echo
echo "=== post-restart verification ==="
sleep 20
python3 /tmp/craftyrestart.py status
echo
echo "  -- properties as the server now reads them --"
grep -E '^resource-pack' "$SRV/server.properties" | sed -E 's/(hm=)[a-f0-9]+/\1<sig>/' | sed 's/^/    /'
echo
echo "  -- datapack survived the restart? --"
python3 /tmp/rcon.py 'datapack list' 2>/dev/null | grep -o 'file/fartpack.zip (world)' || echo "    FATTPACK NOT LISTED"
python3 /tmp/rcon.py 'scoreboard players get #loaded fart.var' 2>/dev/null | tail -1
python3 /tmp/rcon.py 'scoreboard players get #enabled fart.var' 2>/dev/null | tail -1
python3 /tmp/rcon.py 'list' 2>/dev/null | tail -1
echo
echo "  -- Failed to load / errors in the NEW run only --"
tail -n +"$MARK" "$LOG" | grep -E 'Failed to load function fartpack' | head -20 || true
echo "    (count: $(tail -n +"$MARK" "$LOG" | grep -cE 'Failed to load function fartpack'))"
tail -n +"$MARK" "$LOG" | grep -E 'ERROR|Exception' | grep -v quickdeath | head -10 || true
echo
echo "  -- damage_type registry loaded (needs restart, now can confirm) --"
python3 /tmp/rcon.py 'execute if score #rc fart.var matches 0.. run say PACK_ALIVE' 2>/dev/null | tail -2
echo
echo "  -- tail of the new run --"
tail -n +"$MARK" "$LOG" | grep -vE 'RCON Client|RCON Listener' | tail -15
