# core/reap - bound the scoreboard leak.
#
# Vanilla gives you no way to enumerate scoreboard rows, so per-entity scores
# belonging to an entity that has since despawned or died can never be removed
# selectively. That makes most of the leak unfixable in pure commands, but not
# all of it:
#
#   fart.gtick     Only ever set on the two tagged gas clouds, and those always
#                  despawn. Wiping the whole objective costs at most one delayed
#                  damage tick, so it is safe to do wholesale. This is the big
#                  one: one row leaked per cloud, and clouds are the most
#                  frequently spawned thing in the pack.
#   fart.cooldown  Left alone - wiping it would make every nearby mob fart at
#   fart.target    the same instant. See BUGS-AND-FIXES.md #14.
#
# Every 200 ticks (10s), which is far longer than the 20/30-tick gas cadences in
# clouds/gas_apply, so a reap can never swallow a damage tick permanently.
scoreboard players reset * fart.gtick
scoreboard players set #rc fart.var 0
