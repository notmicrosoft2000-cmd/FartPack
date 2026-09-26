# player/apply_gas - actually put this pass's gas into the player's bar.
#
# Split out of player/fill_gas so that the admin/every throttle can skip it
# wholesale. fill_gas still does all the expensive work - two `data get entity`
# calls for the position delta, which is what decides whether the player moved -
# because that has to happen every pass or the throttle would corrupt the
# movement detection. Only the arithmetic is skipped, which is nearly free.
#
# The rate is applied by repeating the SAME operation rather than by scaling,
# because a scoreboard has no multiply - there is no single command meaning "add
# pressure times this player's rate". Repeating `operation += #famt` is
# idempotent and the `matches` tests mean only the steps that apply actually
# execute, so a stock player (rate 1) runs exactly one add and the four extra
# lines below cost four failed comparisons and nothing else.
#
#   rate unset -> 1 add    (see the `unless ..0` note below)
#   rate 0     -> no adds  (frozen: the bar never fills on its own)
#   rate 1     -> one add   (stock, identical to the pre-v26 behaviour)
#   rate 5     -> five adds
#
# The first add is written `unless score @s fart.rate matches ..0` rather than
# `if score @s fart.rate matches 1..` on purpose. An unset score matches neither,
# so the `1..` form would silently stop a player's bar filling at all if
# admin/defaults had not yet run for them - the worst possible failure for this
# feature, because it looks exactly like the player having deliberately set
# themselves to 0. The `unless ..0` form treats unset as stock and only an
# explicit 0 as frozen.
execute unless score @s fart.rate matches ..0 run scoreboard players operation @s fart.pressure += #famt
execute if score @s fart.rate matches 2.. run scoreboard players operation @s fart.pressure += #famt
execute if score @s fart.rate matches 3.. run scoreboard players operation @s fart.pressure += #famt
execute if score @s fart.rate matches 4.. run scoreboard players operation @s fart.pressure += #famt
execute if score @s fart.rate matches 5.. run scoreboard players operation @s fart.pressure += #famt
# Clamp to this player's cap rather than to the old constant 100. Guarded on
# `fart.cap matches 1..` because an `execute if score` against an unset holder
# fails outright, and a player mid-upgrade would otherwise have their bar stop
# filling until admin/defaults has run.
execute if score @s fart.cap matches 1.. if score @s fart.pressure > @s fart.cap run scoreboard players operation @s fart.pressure = @s fart.cap
