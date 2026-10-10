# admin/recalc - derive everything that depends on the bar cap.
#
# Called whenever fart.cap changes, so that raising the cap does not quietly
# change what "full" means. Two thresholds in the pack are relative to a full
# bar and were hardcoded against the old constant 100:
#
#   player/press   hunger while sitting on a full bar   was `pressure matches 25..`
#   player/press   the forced legendary mega-fart       was `pressure matches 100..`
#
# If the cap became configurable and these stayed at 25 and 100, then a cap of
# 200 would fire the legendary fart at half a bar, and a cap of 40 would make it
# literally unreachable. So both are derived instead:
#
#   fart.leg  = fart.cap            a full bar is a full bar at any cap
#   fart.warn = fart.cap / 4        hunger starts at a quarter of full, as before
#
# Integer division, so warn is floor(cap/4). At the stock cap of 100 that is
# exactly 25 and nothing changes for anyone who has not touched the config.
#
# No per-tick cost: this runs when the cap is set, never on the tick path.
#
# admin/cap does NOT call this file - see the comment there - it re-derives the
# same two values against $(arg0) directly, because `execute as` would skip an
# offline player. So keep the two in step when editing.
#
# #rc_four is re-seeded here rather than assumed from bootstrap, so that this
# function cannot divide by a stale or missing constant if it is ever called
# from somewhere bootstrap has not reached.
#   fart.leg  = fart.cap            a full bar is a full bar at any cap
#   fart.warn = fart.cap / 4        hunger starts at a quarter of full, as before
#   fart.near = fart.cap - cap/5    the "GAS PRESSURE NEAR MAX" warning, at 80%
#
# Integer division, so warn is floor(cap/4). At the stock cap of 100 that is
# exactly 25 and nothing changes for anyone who has not touched the config.
#
# `fart.near` is 80% expressed as a SUBTRACTION rather than a multiplication,
# because `scoreboard players operation` has no multiply-by-a-score that composes
# the way `/=` does - there is no `*=` against another holder's value. The pack
# needs a percentage of a per-player number in two places now (this and the
# crouch-heal threshold the user asked for), and both are worked out the same way:
# divide by a small constant into a scratch, then subtract. `cap - cap/5` is 80%
# for every cap that is not a multiple of 5, and floor()s the last few points,
# which moves the warning by at most 1 gas and never past the cap itself.
scoreboard players set #rc_four fart.var 4
scoreboard players set #rc_five fart.var 5
scoreboard players operation @s fart.leg = @s fart.cap
scoreboard players operation #rc_tmp fart.var = @s fart.cap
scoreboard players operation #rc_tmp fart.var /= #rc_four fart.var
scoreboard players operation @s fart.warn = #rc_tmp fart.var
scoreboard players operation #rc_tmp2 fart.var = @s fart.cap
scoreboard players operation #rc_tmp2 fart.var /= #rc_five fart.var
scoreboard players operation @s fart.near = @s fart.cap
scoreboard players operation @s fart.near -= #rc_tmp2 fart.var
