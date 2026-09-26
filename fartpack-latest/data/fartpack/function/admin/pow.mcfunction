# admin/pow - set how hard one player shoves other things on release.
#
#   /function fartpack:admin/pow Steve 80
#
# Units are 1/100 blocks per tick of horizontal impulse, and the value is scaled
# down by distance, so 30 (stock) throws a mob across a room and 80 throws it
# across the room and out of it. 0 disables the shove entirely while leaving the
# fart itself - sound, particles, gas cloud, healing - completely intact.
#
# This is the number that decides whether OTHER PLAYERS get knocked back, which
# since v25 they do: push/release used to set #noplayer 1 and strip every player
# out of the push target set, so a person's crouch fart could not move a person
# while a sheep's could (#28). This is the knob for tuning how far.
#
# It does NOT change the upward component, which stays at the stock 20, and it
# does not touch the self-shove from relieving pressure (a fixed 24 in
# player/press). Those are deliberately left alone: the self-shove is what sells
# the release, and tying it to a config value would mean a player with pow 0 also
# stopped being pushed by their own fart, which is a different change to make.
$scoreboard players set $(arg0) fart.pow $(arg1)
$execute if score $(arg0) fart.pow matches ..-1 run scoreboard players set $(arg0) fart.pow 0
$execute if score $(arg0) fart.pow matches 201.. run scoreboard players set $(arg0) fart.pow 200
$execute store result score #rc_echo fart.var run scoreboard players get $(arg0) fart.pow
$tellraw $(arg0) [{"text":"[FartPack] ","color":"green"},{"text":"knockback power set to ","color":"gray"},{"score":{"name":"#rc_echo","objective":"fart.var"},"color":"gold","bold":true},{"text":"  (0-200, 30 normal)","color":"dark_gray"}]
