# Kept as a separate entry point rather than folded into core/on_join, because
# items/give is the only function in the pack that hands out items and an admin
# may want to run it on its own without waiting for someone to rejoin.
#
# v34: core/on_join calls items/give DIRECTLY, not this file, so a failure in the
# give still cannot abort the crown repair, the regen or the book - which is the
# whole ordering rule stated at the top of core/on_join.
function fartpack:items/give