# v29: YELLOW, and the reason the previous colour did nothing.
#
# The colour is #FFC400 (R=255 G=196 B=0), set as
# potion_contents.custom_color:16761856 on the area_effect_cloud.
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
# ALSO REMOVED in v29: a top-level Color:16761856 on the summon. Measured - the server
# stores no such field and `data get entity ... Color` reports no elements, so it
# was silently discarded and only made the NBT look like it had a control it
# did not have.
#
# NOT VERIFIED: the world is paused at zero players, so this cannot be seen from
# here. custom_color:16761856 was confirmed to survive storage in a live summon.

summon minecraft:area_effect_cloud ~ ~0.7 ~ {custom_particle:{type:"minecraft:effect"},Radius:4.0f,RadiusOnUse:-0.05f,RadiusPerTick:0.0f,Duration:200,WaitTime:10,ReapplicationDelay:20,Tags:["fart.gas_atomic"],potion_contents:{custom_color:16761856,custom_effects:[{id:"minecraft:poison",amplifier:0,duration:100,show_particles:1b}]}}
