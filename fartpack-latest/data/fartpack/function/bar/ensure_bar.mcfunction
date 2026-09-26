# bar/ensure_bar - self-heal the gas bossbar.
# Bossbars are runtime-only (a server restart wipes them) while player tags and
# scores persist, so existence MUST be probed - a player tag cannot be trusted.
# A failed `bossbar get` stores 0, which is exactly the "missing" sentinel, and a
# present bar stores its max (100). No pre-seed/reset is needed: the probe always
# overwrites #eb_tmp first, and one shared scratch name avoids leaking a
# #eb<pid> row per player.
$execute store result score #eb_tmp fart.var run bossbar get fartpack:gas_$(pid) max
$execute if score #eb_tmp fart.var matches 0 run bossbar add fartpack:gas_$(pid) {"text":"Gas Pressure","color":"yellow"}
$execute if score #eb_tmp fart.var matches 0 run bossbar set fartpack:gas_$(pid) max 100
$execute if score #eb_tmp fart.var matches 0 run bossbar set fartpack:gas_$(pid) color yellow
$execute if score #eb_tmp fart.var matches 0 run bossbar set fartpack:gas_$(pid) players @s
