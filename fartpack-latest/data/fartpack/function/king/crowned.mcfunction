# king/crowned - the player has just become the Fart King. Runs once, on the
# tick king/crown hands over, for exactly one player.
#
# THREE advantages, and each one is a single line that can be deleted without
# touching the other two:
#
#   1. DOUBLE GAS. Not here any more. v29 and v30 wrote `fart.rate 2` from this
#      file; v31 moved it into player/apply_gas as a tag test, because profiles
#      own fart.rate and a demotion that reset it to 1 deleted the player's
#      profile. Same numbers on the gas bar, and it composes now.
#   2. health_boost II  - +6 hearts, so 16 hearts instead of 10. v31, up from I.
#   3. knockback x3 and
#      a 30-block radius instead of the usual 3-12. Applied in push/core, NOT
#      here, because push/core is the only place that knows what #radius means
#      and #radius is an enum of literals rather than a tunable - see the
#      comment there before assuming you can just make it bigger.
#
# THE TRADEOFF, because a crown that is only upside stops being a decision. The
# king's cost is the double gas itself, and it is a real cost rather than a bonus
# wearing a disguise: the bar fills twice as fast, which means the king is almost
# always holding a full bar, which means the king is CONSTANTLY releasing into
# whatever is nearby and cannot bank gas for one good hit. Everyone else chooses
# when to spend the bar. The king spends it continuously and gets a bigger radius
# out of it. That is the trade: reach and hearts for control of your own radius.
#
# WHY health_boost AND NOT `attribute`. The obvious spelling is
# `attribute @s minecraft:max_health set 30`, and on this server it is a trap
# twice over. Both `set` and `modify` are ACCEPTED - no error, clean load, green
# lint - and then do NOTHING. Measured on a live fixture: max_health read 10.0,
# was set to 30, and read 10.0 again; the same for `modify add 20`; the same for
# an attribute id that `get` reports as not existing at all. A command that
# parses and does nothing is worse than one that is rejected, because every gate
# in this repo says it worked.
#
# `effect give health_boost` is the vanilla mechanism for extra hearts and it
# genuinely works. Measured on the same fixture, max_health before and after:
#   none            10.0
#   health_boost 0  14.0     (+4 HP  = +2 hearts)
#   health_boost 1  18.0     (+8 HP  = +4 hearts)
#   health_boost 2  22.0     (+12 HP = +6 hearts)
#   effect clear    10.0     (restores cleanly)
# Note amplifier 0 is NOT "no bonus" - it is a real +2 hearts. So the king takes
# amplifier 2 for +6 hearts, and 16 is the number the title below advertises.
#
# The duration is 400 ticks (20s) and it is topped up once a second by
# king/crown, so it never lapses while the crown is held and never has to be
# reasoned about. king/demote clears it.
effect give @s minecraft:health_boost 400 2 true
tag @s add fart.king
title @a title [{"text":"FARTER KING ","color":"gold","bold":true},{"selector":"@s","color":"yellow"}]
title @a subtitle [{"text":"16 hearts, and everyone within 30 blocks flies","color":"gray"}]
playsound minecraft:block.beacon.activate player @a ~ ~ ~ 0.7 1.6
playsound minecraft:block.note_block.pling player @a ~ ~ ~ 0.7 2.0
