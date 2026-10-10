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
#
# `+= #famt fart.var` - the trailing `fart.var` is the SOURCE objective and is
# not optional. `scoreboard players operation` takes five fields
# (target, target objective, operator, source, source objective) and stops at
# four with "Unknown or incomplete command", pointing the caret at the end of the
# line. v26 shipped without it on these five lines: the whole file failed to
# load, so the gas bar silently stopped filling for everyone, and the only
# evidence was one ERROR line in the log naming the file. See #30.
execute unless score @s fart.rate matches ..0 run scoreboard players operation @s fart.pressure += #famt fart.var
execute if score @s fart.rate matches 2.. run scoreboard players operation @s fart.pressure += #famt fart.var
execute if score @s fart.rate matches 3.. run scoreboard players operation @s fart.pressure += #famt fart.var
execute if score @s fart.rate matches 4.. run scoreboard players operation @s fart.pressure += #famt fart.var
execute if score @s fart.rate matches 5.. run scoreboard players operation @s fart.pressure += #famt fart.var
# v31: THE KING'S DOUBLE GAS, and it used to be `fart.rate 2` written by
# king/crowned and undone by king/demote. That was fine until profiles arrived:
# fart.rate belongs to the player's chosen profile, and a demotion hard-setting it
# back to 1 silently threw the profile away. Two systems writing one score is the
# defect, not the crown.
#
# So the crown's bonus is a TAG TEST here, where the other rate steps are, and the
# king functions no longer touch fart.rate at all. The observable behaviour is
# identical - one extra add of #famt per pass, exactly what rate 2 did - and it now
# composes: a king with a heavy profile keeps the heavy profile AND the crown.
# It is also self-healing on rejoin, where the old version was not: core/on_join
# demotes a returning king, which used to cost them the rate they had earned.
#
# `tag=!fart.king` is not needed - the other lines are cumulative steps keyed on
# rate, and this one is a separate additive step, so a king at rate 4 gets 4 + 1
# = 5 adds. That is the intended reading of "the king fills faster", not a bug.
execute if entity @s[tag=fart.king] run scoreboard players operation @s fart.pressure += #famt fart.var
# Clamp to this player's cap rather than to the old constant 100. Guarded on
# `fart.cap matches 1..` because an `execute if score` against an unset holder
# fails outright, and a player mid-upgrade would otherwise have their bar stop
# filling until admin/defaults has run.
execute if score @s fart.cap matches 1.. if score @s fart.pressure > @s fart.cap run scoreboard players operation @s fart.pressure = @s fart.cap
