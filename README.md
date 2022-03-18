# TF2 Indirect Damage Fix

Sure, this is a niche problem, but nevertheless here's a solution.

When maps in TF2 use prop_physics (instead of prop_physics_multiplayer) or 
func_physbox these props can collide with the players. One way to make 
props collide with players is by shooting them. If the impact is strong 
enough, this will damage the player, but not attribute the actual shooter
as damage source.

This is a dirty little fix that stores the last attacker for a prop for a
and applies it as attacker for a limited amount of time until the prop is
considered "settled". The proper way would probably to check the velocity
but I'm lazy :)

## Installation

* Drop the plugin into the server
* Score kill with props
