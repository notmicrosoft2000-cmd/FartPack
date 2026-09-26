# admin/reset - put one player back to stock FartPack numbers.
#
#   /function fartpack:admin/reset Steve
#
# Everything admin/rate, admin/every, admin/cap, admin/rel and admin/pow set is
# absolute and idempotent, so this is mostly just admin/defaults run against
# somebody else.
#
# Two things have to happen outside admin/defaults:
#
#   * the bossbar has to be resized back to 100, which admin/defaults cannot do
#     because it knows nothing about the pid - hence admin/resync_bar, called
#     through `execute as` so that this line carries the $(arg0) the macro rule
#     requires. For an offline player there is no bar and nothing is needed.
#
#   * their current pressure is dropped to 0, because somebody reset from a
#     200 cap while sitting at 150 would otherwise be over their new maximum
#     until the next fill pass clamped them - and a player deliberately sitting
#     on a full bar would be hit by the forced legendary fart in the meantime.
$execute as $(arg0) run function fartpack:admin/defaults
$execute as $(arg0) run function fartpack:admin/resync_bar
$scoreboard players set $(arg0) fart.pressure 0
$tellraw $(arg0) [{"text":"[FartPack] ","color":"green"},{"text":"reset to stock. Fill 1x, cap 100, release 1/tick, knockback 30.","color":"gray"}]
