# admin/rel - set how fast a crouching player empties their bar.
#
#   /function fartpack:admin/rel Steve 3
#
# 1 is stock: one point of pressure per tick, so a full bar empties in two
# seconds. Higher is faster. This is the drain side of the same trade the fill
# rate controls, and it is deliberately independent - a player can be given a
# bar that fills fast and drains slow, which is a completely different feel
# from one that does both fast, and neither has to touch the other.
#
# The clamp is at 0 rather than 1: a value of 0 would mean the bar never
# empties and the release would never finish, which is a soft-lock on the
# player's own crouch, so the floor is 1.
$scoreboard players set $(arg0) fart.rel $(arg1)
$execute if score $(arg0) fart.rel matches ..0 run scoreboard players set $(arg0) fart.rel 1
$execute if score $(arg0) fart.rel matches 11.. run scoreboard players set $(arg0) fart.rel 10
$execute store result score #rc_echo fart.var run scoreboard players get $(arg0) fart.rel
$tellraw $(arg0) [{"text":"[FartPack] ","color":"green"},{"text":"release drains ","color":"gray"},{"score":{"name":"#rc_echo","objective":"fart.var"},"color":"gold","bold":true},{"text":" per tick while crouching (1-10)","color":"dark_gray"}]
