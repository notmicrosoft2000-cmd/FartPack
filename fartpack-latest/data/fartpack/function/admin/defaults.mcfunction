# admin/defaults - put @s back to stock FartPack numbers.
#
# A plain function on @s, not a macro, because it is called from three places
# that have nothing to do with each other: a brand new player joining
# (core/assign_pid), an existing player being upgraded to a version that added
# config (core/bootstrap), and the admin explicitly asking for a reset.
#
# Idempotent by construction - it sets absolute values, never increments.
#
# The `fart.has_cfg` tag is the "this player has been given their config" marker.
# It exists because `fart.rate 0` (frozen) and "never set" are indistinguishable
# from a scoreboard - both fail `matches 1..` - so a value check cannot tell
# "admin deliberately froze this player" from "this world predates the config
# system". A tag can. bootstrap uses it to initialise exactly the players who
# need it, without ever overwriting a setting somebody chose on purpose.
#
#   fart.rate  0-5   how many times the movement-derived base increment is added
#                   per fill pass. 0 = the bar never fills on its own.
#   fart.every 1-4   add on only 1 pass in N. 1 = every pass (stock).
#   fart.cyc         internal counter for `every`. Clamped in player/fill_gas.
#   fart.cap   20-500  what the bar fills to. Also drives the bossbar max.
#   fart.leg         derived: the pressure at which the bar counts as full and
#                   the forced legendary fart fires. == cap.
#   fart.warn        derived: the pressure at which holding it starts to make
#                   you hungry. == cap / 4, so 25 at the stock cap of 100.
#   fart.rel   1-10  how much pressure a crouching release drains per tick.
#   fart.pow   0-200 horizontal knockback applied to OTHER entities on release,
#                   in 1/100 blocks per tick. Stock is 30. 0 = no shove at all.
scoreboard players set @s fart.rate 1
scoreboard players set @s fart.every 1
scoreboard players set @s fart.cyc 0
scoreboard players set @s fart.rel 1
scoreboard players set @s fart.pow 30
scoreboard players set @s fart.cap 100
function fartpack:admin/recalc
tag @s add fart.has_cfg
