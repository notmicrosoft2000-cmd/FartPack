# Drain rate is configurable per player (admin/rel). `operation -=` is used
# rather than `players remove` because the amount has to come from a scoreboard
# holder, and `players remove` only takes an integer literal.
#
# The old two lines were an if/else that removed 1 and special-cased pressure
# being exactly 1. `operation -=` then a clamp at 0 is the same thing without
# the special case, and it is what lets the amount be a player's own setting.
# At the stock rel of 1 this is exactly equivalent: 1 becomes 0, 2 becomes 1.
# v30: the crouch heal is paid for out of gas genuinely expelled, and this is
# the only line in the pack allowed to pay for it. It lives here, next to the
# line that actually deducts the gas, so "gas expelled" cannot drift away from
# "gas deducted".
#
# The expelled amount is measured as before-minus-after rather than assumed to be
# @s fart.rel, because the clamp on the next line falsifies that assumption: at
# 1 gas left, fart.rel of 1 would take the tank to 0 and expel NOTHING, yet a
# flat credit would pay a whole tick's healing for it. That is not a corner
# case, it is the common case - with #famt at 0 (player/fill_gas only produces
# while the player MOVES) a stationary crouch makes the tank oscillate
# 0,1,2,0,1,2, so roughly a third of all crouch ticks expel nothing at all.
# Measured, and a flat credit overstated every crouch heal by about half.
scoreboard players operation @s fart.presspre = @s fart.pressure
scoreboard players operation @s fart.pressure -= @s fart.rel
execute if score @s fart.pressure matches ..0 run scoreboard players set @s fart.pressure 0
# expelled gas = presspre - pressure, so the bank is credited with `+= presspre`
# and debited with `-= pressure`. The order is the whole trick and it is easy to
# write backwards: `healgas -= presspre` then `+= pressure` computes
# pressure - presspre, which is the NEGATIVE of the gas expelled, and a bank
# that only ever falls means the heal can never be paid for. This was written
# backwards first and caught by arithmetic, not by a gate.
#
# It also works from a cold start, which is why fart.healgas needs no bootstrap
# seeding: an unset score reads as 0 to `operation`, so the first tick's
# `-= pressure` alone cannot leave a stranded negative value.
scoreboard players operation @s fart.healgas += @s fart.presspre
scoreboard players operation @s fart.healgas -= @s fart.pressure
effect give @s minecraft:glowing 2 0 true
particle minecraft:campfire_cosy_smoke ~ ~0.3 ~ 0.2 0.1 0.2 0.005 2
scoreboard players add @s fart.sndt 1
execute if score @s fart.sndt matches 15.. run playsound minecraft:entity.player.burp player @s ~ ~ ~ 0.5 0.35
execute if score @s fart.sndt matches 15.. run playsound fartpack:fart.burp player @s ~ ~ ~ 0.6 1.0
execute if score @s fart.sndt matches 15.. run scoreboard players set @s fart.sndt 0
execute unless entity @s[tag=fart.sneak] run scoreboard players set @s fart.sndt 0
execute if score @s fart.pressure matches 0 run function fartpack:player/release_done
execute at @s run function fartpack:push/release
