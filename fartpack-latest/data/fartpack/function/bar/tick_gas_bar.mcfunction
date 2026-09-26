# bar/tick_gas_bar - per-tick bossbar upkeep for one player.
#
# The two macro calls need pid and cap in storage. Both are written HERE, by the
# caller, and not inside the macros themselves: a macro function is expanded in
# full before any of its lines execute, so a macro that wrote its own pid or cap
# would have already had $(pid) / $(cap) substituted from the PREVIOUS player's
# values. Since tick_gas_bar walks players one at a time, that would size every
# bar from whoever was processed before them.
execute store result storage fartpack:data macro.pid int 1 run scoreboard players get @s fart.pid
execute store result storage fartpack:data macro.cap int 1 run scoreboard players get @s fart.cap
function fartpack:bar/ensure_bar with storage fartpack:data macro
function fartpack:bar/update_gas_bar with storage fartpack:data macro
