# world/etick - rebuild the "entities near a player" set.
#
# This is the single most expensive thing the pack did: `tag @e remove` followed
# by one `tag @e add` PER PLAYER, every tick, over every loaded entity. With 3
# players and 300 entities that is ~1800 NBT tag writes per tick, all to
# recompute a set that only needs to be roughly right.
#
# Now it runs on 9 of every 30 ticks instead of 30 of 30, which cuts it to ~30%.
# The only cost is that a mob can keep farting for up to 21 ticks (1s) after it
# walks out of range, and a newly-arrived mob can wait up to 1s to be noticed.
# Both are invisible against mob fart timers of 30-1800 ticks.
#
# The exclusion list is deliberately unchanged from the original. Do NOT swap it
# for #fartpack:no_push: that tag contains minecraft:item, and dropped items
# farting is a core feature of this pack.
tag @e remove fart.etick
execute at @a[name=!"Server"] as @e[tag=!fart.etick,tag=!fart.blocktimer,type=!minecraft:marker,type=!minecraft:player,type=!minecraft:experience_orb,type=!minecraft:area_effect_cloud,type=!minecraft:firework_rocket,distance=..16] run tag @s add fart.etick
