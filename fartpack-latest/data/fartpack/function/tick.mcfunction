# tick.mcfunction - the pack's one and only entry point, run once per tick by
# the pack's own tick function.
#
#   line 1  version gate: if core/bootstrap has not run at the CURRENT version,
#           run it. Bumping the number in both this file and core/bootstrap is
#           what makes new scoreboard objectives reach an already-existing world.
#
#   lines 2-5   player toggle (/trigger fart.toggle)
#   line  6     world/tick - mob/block timers, gas clouds, reaper, fart rain
#   lines 7-8   first-join boss bar setup
#   lines 9-20  the 30-tick cycle (#scan_c counts 1..30 then wraps to 0). Each
#           gate is an EXACT tick number, not a range - a range like `matches
#           1..9` runs the branch on all nine ticks, which would keep the total
#           command count identical to the old single-blob scan and only move
#           the spike around:
#                 1     blocks/scan_low  + world/etick   (49 block checks)
#                 10    blocks/scan_mid  + rain/event countdowns
#                 20    blocks/scan_high                   (49 block checks)
#                 10/20/30 player/fill_gas                 (unchanged 10-tick cadence)
#                 10/20  world/etick (entity set refresh, ~10 ticks apart)
#                 30     kill markers whose block is gone, then wrap
#           That is 147 block checks per 30 ticks instead of 147 per 10: a real
#           3x cut. Cost: a utility block can take up to 1.5s to be noticed
#           (markers still tick on 15-90s timers, so invisible) and the tracked
#           entity set is up to 1s stale.
#   lines 21-22 per-tick player stuff
#
# v25: adds the weather and random-event systems (fart rain, gas surge, cyclone,
# blessing, swarm) ported in from an independent fork. Version numbers 21-24 were
# never used; see BUGS-AND-FIXES.md.
execute unless score #loaded fart.var matches 25 run function fartpack:core/bootstrap
scoreboard players enable @a fart.toggle
execute as @a[scores={fart.toggle=1..}] run function fartpack:core/do_toggle
execute as @a[scores={fart.toggle=1..}] run scoreboard players set @s fart.toggle 0
execute if score #enabled fart.var matches 0 run return 0
function fartpack:world/tick
execute as @a[name=!"Server"] unless entity @s[tag=fart.has_pid] at @s run function fartpack:core/assign_pid
execute as @a[name=!"Server",tag=fart.has_pid] run function fartpack:bar/tick_gas_bar
scoreboard players add #scan_c fart.var 1
execute if score #scan_c fart.var matches 1 as @a[name=!"Server"] at @s run function fartpack:blocks/scan_low
execute if score #scan_c fart.var matches 10 as @a[name=!"Server"] at @s run function fartpack:blocks/scan_mid
execute if score #scan_c fart.var matches 20 as @a[name=!"Server"] at @s run function fartpack:blocks/scan_high
execute if score #scan_c fart.var matches 1 run function fartpack:world/etick
execute if score #scan_c fart.var matches 10 run function fartpack:world/etick
execute if score #scan_c fart.var matches 20 run function fartpack:world/etick
execute if score #scan_c fart.var matches 30 as @e[type=minecraft:marker,tag=fart.blocktimer] at @s unless block ~ ~ ~ #fartpack:utility run kill @s
execute if score #scan_c fart.var matches 10 as @a[name=!"Server"] at @s run function fartpack:player/fill_gas
execute if score #scan_c fart.var matches 20 as @a[name=!"Server"] at @s run function fartpack:player/fill_gas
execute if score #scan_c fart.var matches 30 as @a[name=!"Server"] at @s run function fartpack:player/fill_gas
# Weather and event countdowns. These add 30 per call to compensate for this
# cycle's 30-tick period, so the 5-10 minute rain delay and the 20-40 minute
# event delay are unchanged. Placed on tick 10 rather than 30 because tick 30
# already carries the marker reaper and a fill_gas pass.
execute if score #scan_c fart.var matches 10 run function fartpack:world/fart_rain_tick
execute if score #scan_c fart.var matches 10 run function fartpack:world/fart_event_tick
execute if score #scan_c fart.var matches 30 run scoreboard players set #scan_c fart.var 0
execute as @a[name=!"Server"] if score @s fart.slow matches 1.. run scoreboard players remove @s fart.slow 1
execute as @a[name=!"Server"] at @s run function fartpack:player/press
