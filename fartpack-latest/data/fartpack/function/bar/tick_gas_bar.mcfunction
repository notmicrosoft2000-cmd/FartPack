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
# v33: THE LIVE PERCENTAGE ON THE BAR NAME. Computed here, in the per-player
# function, because this is the only place that has both the entity and the pid.
#
#   #pct = pressure * 100, then #pct /= cap   ->  an integer 0-100
#
# `scoreboard players operation` cannot multiply by a literal, so the 100 is
# `#rc_hundred`, a real score. Division is against a SCRATCH copy of the cap rather
# than the cap itself, because `/=` takes its divisor from a score and the cap is
# per-player - reading it into `#pct_cap` first keeps the divisor a fake player and
# avoids depending on `$(cap)` being substituted correctly inside a nested macro.
#
# `fart.pct` is stored back on the PLAYER (not a global) so it survives between the
# compute and the name-set, which happen in different files. The comparison against
# `fart.pct_shown` gates the name-set: a bossbar name is frozen until re-set
# (measured - the name kept a stale value), so it must be re-set to track, but only
# when the rounded integer percent has actually moved. A player sitting still at 63%
# costs one failed comparison per tick and zero bossbar commands.
execute store result score #pct_cap fart.var run scoreboard players get @s fart.cap
scoreboard players set #rc_hundred fart.var 100
scoreboard players operation @s fart.pct = @s fart.pressure
scoreboard players operation @s fart.pct *= #rc_hundred fart.var
execute unless score #pct_cap fart.var matches 1.. run scoreboard players set @s fart.pct 0
execute if score #pct_cap fart.var matches 1.. run scoreboard players operation @s fart.pct /= #pct_cap fart.var
# Clamp: pressure can exceed cap for the tick before release_gas runs, and the
# multiply/divide round can land on 101 for a full bar. A bar reading 101% is a
# small lie that a player WILL notice, so it is pinned to 100.
execute if score @s fart.pct matches 101.. run scoreboard players set @s fart.pct 100
execute if score @s fart.pct matches ..-1 run scoreboard players set @s fart.pct 0
# The `pct_shown` bookkeeping lives HERE rather than in bar/update_gas_bar, and the
# reason is the macro rule (#12): every line of a macro function must reference a
# macro variable or the loader drops the whole file. The `fart.pct_shown` store
# references neither `$(pid)` nor `$(cap)`, so putting it in the macro made the
# file vanish at load time - and it would have been a SILENT failure, taking the
# bar's name with it. This file is a plain function, so it has no such rule.
#
# It runs AFTER the two macro calls, so `pct_shown` is stamped to the value the
# name was just set from. Set unconditionally: it is idempotent, and gating it
# would need a second comparison for no benefit - the value it writes is the value
# the name now shows either way.
function fartpack:bar/ensure_bar with storage fartpack:data macro
function fartpack:bar/update_gas_bar with storage fartpack:data macro
scoreboard players operation @s fart.pct_shown = @s fart.pct
