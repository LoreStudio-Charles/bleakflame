class_name Leviathan
extends CharacterBody2D
## Base class for the apex cosmic-horror entities — the "leviathans." Each
## system that HAS one gets a named, distinct species (the CINDERWEB here);
## other systems bring wholly different leviathans, or threats that are no
## leviathan at all but just as deadly. How a leviathan moves, hunts, and
## kills lives entirely in the subclass; what all leviathans SHARE lives
## here: their identity, and the iron rule of their mortality.
##
## THE MORTALITY RULE (user canon, 2026-07-20): a leviathan CANNOT be killed
## in open play. Driven to 0 HP it RETREATS into the dark and returns — it
## dies for good only when `mortal` is set, which happens once, at the
## climax of its own system's campaign. Subclasses route 0 HP through
## _perish() (mortal) or _retreat_wounded() (not); take_damage() below does
## that routing so every leviathan obeys the rule by construction.
##
## Members live in the "leviathan" group (scan value, radar bearing, HUD
## threat banner all key off it) — subclasses add it in their _ready.

var beast_name := "Leviathan"
var hp := 1.0
var max_hp := 1.0
var dead := false
## Set true only for the campaign-finale battle: then, and only then, 0 HP
## is death. Everywhere else the beast retreats and comes back.
var mortal := false
var hit_radius := 100.0


func take_damage(amount: float, _source: Node = null) -> void:
	if dead:
		return
	hp -= amount
	_on_hit()
	if hp <= 0.0:
		if mortal:
			_perish()
		else:
			_retreat_wounded()


## Hit feedback (flash, stagger). Subclasses override.
func _on_hit() -> void:
	pass


## True death — only reachable when `mortal`. Subclasses drop loot + free.
func _perish() -> void:
	dead = true
	queue_free()


## Driven off, not slain: fold into the dark and (typically) return later.
## Subclasses decide how it leaves and whether/when it comes back.
func _retreat_wounded() -> void:
	queue_free()
