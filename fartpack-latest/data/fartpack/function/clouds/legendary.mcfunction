# v29: YELLOW, and the reason the previous colour did nothing.
#
# The colour is #FFD24A (R=255 G=210 B=74), set as
# potion_contents.custom_color:16765514 on the area_effect_cloud.
#
# v28 already shipped a yellow-GREEN here (#9EC11A) and the user still saw a
# non-yellow cloud, because the particle was FORCED per cloud with custom_particle
# and every one of those particles has its own fixed colour: was campfire_cosy_smoke - grey. A forced
# particle is not tinted by the cloud's colour, so custom_color never reached the
# screen and re-tuning the number was a no-op.
#
# So the particle is now minecraft:effect, the vanilla particle that DOES render
# in the cloud's colour. That is what makes the colour field authoritative.
#
# The trade-off: vanilla has no tinted SMOKE particle. smoke and both campfire
# smokes are grey and stay grey whatever colour is set, so "smoke" and "yellow"
# cannot both be had. The user asked for yellow twice; this is yellow. Revert the
# one custom_particle value in this file to get the old grey smoke back.
#
# ALSO REMOVED in v29: a top-level Color:16765514 on the summon. Measured - the server
# stores no such field and `data get entity ... Color` reports no elements, so it
# was silently discarded and only made the NBT look like it had a control it
# did not have.
#
# NOT VERIFIED: the world is paused at zero players, so this cannot be seen from
# here. custom_color:16765514 was confirmed to survive storage in a live summon.

title @a title [{"text":"LEGENDARY FART","color":"dark_red","bold":true}]
title @a subtitle [{"text":"A catastrophic blast","color":"red"}]
tellraw @a [{"text":"\u2620 LEGENDARY FART \u2620","color":"dark_red","bold":true}]
tellraw @a [{"text":"","extra":[{"selector":"@s"},{"text":" unleashes a catastrophic blast!","color":"red"}]}]
playsound minecraft:entity.wither.spawn player @a ~ ~ ~ 3.0 0.6
playsound minecraft:entity.generic.explode player @a ~ ~ ~ 3.0 0.8
playsound fartpack:fart.legendary player @a ~ ~ ~ 4.0 1.0
summon minecraft:firework_rocket ~ ~1 ~ {LifeTime:0,FireworksItem:{id:"minecraft:firework_rocket",count:1,components:{"minecraft:fireworks":{explosions:[{shape:"large_ball",has_trail:1b,has_twinkle:1b,colors:[I;16711680,16753920]}]}}}}
summon minecraft:area_effect_cloud ~ ~1 ~ {custom_particle:{type:"minecraft:effect"},Radius:8.0f,RadiusOnUse:-0.1f,RadiusPerTick:0.0f,Duration:300,WaitTime:5,ReapplicationDelay:15,Tags:["fart.gas_legendary"],potion_contents:{custom_color:16765514,custom_effects:[{id:"minecraft:blindness",amplifier:0,duration:100,show_particles:1b},{id:"minecraft:levitation",amplifier:1,duration:40,show_particles:1b}]}}
