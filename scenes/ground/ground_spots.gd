class_name GroundSpots
## WHAT [E] MEANS RIGHT NOW — the interactable resolution, as a pure function.
##
## A ground scene keeps a list of SPOTS: a door, a shopkeeper, the way out of a room,
## a body worth searching. Each is `{pos | node, range, prompt, action, npc?}`. This
## decides which one the player is actually offering to touch.
##
## PURE, AND THAT IS THE POINT (docs/engineering_principles.md, Command/Query). It takes
## the candidates and a position and returns the winner; it holds no list, reads no scene,
## and writes nothing. The caller assembles what is in play — which is what lets an
## interior and the open town use the same rule with completely different contents, and
## what lets a test check the rule without building a planet.
##
## THE RULE IS ONE LINE: NEAREST IN REACH WINS. It is worth stating because it used to be
## two rules. Loot was checked only when nothing else had claimed the prompt — and a room
## ALWAYS has a standing spot (its exit) whose range covers the whole floor, so indoors the
## scavenge prompt could never appear and the cave corpses could not be searched at all
## (playtest: "no drone from the cave scrit"). A body you are standing on is always the
## more specific offer, and "nearest wins" says so without a precedence table.

## How close you must be to a body to be offered a search. Tighter than a door, because a
## corpse is a small thing and you should have to stand over it.
const LOOT_REACH := 70.0


## The spot in reach of `from`, or {} when nothing is. `candidates` is a flat list — the
## caller decides what is in play this frame, including anything dynamic.
static func focus(candidates: Array, from: Vector2) -> Dictionary:
	var best := INF
	var winner := {}
	for s in candidates:
		var p: Vector2 = s.node.global_position if s.has("node") else s.pos
		var dist := from.distance_to(p)
		if dist <= float(s.range) and dist < best:
			best = dist
			winner = s
	return winner


## The searchable bodies lying about, as spot candidates. Dynamic — they come and go — so
## they are rebuilt each frame rather than registered, and they compete with the static
## spots on exactly the same footing.
static func loot_candidates(tree: SceneTree, prompt: String,
		reach := LOOT_REACH) -> Array:
	var out: Array = []
	for n in tree.get_nodes_in_group("ground_loot"):
		var c := n as Node2D
		if c != null and is_instance_valid(c):
			out.append({"node": c, "range": reach, "prompt": prompt, "action": "loot"})
	return out
