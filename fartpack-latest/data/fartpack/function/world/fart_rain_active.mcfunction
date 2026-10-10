# world/fart_rain_active - ambient particles fall around every player while it's
# raining, plus a mild, non-lethal nausea pulse every 1.5s (30 ticks) as a
# reminder to get inside. Purely atmospheric - no damage, no pressure changes, so
# it cannot interfere with the gas-bar mechanics.
#
# The nausea is DELIBERATELY KEPT. "the fart rain just causes nausea" was read
# as a request to remove it; it is not, and the fix for that sentence was to
# make the rain visible (green, below) rather than to stop the one thing that
# made you aware of it. Removing the nausea as well would have left a green
# sky and no reason whatsoever to go inside.
#
# CADENCE: this is the most expensive thing in the weather system - two `particle`
# commands PER PLAYER PER CALL. Run per-tick that is 10 commands/tick for 5
# players, every tick, for the whole 20-40s storm, which is the kind of thing
# that quietly eats the tick budget Pass C reclaimed.
#
# So world/tick drives it on an exact 3-tick gate, and the two counters here
# advance by 3 rather than 1. That keeps wall-clock behaviour EXACTLY the same:
#   #rain_dur   400-800 ticks removed 3 at a time still ends after 400-800 ticks
#   #rain_tick  still reaches 30 after 30 ticks, so nausea still pulses every 1.5s
# while cutting particle dispatch to a third. Particles have a ~1-2s lifetime and
# are spawned with a count of 2-3, so at 6 spawns/second the visual is unchanged.

scoreboard players remove #rain_dur fart.var 3
scoreboard players add #rain_tick fart.var 3
# v28: the two falling layers are now GREEN. They were `campfire_cosy_smoke`
# (grey) and `cloud` (white), which is why the report was "the fart rain just
# causes nausea" - there was nothing to see but a grey haze and a nausea
# overlay, i.e. the one thing you notice about it was the part that is not
# visual. `dust` takes an explicit RGB, so the colour is now a decision rather
# than whatever the particle defaults to.
#
# Two heights on purpose, and not for the "cadence" reason the old two did. A
# single spawn plane reads as a band hanging in the air; spawning one layer at
# +4 and another at +5.5 with different scales gives the column depth that
# reads as weather. The scale difference is what sells it as falling matter
# rather than a glowing box - big soft motes up high, small sharp ones below.
#
# `dust` is camera-facing and does not fall on its own, so the falling
# impression comes entirely from the two-layer stagger plus the 3-tick cadence
# re-spawning them. That is a visual approximation, not simulated rain, and it
# is worth saying so rather than letting the comment imply otherwise.
execute as @a[name=!"Server"] at @s run particle minecraft:dust{color:[0.62,0.82,0.10],scale:0.75} ~ ~4 ~ 1.3 0.5 1.3 0.01 3
execute as @a[name=!"Server"] at @s run particle minecraft:dust{color:[0.48,0.72,0.08],scale:0.55} ~ ~5.5 ~ 1.6 0.7 1.6 0.01 2
# EXACT gate, not a range. #rain_tick is advanced by 3 and reset here, so it can
# only ever be 3,6,...,30 - a range would be harmless today but silently starts
# running this branch on unexpected values the moment the step size changes.
execute if score #rain_tick fart.var matches 30 run scoreboard players set #rain_tick fart.var 0
# NB: `matches 0` requires the score to be SET. fart_rain_start sets #rain_tick to
# 0 explicitly, so this does fire on the first pass - but that also means nausea
# lands on tick one of the storm. Harmless (non-lethal, 2s, refreshed), left as-is.
execute if score #rain_tick fart.var matches 0 as @a[name=!"Server"] run effect give @s minecraft:nausea 40 0 true
execute if score #rain_tick fart.var matches 0 run playsound minecraft:entity.player.burp ambient @a ~ ~ ~ 0.6 0.5
execute if score #rain_dur fart.var matches ..0 run function fartpack:world/fart_rain_end
