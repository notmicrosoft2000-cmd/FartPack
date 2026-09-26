playsound minecraft:entity.creeper.primed player @a ~ ~ ~ 2.0 1.0
particle minecraft:explosion ~ ~0.5 ~ 0 0 0 0 1
summon minecraft:area_effect_cloud ~ ~0.7 ~ {custom_particle:{type:"minecraft:explosion"},Radius:3.5f,RadiusOnUse:-0.05f,RadiusPerTick:0.0f,Duration:200,WaitTime:0,ReapplicationDelay:10,potion_contents:{custom_color:5754977,custom_effects:[{id:"minecraft:poison",amplifier:2,duration:120,show_particles:1b},{id:"minecraft:blindness",amplifier:0,duration:60,show_particles:1b}]}}
