tellraw @a [{"text":"\u2728 ","color":"yellow"},{"text":"A wave of SWEET RELIEF washes over the land...","color":"aqua"}]
playsound minecraft:entity.player.levelup ambient @a ~ ~ ~ 1.0 1.0
execute as @a[name=!"Server"] at @s run function fartpack:clouds/blessed
