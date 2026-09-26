# bar/make_gas_bar - create a player's gas bossbar for the first time.
#
# Called once, from core/assign_pid, when a player is first given a pid. The bar
# is created at the player's own cap (admin/cap) rather than the old constant
# 100, so somebody given a 200 cap never sees a bar that fills halfway and stops.
#
# `$(cap)` comes from storage written by the caller for the same reason
# bar/ensure_bar cannot write its own: a macro function is expanded in full
# before any line executes. core/assign_pid calls admin/defaults first so the cap
# actually exists before it is read here.
$bossbar add fartpack:gas_$(pid) {"text":"Gas Pressure","color":"yellow"}
$bossbar set fartpack:gas_$(pid) max $(cap)
$bossbar set fartpack:gas_$(pid) color yellow
$bossbar set fartpack:gas_$(pid) players @s
$bossbar set fartpack:gas_$(pid) visible true
