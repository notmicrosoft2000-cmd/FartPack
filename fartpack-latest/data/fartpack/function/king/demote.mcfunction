# king/demote - someone else farted harder. Runs once, for the old king only.
#
# Every line here is the exact inverse of a line in king/crowned, and the pairing
# is the thing to check. A demotion that forgets one leaves the old king with
# 4 bonus hearts and no crown, which is worse than never having crowned them.
#
# The hearts come off with `effect clear`, not with an `attribute` write, because
# `attribute ... set` parses and does nothing on this server - see the measured
# table in king/crowned. `effect clear` is verified to drop max_health straight
# back to its base. Clearing rather than letting the 400-tick effect lapse also
# means a demoted king is not visibly still boosted for another 20 seconds.
#
# v31: there is deliberately NO `fart.rate` line here any more, and its absence is
# the point. v30 demoted by writing rate 1, which was correct when rate only ever
# meant "1 normal, 2 king" - and wrong the moment a player's profile set it to
# something else, because a demotion would overwrite their profile with the
# default. The crown is now a tag, the double gas is a tag test in
# player/apply_gas, and removing the tag is the whole of the demotion's effect on
# gas. A demoted player keeps whatever profile they chose.
effect clear @s minecraft:health_boost
tag @s remove fart.king
title @s title [{"text":"DETHRONED","color":"gray","bold":true}]
title @s subtitle [{"text":"someone farted harder","color":"dark_gray"}]
playsound minecraft:block.beacon.deactivate player @s ~ ~ ~ 0.6 1.4
