scoreboard players add #stats fart.total 1
function fartpack:world/fart_sound
execute at @s if block ~ ~ ~ minecraft:crafting_table run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a crafting table farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ minecraft:furnace run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a furnace farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ minecraft:blast_furnace run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a blast furnace farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ minecraft:smoker run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a smoker farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ minecraft:chest run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a chest farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ minecraft:trapped_chest run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a trapped chest farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ minecraft:barrel run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a barrel farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ minecraft:dispenser run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a dispenser farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ minecraft:dropper run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a dropper farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ minecraft:hopper run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a hopper farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ minecraft:campfire run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a campfire farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ minecraft:beehive run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a beehive farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ minecraft:lectern run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a lectern farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ minecraft:stonecutter run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a stonecutter farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ minecraft:anvil run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"an anvil farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ minecraft:brewing_stand run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a brewing stand farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ minecraft:composter run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a composter farted!","color":"yellow"}]
execute at @s if block ~ ~ ~ #fartpack:cauldron run tellraw @a[name=!"Server",distance=..24] [{"text":"BROOFT! ","color":"gold"},{"text":"a cauldron farted!","color":"yellow"}]
function fartpack:world/cloud_random
execute at @s run function fartpack:push/block
