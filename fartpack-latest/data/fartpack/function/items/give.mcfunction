# Both items are consumables with an effect that runs through a `consume_item`
# advancement, so the custom_data on the stack is what fires items/on_kibble and
# items/on_tonic. The two give lines use the current 1.21 item-component syntax
# (`custom_data` and `item_name` as component keys, not a `tag:` compound) -
# this server is 1.21.11 and the older `tag:{...}` form is no longer read.
#
# v34: called from core/on_join again, per player. It had lost its only call site
# at some point, which left the pack with two working items and no way to get
# them except crafting.
give @s minecraft:cooked_beef[custom_data={fartpack:"kibble"},item_name="Anti-Fart Kibble"] 2
give @s minecraft:honey_bottle[custom_data={fartpack:"tonic"},item_name="Gas-Warden Tonic"] 1
# v34: the message claimed both items "slow your gas bar". That was only ever
# true of the kibble, and even then it was 50% rather than the 1% it now is.
tellraw @s [{"text":"Here's some Gas-Warden Tonic and Anti-Fart Kibble - the tonic stops your bar filling for 90s, the kibble slows it to 1%!","color":"gold"}]