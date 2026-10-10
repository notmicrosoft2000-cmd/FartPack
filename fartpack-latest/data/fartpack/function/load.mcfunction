function fartpack:core/bootstrap
recipe give @a fartpack:anti_fart_kibble
recipe give @a fartpack:gas_warden_tonic
tellraw @a [{"text":"[FartPack] ","color":"green"},{"text":"loaded. Every utility block, mob and dropped item has its own independent fart timer!","color":"yellow"}]
tellraw @a [{"text":"  CROUCH to release (empties bar + HEALS you). Empty bar + crouching HURTS. Full bar = LEGENDARY MEGA-FART!","color":"gold"}]
# v34: the items are handed out on join again (core/on_join calls items/give),
# so say so. Previously the load screen advertised two recipes while nothing in
# the pack ever gave the items and nothing said you were being given any.
tellraw @a [{"text":"  You get a Gas-Warden Tonic and two Anti-Fart Kibble when you join - keep them for a bad day.","color":"green"}]
tellraw @a [{"text":"  Recipes - Kibble: Cooked Beef + Dried Kelp + Sugar (fills at 1% for 45s). Tonic: Honey Bottle + Slime Ball (no fill for 90s). Toggle: /trigger fart.toggle","color":"aqua"}]
tellraw @a [{"text":"  Weather - putrid fronts roll in every 5-10 min. Rare events (gas surge, cyclone, blessing, swarm) every 20-40 min.","color":"gray"}]
