class_name ShoalPad
extends DockingPad
## The Rust Shoal's berth. A DockingPad (so it inherits the approach skill-check,
## repairs-on-dock, and save), but the gate is INVERTED from the station's: the
## Shoal welcomes OUTLAWS, not the law. You may only put down if the Shoal is
## OPEN to you (Standing.shoal_open() — Krayt's invitation, Privateer-friendly,
## or the post-Krayt truce); otherwise its guns track you and you're bounced.
## Being a distinct type also lets flight_test tell the Shoal berth apart from
## the station's (both are DockingPads) when toggling the right dock screen.


func try_dock(ship: TestShip) -> void:
	var s := status_for(ship)
	if not s.in_range:
		return
	if not Standing.shoal_open():
		ship._flash_note("The Shoal's guns track you. Nobody flies in here uninvited.")
		ship.velocity = -approach_dir() * 120.0 + ship.velocity.bounce(approach_dir()) * 0.2
		Sfx.play_at("scrape", ship.global_position, -6.0, 0.5)
		return
	if s.error >= CRASH_ERROR:
		Sfx.play_at("scrape", ship.global_position, -3.0, 0.65)
		ship.take_damage(s.error * CRASH_DAMAGE_SCALE)
		ship.velocity = -approach_dir() * 160.0 + ship.velocity.bounce(approach_dir()) * 0.2
		return
	if s.error > SCRAPE_FREE_ERROR:
		Sfx.play_at("scrape", ship.global_position, -8.0)
		ship.take_damage(s.error * CRASH_DAMAGE_SCALE * 0.45)
	if not ship.dead:
		Sfx.play("dock", -8.0)
		ship.dock(self)
