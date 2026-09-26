# core/bootstrap - full initializer. Bump the version at the bottom whenever an
# objective is added or removed; tick.mcfunction runs this on a version mismatch
# so new objectives actually get created on an existing world.
scoreboard objectives add fart.cooldown dummy
scoreboard objectives add fart.target dummy
scoreboard objectives add fart.var dummy
scoreboard objectives add fart.pressure dummy
scoreboard objectives add fart.stress dummy
scoreboard objectives add fart.pid dummy
scoreboard objectives add fart.slow dummy
scoreboard objectives add fart.lastx dummy
scoreboard objectives add fart.lastz dummy
scoreboard objectives add fart.hurtt dummy
scoreboard objectives add fart.gtick dummy
scoreboard objectives add fart.sndt dummy
scoreboard objectives add fart.total dummy {"text":"Total Farts","color":"gold"}
scoreboard objectives add fart.toggle trigger
# Per-player config (v26). These are the knobs admin/* expose. All of them have a
# fail-safe default that reproduces the pre-v26 behaviour when UNSET, so a player
# who somehow never gets initialised still fills and drains at stock speed -
# see player/apply_gas for the specific trap that "unset" and "0" look identical
# to a scoreboard, and why `fart.has_cfg` exists to tell them apart.
scoreboard objectives add fart.rate dummy
scoreboard objectives add fart.every dummy
scoreboard objectives add fart.cyc dummy
scoreboard objectives add fart.cap dummy
scoreboard objectives add fart.leg dummy
scoreboard objectives add fart.warn dummy
scoreboard objectives add fart.rel dummy
scoreboard objectives add fart.pow dummy
scoreboard players enable @a fart.toggle
scoreboard players set #neg1 fart.var -1
# The constant 4, used to turn a bar cap into a quarter-of-full hunger warning.
# Seeded here because admin/cap's macro cannot set it - a macro line has to
# carry a $(arg) and `set #rc_four ... 4` has nowhere to put one. admin/recalc
# re-seeds it too, so the two paths cannot drift.
scoreboard players set #rc_four fart.var 4
scoreboard players set #noplayer fart.var 0
scoreboard players set #scan_c fart.var 0
scoreboard players set #rc fart.var 0
scoreboard players set #stats fart.total 0
# Weather and event state (v25). Every one of these is a fake player on fart.var.
#
# They are seeded here rather than left to first use so the state is readable with
# a plain `scoreboard players get` on a fresh world. #rain_target and
# #event_target are deliberately left UNSET: both countdown functions test
# `matches 1..` to mean "not chosen yet", and an unset score does not match that,
# so a 0 would be a legal-looking target and the storm would fire instantly.
# Do not initialise them to 0.
scoreboard players set #raining fart.var 0
scoreboard players set #rain_c fart.var 0
scoreboard players set #rain_cd fart.var 0
scoreboard players set #rain_dur fart.var 0
scoreboard players set #rain_tick fart.var 0
scoreboard players set #event_cd fart.var 0
scoreboard players set #event_pick fart.var 0
execute unless score #enabled fart.var matches 0 run scoreboard players set #enabled fart.var 1
scoreboard objectives setdisplay sidebar fart.total
# v26: give stock config to exactly the players who have none.
#
# The tag test, not a value test. `fart.rate 0` (frozen) and "never set" are both
# invisible to `matches 1..`, so checking scores would either re-freeze a player
# somebody deliberately froze, or skip a player who needs initialising - and the
# second one is the dangerous direction, because an uninitialised player has a
# bar that never fills.
#
# This is also the reason the version gate exists at all: adding the objectives
# above is not enough on a world that already has players, and a version bump is
# what makes this line run exactly once per upgrade rather than every tick.
execute as @a[tag=fart.has_pid,tag=!fart.has_cfg] run function fartpack:admin/defaults
data modify storage fartpack:data macro set value {}
scoreboard players set #loaded fart.var 26
