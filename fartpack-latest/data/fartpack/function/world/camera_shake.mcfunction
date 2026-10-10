# v29: an actual shake, and an honest record of why it is nausea and not rotation.
#
# WHAT WAS HERE: one line, `effect give @a[...distance=..3] minecraft:nausea 2 0`.
# Duration 2 ticks, amplifier 0, farter excluded. That is a tenth of a second of
# the mildest wobble, applied to bystanders only - the person who actually farted
# felt nothing. The user was right that this was not a camera shake.
#
# WHY IT IS STILL NAUSEA, which is the part worth reading before trying again.
# The obvious implementation is to jitter the player's Rotation, and I tried to
# make that work. Five distinct mechanisms were measured on this server and all
# five are dead ends, so nobody should spend another day rediscovering them:
#
#   tp <t> ~ ~ ~ #scoreholder ~   runtime error, "Incorrect argument for command"
#                                RotationArgument is a plain double; unlike the
#                                x/y/z slots it does not accept a score holder
#   tp <t> ~ ~ ~ $(macro) ~       the function will not even LOAD:
#                                "Whilst parsing command on line 1: Incorrect
#                                argument for command at position 6: tp @s"
#   tp <t> ~ ~ ~ 47.0 ~           works, but nothing can compute the 47.0
#   data merge entity <t>         works, and is the only one that does:
#     {Rotation:[47.0f,-20.0f]}   seed 45/-20 -> read back exactly [47.0f,-20.0f],
#                                pitch preserved. But it needs a literal, and
#                                the yaw has to be read from the player first
#   data merge entity <t>         the function will not LOAD:
#     {Rotation:[$(macro).0f,..]}  "Expected literal B at position 32", i.e. a
#                                macro is not accepted inside the NBT list
#
# So: macros work inside NBT in some commands (the live pack's heal path merges
# $(hp) into Health) and inside JSON text, but never in a coordinate, a rotation,
# or an NBT list element. Both ends of the computation are unavailable, which is
# why the Rotation approach is impossible here rather than merely awkward. Same
# family as bug #32.
#
# Nausea is therefore not a fallback because it is the nice option - it is the
# only camera-wobbling lever a datapack has on this server. What v29 changes is
# that it is actually turned up: it now reaches the farter, it lasts 1 to 2
# seconds instead of a fifth of one, and it scales with the fart's own power
# score, so a boss fart hits like a boss and a rabbit fart barely registers.
#
# TUNING: the six numbers below are the whole effect. v29 shipped them at
# 20/0, 30/1 and 40/2 for the farter and 15/0, 20/0, 30/1 for bystanders. v30
# roughly halves every one of them and drops the top rung from amplifier 2 to
# amplifier 1.
#
# The amplifier is what actually matters and the durations were the smaller half
# of the problem. Nausea amplifier 2 is the screen-warping tier - the view
# swims and the field of view lurches - and 40 ticks of it is two full seconds.
# That is the number players complained about, and it was being applied to the
# person who did the farting, which is the worst possible recipient: they chose
# to fart, they did not choose to be made ill. So the top rung is now 24/1, and
# the farter's worst case is about a third of the old dose in strength terms.
#
# Bystanders are cut harder (30 -> 16) than the farter (40 -> 24) because being
# nearby should be a wobble you can still fight in, not a fight you lose.
# Nausea I is 15/0 in v29 for a bystander and is now 8/0.
#
# NOT VERIFIED: the world is paused at zero players, so how any of this LOOKS
# cannot be checked from here. What is verified is that every one of these
# commands is accepted and that the amplifier and duration asked for are the
# ones the server applies. The feel needs a human. If it is still too much, the
# amplifier 1 rungs are the ones to delete - a missing rung falls back to the
# unconditional base dose, so deleting one degrades the effect instead of
# breaking it.

# --- the farter, who is @s: the function is called from world/fart_entity and
# --- from world/fart_forced, both of which leave @s as the farter.
# Base dose first, unconditionally, so a fart always registers even if fart.pow
# was never set on that entity. The lines below then upgrade it, and a second
# `effect give` for an effect the target already has replaces the first - so
# this is a floor with rungs on it, not a gap where a big fart feels nothing.
effect give @s minecraft:nausea 12 0
execute if score @s fart.pow matches 51..150 run effect give @s minecraft:nausea 18 0
execute if score @s fart.pow matches 151.. run effect give @s minecraft:nausea 24 1

# --- bystanders within 3 blocks, one dose rung below the farter
effect give @a[name=!"Server",distance=..3] minecraft:nausea 8 0
execute if score @s fart.pow matches 51..150 run effect give @a[name=!"Server",distance=..3] minecraft:nausea 12 0
execute if score @s fart.pow matches 151.. run effect give @a[name=!"Server",distance=..3] minecraft:nausea 16 0
