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
#
# v26: adds the per-player config layer - admin/rate, admin/every, admin/cap,
# admin/rel, admin/pow, admin/reset, admin/show - so gas speed, bar size, drain
# rate and knockback can be set per player with /function. This costs one extra
# command per player per tick (bar/tick_gas_bar has to hand the cap to the
# bossbar macro) and two comparisons per gas pass; it adds no entity selectors.
# v27: repairs v26, which shipped with two files that failed to load
# (player/apply_gas and admin/recalc, both from a missing source objective in a
# `scoreboard players operation`) and so silently stopped the gas bar filling.
# No behavioural change beyond that; the version bump exists so bootstrap
# re-derives the cap-relative thresholds for anyone v26 left half-configured.
# v28: the user's bug list, all in one deploy. Each line says where it lives.
#   green fart rain            world/fart_rain_active      (was grey smoke + nausea)
#   yellow/green clouds        clouds/*                    (was arbitrary colours)
#   no hunger                  player/press, world/fart_forced
#   crouch pushes players      push/player, push/player_cd  (was Motion, which the
#                              engine discards for players - see push/player)
#   crouch heals 1 HP/sec      player/press               (was 1 HP per 2.5s)
#   2 hearts/sec on empty tank player/stress_hurt          (was 0.5 hearts/sec)
#   bar does not fill standing player/fill_gas              (which is what made the
#                              empty tank reachable, and so made the line above
#                              reachable too)
#   events announced loudly    world/event_*, world/fart_rain_*, player/stress_hurt,
#                              world/fart_forced, clouds/legendary   (via /title)

# v34 (was 33): the bump exists so core/bootstrap runs again on the live world and
# creates fart.nofill. Both numbers must move together - the gate here and the
# `set #loaded` at the bottom of core/bootstrap - or the pack silently keeps the
# old objectives and the tonic's countdown has nowhere to live.
execute unless score #loaded fart.var matches 34 run function fartpack:core/bootstrap
scoreboard players enable @a fart.toggle
# v33: the four `scoreboard players enable @a fart.p*` lines are DELETED with the
# profile system. They cannot stay: `enable` against an objective that no longer
# exists is a command error, and this file runs every tick, so it would be a
# permanent error spam rather than one line in a log. A player who set a profile
# under v31 still HAS those objectives on the live server (a datapack cannot
# un-create one) and this line is what stops them being able to type /trigger into
# them, which is the correct outcome - nothing reads the values any more.
execute as @a[scores={fart.toggle=1..}] run function fartpack:core/do_toggle
execute as @a[scores={fart.toggle=1..}] run scoreboard players set @s fart.toggle 0
execute if score #enabled fart.var matches 0 run return 0
function fartpack:world/tick
execute as @a[name=!"Server"] unless entity @s[tag=fart.has_pid] run function fartpack:core/on_join
execute as @a[name=!"Server"] unless entity @s[tag=fart.has_pid] at @s run function fartpack:core/assign_pid
# v33: `function fartpack:profile/triggers` USED TO BE HERE, and the v31 note
# explaining its careful placement is deleted with it. It sat after the `return 0`
# above (so the pack's kill switch also stopped profiles) and after
# core/assign_pid (so a profile could be set on a player's first tick). Both
# reasons were real; the feature they served is gone. admin/defaults, run by
# core/assign_pid, is now the only thing that sets a player's rate/cap/pow.
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
execute if score #scan_c fart.var matches 20 run function fartpack:king/crown
# v33: the profile nag clock (profile/remind) is DELETED with the profile system.
# It shared this tick with king/crown so it cost no extra scheduling; there is
# nothing left to nag about.
execute if score #scan_c fart.var matches 10 run function fartpack:world/fart_rain_tick
execute if score #scan_c fart.var matches 10 run function fartpack:world/fart_event_tick
execute if score #scan_c fart.var matches 30 run scoreboard players set #scan_c fart.var 0
execute as @a[name=!"Server"] if score @s fart.slow matches 1.. run scoreboard players remove @s fart.slow 1
# v34: the tonic's own timer, ticked down alongside the kibble's. It is a
# SEPARATE countdown from fart.slow on purpose: the kibble fills at a 1-in-100
# roll and the tonic blocks fill outright, so they cannot be one holder (see
# player/fill_gas). One decrement each, per tick, for every player but Server.
execute as @a[name=!"Server"] if score @s fart.nofill matches 1.. run scoreboard players remove @s fart.nofill 1
execute as @a[name=!"Server"] at @s run function fartpack:player/press
