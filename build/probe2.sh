#!/usr/bin/env bash
R=(python3 /tmp/rcon.py)
CX=300; CY=100; CZ=300

echo "=== 1. does setblock to undyed_shulker_box actually work? ==="
"${R[@]}" 'forceload add 300 300' >/dev/null 2>&1
"${R[@]}" "setblock $CX $((CY+2)) $CZ minecraft:stone" 2>&1 | tail -1
"${R[@]}" "setblock $CX $((CY+2)) $CZ minecraft:undyed_shulker_box" 2>&1 | tail -1
echo "  server's own opinion of what is there now:"
"${R[@]}" "execute if block $CX $((CY+2)) $CZ minecraft:undyed_shulker_box run data modify storage fartpack:msg probe set value MATCHED_SHULKER" 2>&1 | tail -1
"${R[@]}" "execute if block $CX $((CY+2)) $CZ minecraft:anvil run data modify storage fartpack:msg probe set value MATCHED_ANVIL" 2>&1 | tail -1
"${R[@]}" 'data get storage fartpack:msg probe' 2>&1 | tail -1

echo
echo "=== 2. is undyed_shulker_box in the deployed tag AND in the generated file? ==="
python3 - "$HOME/crafty/servers/241920ac-55ce-46c6-aa2f-c42ebf290457/world/datapacks/fartpack.zip" <<'PY'
import sys, zipfile, json
z = zipfile.ZipFile(sys.argv[1])
t = [x for x in z.namelist() if x.endswith('tags/block/utility.json')][0]
vals = json.loads(z.read(t))['values']
n = [x for x in z.namelist() if x.endswith('world/block_name.mcfunction')][0]
lines = [l for l in z.read(n).decode().splitlines() if l.strip().startswith('execute if block')]
for want in ('minecraft:undyed_shulker_box', 'minecraft:anvil', 'minecraft:white_shulker_box'):
    in_tag = want in vals
    in_gen = [l for l in lines if want in l]
    print("  %-30s tag=%-5s generated=%s" % (want, in_tag, in_gen[0].split('value "')[-1] if in_gen else "MISSING"))
print("  tag=%d generated=%d  (counts must match)" % (len(vals), len(lines)))
# every tag entry must have exactly one generated line
missing = [v for v in vals if not any(v in l for l in lines)]
print("  tag entries with NO generated line:", missing if missing else "none")
PY

echo
echo "=== 3. is minecraft:undyed_shulker_box even a real block on this server? ==="
"${R[@]}" "setblock $CX $((CY+4)) $CZ minecraft:undyed_shulker_box" 2>&1 | tail -1
"${R[@]}" "setblock $CX $((CY+4)) $CZ minecraft:undyed_shulker_box[facing=north]" 2>&1 | tail -1

echo
echo "=== 4. the summon that produced 0 birds ==="
"${R[@]}" "kill @e[type=minecraft:chicken,tag=fart.kbtest]" >/dev/null 2>&1
"${R[@]}" "setblock $CX $((CY+3)) $CZ minecraft:stone" 2>&1 | tail -1
echo "  plain summon, no NBT:"
"${R[@]}" "summon minecraft:chicken $CX $((CY+4)) $CZ" 2>&1 | tail -1
"${R[@]}" "execute as @e[type=minecraft:chicken,limit=1] run data modify storage fartpack:msg probe set value BIRD_ALIVE" 2>&1 | tail -1
"${R[@]}" 'data get storage fartpack:msg probe' 2>&1 | tail -1
echo "  kill it, then summon WITH the Tags NBT:"
"${R[@]}" 'kill @e[type=minecraft:chicken]' >/dev/null 2>&1
"${R[@]}" "summon minecraft:chicken $CX $((CY+4)) $CZ {Tags:[\"fart.kbtest\"]}" 2>&1 | tail -1
"${R[@]}" "execute as @e[type=minecraft:chicken,tag=fart.kbtest,limit=1] run data modify storage fartpack:msg probe set value TAGGED_BIRD_ALIVE" 2>&1 | tail -1
"${R[@]}" 'data get storage fartpack:msg probe' 2>&1 | tail -1

echo
echo "=== 5. does the count trick work at all? ==="
"${R[@]}" 'data modify storage fartpack:msg n set value 0' 2>&1 | tail -1
"${R[@]}" 'execute as @e[type=minecraft:chicken,tag=fart.kbtest] run data modify storage fartpack:msg n add value 1' 2>&1 | tail -1
"${R[@]}" 'data get storage fartpack:msg n' 2>&1 | tail -1

echo
echo "=== 6. and the bird's actual Pos, for the knockback arithmetic ==="
"${R[@]}" 'execute store result score #px fart.var run data get entity @e[type=minecraft:chicken,tag=fart.kbtest,limit=1] Pos[0] 10' >/dev/null 2>&1
"${R[@]}" 'scoreboard players get #px fart.var' 2>&1 | tail -1

echo
echo "=== cleanup ==="
"${R[@]}" 'kill @e[type=minecraft:chicken]' "fill $CX $CY $CZ $CX $((CY+5)) $CZ minecraft:air" 'forceload remove 300 300' >/dev/null 2>&1
echo "  done"
