function fartpack:core/bootstrap
recipe give @a fartpack:anti_fart_kibble
recipe give @a fartpack:gas_warden_tonic
tellraw @a [{"text":"[FartPack] ","color":"green"},{"text":"loaded. Every utility block, mob and dropped item has its own independent fart timer!","color":"yellow"}]
tellraw @a [{"text":"  CROUCH to release (empties bar + HEALS you). Empty bar + crouching HURTS. Full bar = LEGENDARY MEGA-FART!","color":"gold"}]
tellraw @a [{"text":"  Recipes - Kibble: Cooked Beef + Dried Kelp + Sugar (slows bar). Tonic: Honey Bottle + Slime Ball (empties bar). Toggle: /trigger fart.toggle","color":"aqua"}]
