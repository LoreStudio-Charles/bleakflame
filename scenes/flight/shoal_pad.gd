class_name ShoalPad
extends DockingPad
## The Rust Shoal's berth. A DockingPad (so it inherits the approach skill-check,
## repairs-on-dock, and save), but the gate is INVERTED from the station's: the
## Shoal welcomes OUTLAWS, not the law. You may only put down if the Shoal is
## OPEN to you (Standing.shoal_open() — Krayt's invitation, Privateer-friendly,
## or the post-Krayt truce); otherwise its guns track you and you're bounced.
## Being a distinct type also lets flight_test tell the Shoal berth apart from
## the station's (both are DockingPads) when toggling the right dock screen.


func _ready() -> void:
	super()
	# NOBODY LEARNS TO FLY HERE. The scrape and wreck lessons are Ruel hailing the
	# cockpit from the station he runs; hearing the Harbormaster scold you as you
	# put down at an outlaw den would be nonsense. This is the ONLY reason the old
	# override existed, and dodging one dialogue by reimplementing try_dock cost
	# the Shoal the berth size gate and the fault reporting with it.
	teaches_docking = false


## INVERTED FROM THE STATION'S. The Shoal welcomes outlaws and turns away the
## law: you may only put down if it is open to you (Krayt's invitation, a
## Privateer standing, or the post-Krayt truce). Overriding just this leaves the
## approach grading, the damage tiers, the size limit and the berth itself
## exactly as they are everywhere else — which is the point.
func clearance_error(_ship: TestShip) -> String:
	if not Standing.shoal_open():
		return "The Shoal's guns track you. Nobody flies in here uninvited."
	return ""
