#!/usr/bin/env bash
# Debug the generated block-name lookup one command at a time.
R="python3 /tmp/rcon.py"
P=300

echo "=== 1. is the function there and does it exist? ==="
$R 'function fartpack:world/block_name' 2>&1 | tail -2

echo
echo "=== 2. place a crafting table and confirm the server agrees it is one ==="
$R "setblock $P 100 $P minecraft:crafting_table" 2>&1 | tail -1
$R "execute if block $P 100 $P minecraft:crafting_table run say YES_ITS_A_CRAFTING_TABLE" 2>&1 | tail -1
$R "execute if block $P 100 $P minecraft:jukebox run say YES_ITS_A_JUKEBOX" 2>&1 | tail -1

echo
echo "=== 3. run the lookup with the position set, then read storage ==="
$R "execute positioned $P 100 $P run function fartpack:world/block_name" 2>&1 | tail -1
$R 'data get storage fartpack:msg name' 2>&1 | tail -1

echo
echo "=== 4. does the raw if-block + data-modify pair work at all? ==="
$R "execute if block $P 100 $P minecraft:crafting_table run data modify storage fartpack:msg name set value \"MANUAL TEST\"" 2>&1 | tail -1
$R 'data get storage fartpack:msg name' 2>&1 | tail -1

echo
echo "=== 5. how many blocks does the generated file actually contain, and is crafting_table in it? ==="
D="$HOME/crafty/servers/241920ac-55ce-46c6-aa2f-c42ebf290457/world/datapacks/fartpack.zip"
python3 - "$D" <<'PY'
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
n = [x for x in z.namelist() if x.endswith('world/block_name.mcfunction')][0]
body = z.read(n).decode()
lines = [l for l in body.splitlines() if l.strip().startswith('execute if block')]
print("  lookup lines in the DEPLOYED zip: %d" % len(lines))
for want in ('crafting_table', 'jukebox', 'barrel', 'enchanting_table'):
    hit = [l for l in lines if want in l]
    print("  %-18s %s" % (want, hit[0].split('value "')[-1] if hit else "*** NOT FOUND ***"))
print("  first 2 raw lines:")
for l in body.splitlines()[:2]:
    print("    %r" % l)
PY

echo
echo "=== 6. is jukebox actually in the deployed tag? ==="
python3 - "$D" <<'PY'
import sys, zipfile, json
z = zipfile.ZipFile(sys.argv[1])
t = [x for x in z.namelist() if x.endswith('tags/block/utility.json')][0]
v = json.loads(z.read(t))['values']
print("  tag entries: %d" % len(v))
for want in ('minecraft:crafting_table', 'minecraft:jukebox', 'minecraft:barrel'):
    print("  %-28s %s" % (want, "in tag" if want in v else "*** NOT IN TAG ***"))
PY

echo
echo "=== 7. cleanup ==="
$R "setblock $P 100 $P minecraft:air" 2>&1 | tail -1
