# admin/every - throttle one player's fill to 1 pass in N.
#
#   /function fartpack:admin/every Steve 2
#
# 1 = every pass (stock, does nothing on its own). 2 = fill on every other pass,
# so the bar takes twice as long. 4 = a quarter speed.
#
# This is the "slower" half of the speed control, and it is a separate knob from
# admin/rate on purpose: the two compose, so rate 2 + every 2 is exactly stock
# speed, and rate 3 + every 2 is 1.5x. A single percent knob could also express
# that, but it would need a per-player accumulator and a small emit loop on the
# tick path; an integer count and a 1-in-N counter cost one comparison.
$scoreboard players set $(arg0) fart.every $(arg1)
$execute if score $(arg0) fart.every matches ..0 run scoreboard players set $(arg0) fart.every 1
$execute if score $(arg0) fart.every matches 5.. run scoreboard players set $(arg0) fart.every 4
$execute store result score #rc_echo fart.var run scoreboard players get $(arg0) fart.every
$tellraw $(arg0) [{"text":"[FartPack] ","color":"green"},{"text":"gas fills 1 pass in ","color":"gray"},{"score":{"name":"#rc_echo","objective":"fart.var"},"color":"gold","bold":true},{"text":"  (1 = every pass)","color":"dark_gray"}]
