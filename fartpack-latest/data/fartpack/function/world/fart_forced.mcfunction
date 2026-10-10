# world/fart_forced - the bar filled up and the player could not hold it.
# "Full" is the player's own cap (fart.leg), not a constant - player/press
# compares against it, so a 200-cap player fills the bar before this fires.
# v28: the cost of losing control of it is now slowness only. The
# `hunger 60 1` line is gone - the whole "holding gas makes you hungry" bargain
# was withdrawn in v28 (see player/press), and leaving Hunger II here would have
# meant the one moment the pack is loudest is also the one moment you cannot
# eat. Slowness stays: it is a punishment you can see yourself in, it does not
# touch the hunger bar, and it does not fire on the per-tick path.
#
# v28: a /title as well as the chat line. Reported as "make the events more
# obvious by announcing via /title". title goes to @s (the player who lost
# control) rather than @a, because the chat line below already broadcasts to
# everyone and two overlapping screen-wide titles from one event is worse than
# one.

title @s title [{"text":"BRAAAAP!","color":"red","bold":true}]
title @s subtitle [{"text":"You couldn't hold it - LEGENDARY MEGA-FART","color":"gold"}]
tellraw @a [{"text":"BRAAAAP! ","color":"red"},{"selector":"@s"},{"text":" couldn't hold it any longer - LEGENDARY MEGA-FART! Everyone FLIES!!","color":"gold"}]
playsound minecraft:entity.wither.spawn player @a ~ ~ ~ 4.0 0.5
playsound minecraft:entity.generic.explode player @a ~ ~ ~ 4.0 0.9
playsound fartpack:fart.legendary player @a ~ ~ ~ 4.0 1.0
summon minecraft:firework_rocket ~ ~1 ~ {LifeTime:0,FireworksItem:{id:"minecraft:firework_rocket",count:1,components:{"minecraft:fireworks":{explosions:[{shape:"large_ball",has_trail:1b,has_twinkle:1b,colors:[I;16711680,16753920,65280]}]}}}}
particle minecraft:dragon_breath ~ ~1 ~ 3 1 3 0.05 100
# The cost of losing control of it: slowed. See the v28 note above.
effect give @s minecraft:slowness 60 0
scoreboard players set @s fart.pressure 0
# v29: this cloud was mint (#4EFED9) with dragon_breath forced on it, so it
# rendered as purple dragon breath and the colour field did nothing. Forced
# particles are not tinted by the cloud. Now #FFB300 via custom_color:16757504
# with the colour-respecting `effect` particle, like the other nine clouds.
#
# LEFT ALONE ON PURPOSE: the bare `particle minecraft:dragon_breath` burst a
# few lines above. A `particle` command has no colour argument, so making it
# yellow would mean swapping dragon_breath for a dust particle - a different
# looking effect, which is a call for the user rather than a bug fix.
summon minecraft:area_effect_cloud ~ ~1 ~ {custom_particle:{type:"minecraft:effect"},Radius:8.0f,RadiusOnUse:-0.1f,RadiusPerTick:0.0f,Duration:100,WaitTime:5,ReapplicationDelay:10,Tags:["fart.gas_legendary"],potion_contents:{custom_color:16757504,custom_effects:[{id:"minecraft:levitation",amplifier:2,duration:100,show_particles:1b}]}}
function fartpack:world/fart_entity
execute at @s run function fartpack:push/legendary
scoreboard players set #power fart.var 90
function fartpack:push/self
execute at @s run function fartpack:world/camera_shake
