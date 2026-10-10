scoreboard players set #rain_cd fart.var 0
execute store result score #rain_target fart.var run random value 6000..12000
scoreboard players set #raining fart.var 1
scoreboard players set #rain_tick fart.var 0
execute store result score #rain_dur fart.var run random value 400..800
# v28: /title as well as chat. A chat line is easy to scroll past and impossible
# to notice if you are looking at a mob; a title owns the middle of the screen.
# Both are kept - the title is what you notice, the chat line is what you can
# find again later in the scrollback.
title @a title [{"text":"FART RAIN","color":"green","bold":true}]
title @a subtitle [{"text":"A putrid front is rolling in","color":"yellow"}]
tellraw @a [{"text":"\u2601 ","color":"gray"},{"text":"A putrid front is rolling in... ","color":"green"},{"text":"FART RAIN incoming!","color":"gold","bold":true}]
playsound minecraft:weather.rain ambient @a ~ ~ ~ 1.0 0.6
playsound fartpack:fart.burp ambient @a ~ ~ ~ 1.0 0.5
