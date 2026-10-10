$execute store result bossbar fartpack:gas_$(pid) value run scoreboard players get @s fart.pressure
# v33: the name carries the live percentage, and is only re-set when the integer
# percent has moved.
#
# PROVEN, by a probe on the live server: a bossbar name accepts a chat component,
# and {"score":{"name":X,"objective":Y}} inside it is accepted and RESOLVED
# SERVER-SIDE - the rename response came back as
# "Custom bossbar [Gas 42%] has been renamed", i.e. the number was already
# substituted before the client saw it. That is not obvious, bossbar names are
# not documented as evaluating components, and a tellraw-shaped assumption would
# have been a guess. The same probe included a deliberately-broken component,
# which was REJECTED, so acceptance here means something rather than being a
# silent no-op. (Do not read too much into the rename response though: it echoes
# the server's own resolved form, not anything the client rendered.)
#
# INFERRED, NOT PROVEN: that the name is FROZEN and therefore must be re-set. I
# could not read a name back - `bossbar get <id> name` is rejected by this
# server - and I never changed the source score between renames, so "it still
# showed 42%" is explained just as well by "the server froze the resolved text"
# as by "the client re-evaluates the component every frame". An earlier version
# of this comment called that "measured". It was not, and the gap between those
# two words is exactly the kind of thing that rots into a false claim.
#
# It does not matter, which is why this is safe to ship. The re-set is CORRECT if
# the name is frozen and merely REDUNDANT if it is not, so the design is right
# under either answer. A player sitting still at 63% pays one failed comparison
# per tick and zero bossbar commands either way. Do not delete the re-set on the
# strength of the inference. Settling it needs a human: change the source score
# between two renames and look at the screen, because rendering is not
# verifiable over RCON.
#
# `fart.pct_shown` is deliberately NOT seeded to -1: an UNSET score matches no
# range, so `unless score @s fart.pct_shown = @s fart.pct` is TRUE for a player who
# has never had a name set, and the name gets written on their first bar tick. That
# is the `fart.rate` trap again, in a third costume - a comparison that looks like
# it covers "no value yet" and does not.
$execute unless score @s fart.pct_shown = @s fart.pct run bossbar set fartpack:gas_$(pid) name [{"text":"Gas "},{"score":{"name":"@s","objective":"fart.pct"},"color":"yellow"},{"text":"%"}]
