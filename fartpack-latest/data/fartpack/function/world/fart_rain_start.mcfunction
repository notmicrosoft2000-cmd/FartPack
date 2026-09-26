scoreboard players set #rain_cd fart.var 0
execute store result score #rain_target fart.var run random value 6000..12000
scoreboard players set #raining fart.var 1
scoreboard players set #rain_tick fart.var 0
execute store result score #rain_dur fart.var run random value 400..800
tellraw @a [{"text":"\u2601 ","color":"gray"},{"text":"A putrid front is rolling in... ","color":"green"},{"text":"FART RAIN incoming!","color":"gold","bold":true}]
playsound minecraft:weather.rain ambient @a ~ ~ ~ 1.0 0.6
playsound fartpack:fart.burp ambient @a ~ ~ ~ 1.0 0.5
