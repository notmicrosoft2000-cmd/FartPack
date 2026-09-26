#!/usr/bin/env bash
# Drive fartpack:tick by hand across a full 30-tick cycle, twice, and check that
# (a) it does not error, (b) #scan_c walks 1..30 then wraps, (c) the #rc reaper
# fires. This works while the server is PAUSED (pause-when-empty-seconds=60),
# so it is the only way to runtime-test the pack with 0 players online.
SID=241920ac-55ce-46c6-aa2f-c42ebf290457
SRV="$HOME/crafty/servers/$SID"
LOG="$SRV/logs/latest.log"
MARK=$(wc -l < "$LOG")

echo "=== log line count before: $MARK ==="

# One RCON session, alternating tick / read, so this finishes in ~45s not ~6min.
CMDS=( 'scoreboard players set #scan_c fart.var 0' 'scoreboard players set #rc fart.var 0' )
for i in $(seq 1 70); do
  CMDS+=( 'function fartpack:tick' 'scoreboard players get #scan_c fart.var' )
done
CMDS+=( 'scoreboard players get #rc fart.var' )

python3 /tmp/rcon.py "${CMDS[@]}" > /tmp/smoke.out 2>&1
echo "exit=$?"

echo
echo "=== #scan_c sequence (should climb to 30, wrap to 0, repeat) ==="
grep -A1 'scoreboard players get #scan_c' /tmp/smoke.out | grep -oE 'has [0-9-]+' | grep -oE '[0-9-]+' \
  | tr '\n' ' ' | fold -w 100 | sed 's/^/    /'
echo

echo
echo "=== did any tick report an error? ==="
echo "  error replies: $(grep -cE 'Incorrect argument|Unknown|Expected|Can.t parse|error' /tmp/smoke.out)"
grep -E 'Incorrect argument|Unknown|Expected|Can.t parse' /tmp/smoke.out | sort -u | head
echo

echo "=== reaper: #rc should be < 200 (it resets at 200) ==="
grep 'scoreboard players get #rc' /tmp/smoke.out | tail -2 | sed 's/^/  /'

echo
echo "=== NEW log lines written by those 70 manual ticks ==="
tail -n +"$MARK" "$LOG" | grep -vE 'RCON Client|RCON Listener' > /tmp/tickout.txt
echo "  new log lines: $(wc -l < /tmp/tickout.txt)"
echo "  --- non-thread lines (real events) ---"
grep -vE '^\[[0-9:]+\] \[(Server thread|Worker-Main|Rcon)' /tmp/tickout.txt | head -20
echo "  --- ERROR / Exception / Failed to load ---"
grep -E 'ERROR|Exception|Failed to load' /tmp/tickout.txt | grep -v quickdeath | head -20
echo "  --- end ---"
