tellraw @a [{"text":"BRAAAAP! ","color":"red"},{"selector":"@s"},{"text":" couldn't hold it any longer - LEGENDARY MEGA-FART! Everyone FLIES!!","color":"gold"}]
playsound minecraft:entity.wither.spawn player @a ~ ~ ~ 4.0 0.5
playsound minecraft:entity.generic.explode player @a ~ ~ ~ 4.0 0.9
playsound fartpack:fart.legendary player @a ~ ~ ~ 4.0 1.0
summon minecraft:firework_rocket ~ ~1 ~ {LifeTime:0,FireworksItem:{id:"minecraft:firework_rocket",count:1,components:{"minecraft:fireworks":{explosions:[{shape:"large_ball",has_trail:1b,has_twinkle:1b,colors:[I;16711680,16753920,65280]}]}}}}
particle minecraft:dragon_breath ~ ~1 ~ 3 1 3 0.05 100
effect give @s minecraft:slowness 60 0
scoreboard players set @s fart.pressure 0
summon minecraft:area_effect_cloud ~ ~1 ~ {custom_particle:{type:"minecraft:dragon_breath"},Radius:8.0f,RadiusOnUse:-0.1f,RadiusPerTick:0.0f,Duration:100,WaitTime:5,ReapplicationDelay:10,Tags:["fart.gas_legendary"],potion_contents:{custom_color:5177049,custom_effects:[{id:"minecraft:levitation",amplifier:2,duration:100,show_particles:1b}]}}
function fartpack:world/fart_entity
execute at @s run function fartpack:push/legendary
scoreboard players set #power fart.var 90
function fartpack:push/self
execute at @s run function fartpack:world/camera_shake
