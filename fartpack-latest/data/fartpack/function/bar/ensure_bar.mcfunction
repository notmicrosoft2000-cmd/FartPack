# bar/ensure_bar - self-heal the gas bossbar.
# Bossbars are runtime-only (a server restart wipes them) while player tags and
# scores persist, so existence MUST be probed - a player tag cannot be trusted.
# A failed `bossbar get` stores 0, which is exactly the "missing" sentinel, and a
# present bar stores its max (100). No pre-seed/reset is needed: the probe always
# overwrites #eb_tmp first, and one shared scratch name avoids leaking a
# #eb<pid> row per player.
#
# v26: the bar is created at the player's own cap rather than the constant 100.
# `$(cap)` is written into the macro storage by bar/tick_gas_bar, which must be
# the CALLER rather than a line in here: a macro function is fully expanded
# before any of its lines run, so a `store result storage ... macro.cap` in this
# same file would execute long after `$(cap)` had already been substituted, and
# every bar would be sized from the previously-processed player. This is the
# same reason the file cannot write its own pid.
#
# Note that max is only set in the CREATION branch on purpose: this function
# runs every tick for every player, and an unconditional `bossbar set ... max`
# here would be per-tick cost. Resizing an existing bar is admin/set_max's job,
# called from admin/cap.
$execute store result score #eb_tmp fart.var run bossbar get fartpack:gas_$(pid) max
$execute if score #eb_tmp fart.var matches 0 run bossbar add fartpack:gas_$(pid) {"text":"Gas Pressure","color":"yellow"}
$execute if score #eb_tmp fart.var matches 0 run bossbar set fartpack:gas_$(pid) max $(cap)
$execute if score #eb_tmp fart.var matches 0 run bossbar set fartpack:gas_$(pid) color yellow
$execute if score #eb_tmp fart.var matches 0 run bossbar set fartpack:gas_$(pid) players @s
