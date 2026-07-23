extends Node
## Player SETTINGS — audio volumes + fullscreen. Persisted SEPARATELY from the
## save game (user://bleakflame_settings.json) so they survive New Game and a
## wiped profile. Autoloaded as `Settings`, applied at launch before any scene.
## Audio routes through the Master / Music / SFX buses (default_bus_layout.tres);
## the volumes are linear 0..1 and map to bus dB.

const PATH := "user://bleakflame_settings.json"

var master := 0.9
var music := 0.8
var sfx := 0.9
var fullscreen := false


func _ready() -> void:
	_load()
	apply_all()


func apply_all() -> void:
	_apply_bus("Master", master)
	_apply_bus("Music", music)
	_apply_bus("SFX", sfx)
	_apply_fullscreen()


func volume(which: String) -> float:
	match which:
		"master": return master
		"music": return music
		"sfx": return sfx
	return 1.0


func set_volume(which: String, v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	match which:
		"master": master = v; _apply_bus("Master", v)
		"music": music = v; _apply_bus("Music", v)
		"sfx": sfx = v; _apply_bus("SFX", v)
	save()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_fullscreen()
	save()


func _apply_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	# linear_to_db(0) is -inf; mute at the floor instead of a blast of noise.
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, v)))


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"master": master, "music": music, "sfx": sfx,
			"fullscreen": fullscreen}, "\t"))


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data == null:
		return
	master = clampf(float(data.get("master", master)), 0.0, 1.0)
	music = clampf(float(data.get("music", music)), 0.0, 1.0)
	sfx = clampf(float(data.get("sfx", sfx)), 0.0, 1.0)
	fullscreen = bool(data.get("fullscreen", fullscreen))
