# admin/set_max - resize an existing gas bossbar to match a changed cap.
#
# Macro. Invoked with `with storage fartpack:data macro`, which the caller fills
# with `pid` (the player's fart.pid) and `cap` (the bar cap).
#
# Why this exists separately: bar/ensure_bar only ever sets `max` in the branch
# that CREATES a bar, because that branch runs once per player and the pack
# cares a great deal about per-tick cost - bar/tick_gas_bar runs every tick for
# every player. So when an admin changes somebody's cap after their bar already
# exists, nothing would tell the bar about it, and the bossbar would still read
# 0-100 while the scoreboard said 0-200.
#
# The probe is the same trick ensure_bar uses: `bossbar get` on a bar that does
# not exist stores 0, so `unless matches 0` is a reliable "it exists" test. It
# also means running this before the player's first bar is created is harmless.
$execute store result score #smax_tmp fart.var run bossbar get fartpack:gas_$(pid) max
$execute unless score #smax_tmp fart.var matches 0 run bossbar set fartpack:gas_$(pid) max $(cap)
