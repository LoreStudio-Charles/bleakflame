class_name NavyShip
extends GuardianShip
## THE GALEAN CONFEDERATE NAVY — allied to the Guardians, and NOT the same thing.
##
## USER (2026-07-27): "The Navy is its own faction. Allies but not the same."
##
## WHAT WAS WRONG. The Navy was GuardianShip wearing a costume: every spawn site called
## setup_guard and then UN-SET three things it had just done — the hull tint, the rank
## (setup_guard stamps ELITE; the Navy is MILITARY), and later the registry (GEU; the Navy
## is GCN). Three "undo what the base class did" lines at each of three call sites is the
## textbook shape of a subtype standing where it is not substitutable, and it was already
## logged as a live LSP violation in docs/engineering_principles.md. Each new property the
## Navy needed made it worse, which is how you know it was structural rather than untidy.
##
## AND THE FICTION MAKES IT WORSE, not better (user, 2026-07-27): "Guardians - private
## police and investigators, Navy - the naval force of the Galean Confederacy." A state
## navy is not a KIND OF private security firm. They are two institutions that happen to
## share a habit — flying a patrol route in formation — which is the weakest possible
## reason for one to inherit from the other.
##
## SO THIS IS AN INTERMEDIATE STEP, said plainly rather than pretended otherwise. What is
## borrowed is the PATROL BEHAVIOUR (leash, formation, lane-flying), and the correct end
## state is a shared PatrolShip that both extend, with neither owning the other. That is a
## rename of a widely-used class and wants its own pass. What this fixes TODAY is the
## correction-at-every-call-site problem: what a Navy ship IS is now stated once, here,
## instead of being un-set three times in three places.

## Livery blue — the Navy's own, distinct from Guardian blue.
const NAVY_BLUE := Color(0.23, 0.44, 0.85)


## Stand up a Navy hull. Everything that makes it Navy rather than Guardian happens here,
## so a caller never has to know what the base class did first.
func setup_navy(new_build: ShipBuild, ring_r: float) -> void:
	setup_guard(new_build, ring_r)
	faction = "navy"
	# MILITARY, not the ELITE setup_guard stamps: the Navy is built for a group.
	rank = Threat.Rank.MILITARY
	ship_name = ShipNames.registry("navy")     # GCN
	# The hull shows its OWN colours. set_hull_tint(WHITE) clears the guardian blue the
	# base applied; the livery chevron is what identifies it.
	set_hull_tint(Color.WHITE)
	apply_livery(NAVY_BLUE)


## A Navy patrol on a lane route — the picket, and the fleet's screen.
static func spawn_patrol(host: Node, at: Vector2, build: ShipBuild,
		route: Array[Vector2], level := 0) -> NavyShip:
	var n := NavyShip.new()
	n.position = at
	n.spawn_level = level        # BEFORE setup: apply_build is where the level scales pools
	host.add_child(n)
	n.patrol_points = route
	n.setup_navy(build, 0.0)
	return n
