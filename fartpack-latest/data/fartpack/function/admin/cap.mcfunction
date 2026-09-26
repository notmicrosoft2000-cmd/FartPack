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
$scoreboard players operation $(arg0) fart.warn = $(arg0) fart.cap
$scoreboard players operation $(arg0) fart.warn /= #rc_four
$execute if score $(arg0) fart.pressure > $(arg0) fart.cap run scoreboard players operation $(arg0) fart.pressure = $(arg0) fart.cap
$execute as $(arg0) run function fartpack:admin/resync_bar
$execute store result score #rc_echo fart.var run scoreboard players get $(arg0) fart.cap
$execute store result score #rc_echo2 fart.var run scoreboard players get $(arg0) fart.warn
$tellraw $(arg0) [{"text":"[FartPack] ","color":"green"},{"text":"bar cap set to ","color":"gray"},{"score":{"name":"#rc_echo","objective":"fart.var"},"color":"gold","bold":true},{"text":"  - full bar and legendary now fire at that, hunger from ","color":"gray"},{"score":{"name":"#rc_echo2","objective":"fart.var"},"color":"gold"},{"text":".","color":"gray"}]
