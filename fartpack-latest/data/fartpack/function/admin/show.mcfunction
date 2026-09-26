# admin/show - print one player's current FartPack config.
#
#   /function fartpack:admin/show Steve
#
# A one-line macro that hands off to admin/show_one, for the same reason
# admin/cap delegates its bossbar work: the body is mostly constant commands
# (zeroing five scratch holders, then telling the chat a fixed sentence) and
# none of those lines can carry a $(arg) without something contrived. A plain
# function has no such restriction.
#
# For an offline player the `execute as` does not resolve and nothing prints.
# That is the right behaviour for a diagnostic rather than a silent wrong
# answer - and the underlying values are readable directly anyway with
# `scoreboard players get <name> fart.rate`.
$execute as $(arg0) run function fartpack:admin/show_one
