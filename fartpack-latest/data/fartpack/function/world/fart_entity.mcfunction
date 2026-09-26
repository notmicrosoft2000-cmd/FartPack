scoreboard players add #stats fart.total 1
execute unless entity @s[type=#fartpack:boss] run effect give @s minecraft:glowing 3 0 true
execute unless entity @s[type=#fartpack:boss] run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"selector":"@s"},{"text":" farted!","color":"yellow"}]
execute unless entity @s[type=#fartpack:boss] run function fartpack:world/fart_sound
execute unless entity @s[type=#fartpack:boss] run particle minecraft:campfire_cosy_smoke ~ ~0.5 ~ 0.5 0.2 0.5 0.01 20
execute unless entity @s[type=#fartpack:boss] run function fartpack:world/camera_shake
execute if entity @s[type=#fartpack:boss] run function fartpack:clouds/legendary
execute if entity @s[type=minecraft:creeper] unless entity @s[type=#fartpack:boss] run function fartpack:clouds/creeper_signature
execute if entity @s[type=minecraft:goat] unless entity @s[type=#fartpack:boss] run function fartpack:clouds/goat_signature
execute unless entity @s[type=minecraft:creeper] unless entity @s[type=minecraft:goat] unless entity @s[type=#fartpack:boss] run function fartpack:world/cloud_random
execute at @s if entity @s[type=#fartpack:small_radius] unless entity @s[type=minecraft:player] run function fartpack:push/small
execute at @s unless entity @s[type=#fartpack:small_radius] unless entity @s[type=minecraft:player] run function fartpack:push/norm
