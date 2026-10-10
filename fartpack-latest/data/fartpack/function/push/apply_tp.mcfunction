# push/apply_tp - the one line that actually moves a player.
#
# It is a macro because the offset is arithmetic, and the only way to get a
# computed number into a `tp` is to expand it into the command text. The three
# arguments (dx, dz, dyy) are written into the macro storage by push/player,
# the CALLER, immediately before calling this - never from in here. A macro
# function is expanded in full before any of its lines run, so storing an
# argument inside the macro would substitute the previous target's value, and
# push/core walks every player in the radius in a single pass.
#
# `dyy` rather than `vy`: the macro argument is already the SCALED vertical
# offset in blocks (0.2, not 20), and calling it `vy` next to the #vy score it
# came from would be two different numbers under one name.
#
# `at @s` is redundant on its face - @s is already the target - and is kept
# anyway: it makes this line independent of where the caller's execution
# position happens to be, which is the sort of thing that silently becomes
# load-bearing the moment somebody reorders push/core.
#
# Every line here is $-prefixed and carries a $(var). That is not style: a macro
# function containing even one line with no $(...) is rejected by the loader
# with "No variables in macro" and the WHOLE FILE silently stops existing - no
# error at the call site, no error in game, and build/checkmacro.py exists
# specifically to catch that before a reload does (#12).

$execute at @s run tp @s ~$(dx) ~$(dyy) ~$(dz)
