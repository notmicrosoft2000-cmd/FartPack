title @a title [{"text":"GAS CYCLONE","color":"green","bold":true}]
title @a subtitle [{"text":"Tears through the area","color":"yellow"}]
tellraw @a [{"text":"\ud83c\udf00 ","color":"aqua"},{"text":"A GAS CYCLONE tears through the area!","color":"gold","bold":true}]
playsound minecraft:entity.phantom.ambient ambient @a ~ ~ ~ 1.0 0.4
execute as @a[name=!"Server"] at @s run function fartpack:world/event_cyclone_burst
