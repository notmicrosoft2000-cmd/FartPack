tellraw @a [{"text":"\u2620 LEGENDARY FART \u2620","color":"dark_red","bold":true}]
tellraw @a [{"text":"","extra":[{"selector":"@s"},{"text":" unleashes a catastrophic blast!","color":"red"}]}]
playsound minecraft:entity.wither.spawn player @a ~ ~ ~ 3.0 0.6
playsound minecraft:entity.generic.explode player @a ~ ~ ~ 3.0 0.8
playsound fartpack:fart.legendary player @a ~ ~ ~ 4.0 1.0
summon minecraft:firework_rocket ~ ~1 ~ {LifeTime:0,FireworksItem:{id:"minecraft:firework_rocket",count:1,components:{"minecraft:fireworks":{explosions:[{shape:"large_ball",has_trail:1b,has_twinkle:1b,colors:[I;16711680,16753920]}]}}}}
summon minecraft:area_effect_cloud ~ ~1 ~ {custom_particle:{type:"minecraft:dragon_breath"},Radius:8.0f,RadiusOnUse:-0.1f,RadiusPerTick:0.0f,Duration:300,WaitTime:5,ReapplicationDelay:15,Tags:["fart.gas_legendary"],potion_contents:{custom_color:5177049,custom_effects:[{id:"minecraft:blindness",amplifier:0,duration:100,show_particles:1b},{id:"minecraft:levitation",amplifier:1,duration:40,show_particles:1b}]}}
