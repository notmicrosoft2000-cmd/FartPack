# admin/resync_bar - resize this player's gas bossbar to match their current cap.
#
# A PLAIN function, not a macro, and that is the whole point of it. It exists so
# that admin/cap and admin/reset can do their bossbar work through a single
# `execute as <player> run function` line - a line that already contains a
# $(arg0) - instead of trying to perform the work inside the macro itself.
#
# Why that matters: in a macro function, `$` marks a line as a macro line and
# every macro line must contain at least one variable, or the datapack loader
# rejects the ENTIRE file with "No variables in macro" and the function silently
# does not exist (#12). Neither `function ... with storage ... macro` nor
# `scoreboard players set #rc_four ... 4` can carry a $(arg), so both had to
# move out here, where lines need no marker and no variable.
#
# `execute as` only resolves for an online player, and that is correct rather
# than a limitation: a bossbar only exists while somebody is connected, so an
# offline player has nothing to resize, and bar/ensure_bar creates their bar at
# the right size on their next join because it now reads the cap instead of a
# constant. The offline-critical half of admin/cap - deriving fart.leg and
# fart.warn - deliberately does NOT come through here, because those are
# scoreboard values that persist and would otherwise be left stale.
execute store result storage fartpack:data macro.pid int 1 run scoreboard players get @s fart.pid
execute store result storage fartpack:data macro.cap int 1 run scoreboard players get @s fart.cap
function fartpack:admin/set_max with storage fartpack:data macro
