# admin/cap - change how full "full" is for one player.
#
#   /function fartpack:admin/cap Steve 200
#
# Raising the cap does three things, and all three have to happen together or
# the config is quietly broken:
#
#   1. the fill clamp moves, so the bar stops at 200 instead of 100
#   2. the gas bossbar's max moves, so the bar is not stuck reading 0-100 while
#      the scoreboard says 0-200
#   3. the two thresholds that used to be hardcoded against the constant 100
#      are re-derived - the hunger warning and the point at which a full bar
#      fires the forced legendary mega-fart. admin/recalc does this for @s.
#
# Step 3 inlines admin/recalc, and step 2 is delegated to admin/resync_bar.
# Neither is decoration - both are forced by this file being a macro:
#
#   * recalc works on @s, and `execute as <name>` only resolves for an ONLINE
#     player. Routing the derivation through it would silently do nothing for an
#     offline player, so their cap would change while fart.leg stayed at 100 -
#     meaning a 200 cap fired the legendary mega-fart at half a bar, with no
#     error anywhere. Scoreboard operations work fine on offline holders, so the
#     arithmetic is done directly against $(arg0) instead, which is correct
#     whether they are online or not.
#
#   * the resync is the opposite case: it only matters for somebody who HAS a
#     bossbar, which only exists while they are connected. So it goes through
#     `execute as` and admin/resync_bar, which is a plain function - see that
#     file for why the work could not stay in here.
#
# The division is written straight onto the player rather than through a
# temporary, so that every line carries a $(arg0) and the file survives the
# loader's macro rule. #rc_four is the constant 4, seeded by core/bootstrap.
$scoreboard players set $(arg0) fart.cap $(arg1)
$execute if score $(arg0) fart.cap matches ..19 run scoreboard players set $(arg0) fart.cap 20
$execute if score $(arg0) fart.cap matches 501.. run scoreboard players set $(arg0) fart.cap 500
$scoreboard players operation $(arg0) fart.leg = $(arg0) fart.cap
# fart.near, the 80% near-full warning, and the re-derivation of fart.warn after
# it borrows warn as a scratch. Kept in step with admin/recalc BY HAND - this file
# cannot call that one, see the note at the top. #rc_five is seeded by
# core/bootstrap alongside #rc_four; both are re-set per call rather than trusted,
# because a missing constant here would divide by nothing without saying so.
# #rc_five is NOT re-set here, only consumed, because a `$scoreboard players set
# #rc_five fart.var 5` line would reference no macro variable and would make the
# loader drop this entire file (#12). The constant is seeded by core/bootstrap and
# re-seeded by admin/recalc, which is the same treatment #rc_four already gets in
# this file: used, never defined. An earlier version of this edit DID try to set it
# here, and checkmacro caught it - which is the gate doing the one job it exists
# for, on the one class of bug that is invisible until the file stops loading.
# THE SCRATCH IS `fart.warn`, NOT A FAKE PLAYER, and that is forced by #12: a macro
# line that references no macro variable makes the loader drop the whole file. The
# obvious spelling of 80% needs a scratch that is not the player -
# `#rc_tmp2 = $(arg0) cap` then `#rc_tmp2 /= #rc_five` - and the second of those
# lines mentions neither the player nor a macro var, so the file would vanish at
# load time and take the whole config layer with it. It is a SILENT failure: the
# admin commands are already unreachable (#32), so nothing would report it.
#
# So the fifth is borrowed, taken BEFORE the real value is written and put back
# immediately after. Every line below mentions $(arg0), the scratch lives on the
# player rather than in a global, and the ordering is load-bearing: warn is
# overwritten with the correct quarter-of-cap on the last line.
$scoreboard players operation $(arg0) fart.warn = $(arg0) fart.cap
$scoreboard players operation $(arg0) fart.warn /= #rc_five fart.var
$scoreboard players operation $(arg0) fart.near = $(arg0) fart.cap
$scoreboard players operation $(arg0) fart.near -= $(arg0) fart.warn
$scoreboard players operation $(arg0) fart.warn = $(arg0) fart.cap
$scoreboard players operation $(arg0) fart.warn /= #rc_four fart.var
$execute if score $(arg0) fart.pressure > $(arg0) fart.cap run scoreboard players operation $(arg0) fart.pressure = $(arg0) fart.cap
$execute as $(arg0) run function fartpack:admin/resync_bar
$execute store result score #rc_echo fart.var run scoreboard players get $(arg0) fart.cap
$execute store result score #rc_echo2 fart.var run scoreboard players get $(arg0) fart.warn
$tellraw $(arg0) [{"text":"[FartPack] ","color":"green"},{"text":"bar cap set to ","color":"gray"},{"score":{"name":"#rc_echo","objective":"fart.var"},"color":"gold","bold":true},{"text":"  - full bar and legendary now fire at that, hunger from ","color":"gray"},{"score":{"name":"#rc_echo2","objective":"fart.var"},"color":"gold"},{"text":".","color":"gray"}]
