# admin/rate - set how fast one player's gas bar fills.
#
#   /function fartpack:admin/rate Steve 2
#
# 0 = the bar never fills on its own (you can still crouch-release and everything
# else works). 1 = stock. 2-5 = that many times the normal fill per pass.
#
# The value is clamped rather than rejected. A macro function cannot take a
# conditional branch on the literal text of an argument, and an admin who types
# 9 clearly wants a big number, not an error message - so 9 becomes 5 and the
# read-back at the bottom tells them what actually landed. Note that every
# non-comment line here contains a $(arg) on purpose: a macro function with a
# line that references no variable is rejected wholesale by the loader with
# "No variables in macro" and the entire file silently stops existing (#12).
$scoreboard players set $(arg0) fart.rate $(arg1)
$execute if score $(arg0) fart.rate matches ..-1 run scoreboard players set $(arg0) fart.rate 0
$execute if score $(arg0) fart.rate matches 6.. run scoreboard players set $(arg0) fart.rate 5
$execute store result score #rc_echo fart.var run scoreboard players get $(arg0) fart.rate
$tellraw $(arg0) [{"text":"[FartPack] ","color":"green"},{"text":"gas fill rate set to ","color":"gray"},{"score":{"name":"#rc_echo","objective":"fart.var"},"color":"gold","bold":true},{"text":"  (0 frozen, 1 normal, 5 max)","color":"dark_gray"}]
