# The palette, and why. The report was: "the colors are random they do not
# look like farts so yellow, green disgusting colors must be used to make them
# that color."
#
# Before v28, seven of the nine clouds were outside a sickly band: methane
# #FFAA00 orange, blessed #FFD700 gold, greensmoothie #55FF55 neon, atomic
# #82002B dark magenta, legendary #4EFED9 cyan, goat_signature #FFFFFF white,
# sulfuric #C0C0C0 silver. The two already in it were stinky #95D27E and
# creeper_signature #57D061. All nine are now G>R>B - green dominant, red
# substantial, blue near zero.
#
# G>R>B rather than R>G>B on purpose. The red component is what separates
# "sickly yellow-green" from "grass", and the near-zero blue is what keeps it
# off the magic end. The two worst offenders were not the odd colours but the
# dragon_breath clouds: that particle is the vanilla spelling of sorcery, and
# no tint turns it into a fart. atomic and legendary moved to
# campfire_cosy_smoke - the pack's own fart particle, which is what
# clouds/stinky already used.
#
# Kept, because they are apt and nobody asked: methane's flame (it ignites),
# greensmoothie's happy_villager (it is called the smoothie), creeper's
# explosion, blessed's end_rod (the one deliberately pleasant cloud), stinky and
# sulfuric's smoke particles. Only their colours moved.

execute store result score #cloud fart.var run random value 1..6
execute if score #cloud fart.var matches 1 run function fartpack:clouds/stinky
execute if score #cloud fart.var matches 2 run function fartpack:clouds/methane
execute if score #cloud fart.var matches 3 run function fartpack:clouds/atomic
execute if score #cloud fart.var matches 4 run function fartpack:clouds/greensmoothie
execute if score #cloud fart.var matches 5 run function fartpack:clouds/sulfuric
execute if score #cloud fart.var matches 6 run function fartpack:clouds/blessed