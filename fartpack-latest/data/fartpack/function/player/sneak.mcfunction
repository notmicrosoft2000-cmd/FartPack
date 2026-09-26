# player/sneak - vanilla has no "is this entity crouching" selector, so this uses
# the only signal that exists: the eye anchor height.
#
# Standing puts the eye anchor at 1.62 above the feet; sneaking puts it at
# exactly 1.27. Walking the anchor back down by 1.27 therefore lands on the
# player's own feet position ONLY while sneaking, so "is there an entity within
# 0.2 of this point" is a crouch test. Standing leaves the probe 0.35 above the
# feet, which is comfortably outside 0.2.
#
# FRAGILE BY NATURE. This breaks if anything changes eye height - notably the
# minecraft:player_scale attribute, or a mod that alters sneaking. If crouch to
# release ever stops working, this file is the first place to look.
execute at @s anchored eyes positioned ^ ^ ^ positioned ~ ~-1.27 ~ if entity @s[distance=..0.2] run tag @s add fart.sneak
execute at @s anchored eyes positioned ^ ^ ^ positioned ~ ~-1.27 ~ unless entity @s[distance=..0.2] run tag @s remove fart.sneak
