extends Node
## Procedural retro SFX. Every sound is synthesized to PCM at startup — no
## audio assets, everything tunable in code. Registered as the "Sfx" autoload.
## play() = flat/UI sounds; play_at() = positional world sounds.

const SAMPLE_RATE := 22050

var _streams := {}
var _world_pool: Array[AudioStreamPlayer2D] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _world_i := 0
var _ui_i := 0


func _ready() -> void:
	_build_synth_streams()
	# Real audio overrides: drop files in res://audio/sfx/<name>.(ogg|wav|mp3)
	# and they replace the synth automatically. Same names as the table below.
	for sound in _streams.keys():
		var override = _find_audio("res://audio/sfx/" + sound)
		if override != null:
			_streams[sound] = override
	# Bus routing (default_bus_layout.tres): SFX pools + world audio on "SFX",
	# music on "Music", voice on Master — so the Options sliders control each.
	for i in 12:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 1400.0
		p.attenuation = 1.4
		p.bus = "SFX"
		add_child(p)
		_world_pool.append(p)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_ui_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -12.0
	_music.bus = "Music"
	add_child(_music)
	_voice = AudioStreamPlayer.new()
	add_child(_voice)


var _music: AudioStreamPlayer
var _music_track := ""
## ONE dedicated channel for dialogue / quest / tutorial voice. Single so a
## new line cuts the previous, and stop_voice() silences it the instant a
## step or dialogue node changes — no two quest voices ever overlap. Combat
## SFX (the pools) are untouched.
var _voice: AudioStreamPlayer
## Lines already spoken this docking session (for `once` VO); cleared on undock.
var _vo_session := {}


## Loops res://audio/music/<track>.(ogg|wav|mp3) if present; silent otherwise.
func play_music(track: String) -> void:
	if track == _music_track:
		return
	_music_track = track
	var stream_res = _find_audio("res://audio/music/" + track)
	if stream_res == null:
		_music.stop()
		return
	if stream_res is AudioStreamOggVorbis:
		stream_res.loop = true
	elif stream_res is AudioStreamMP3:
		stream_res.loop = true
	elif stream_res is AudioStreamWAV:
		stream_res.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music.stream = stream_res
	_music.play()


## Voice lines: res://audio/vo/<name>.(ogg|wav|mp3). Silent if absent.
## Fire-and-forget on the round-robin pool — for one-offs that may overlap.
func play_vo(line: String, volume_db := -4.0) -> void:
	var stream_res = _find_audio("res://audio/vo/" + line)
	if stream_res == null:
		return
	var p := _ui_pool[_ui_i]
	_ui_i = (_ui_i + 1) % _ui_pool.size()
	p.stream = stream_res
	p.volume_db = volume_db
	p.pitch_scale = 1.0
	p.play()


## Interruptible voice: dialogue / quest / tutorial lines play HERE. Starting
## a line cuts whatever was speaking; a step transition calls stop_voice().
## Returns true if a clip was found. Empty `line` just stops the channel.
func play_voice(line: String, volume_db := -4.0, once := false) -> bool:
	_voice.stop()
	if line == "":
		return false
	# `once`: a line tagged play-once-per-docking-session (an NPC intro, say) is
	# silenced when its node is shown again this session — so re-reading a
	# dialogue's main message doesn't replay the greeting. reset_vo_session()
	# (called on undock) opens it up again for the next visit.
	if once and _vo_session.has(line):
		return false
	var stream_res = _find_audio("res://audio/vo/" + line)
	if stream_res == null:
		return false
	if once:
		_vo_session[line] = true
	_voice.stream = stream_res
	_voice.volume_db = volume_db
	_voice.play()
	return true


## Silence the quest/dialogue voice — call before advancing a step so a
## still-playing line never bleeds into the next.
func stop_voice() -> void:
	_voice.stop()


## How long the voice line CURRENTLY SPEAKING runs (seconds), 0 if none is playing.
## Lets a caller time another sound to land over the tail of a line — e.g. the
## static that crashes over Krayt's last words. Gated on `playing` so a missing VO
## clip (drop-in art absent) reports 0, not a stale previous line's length.
func voice_length() -> float:
	if _voice.playing and _voice.stream != null:
		return _voice.stream.get_length()
	return 0.0


## Clear the play-once-per-docking-session VO memory (call on undock).
func reset_vo_session() -> void:
	_vo_session.clear()


func _find_audio(base_path: String):
	for ext in [".ogg", ".wav", ".mp3"]:
		if ResourceLoader.exists(base_path + ext):
			return load(base_path + ext)
	return null


func _build_synth_streams() -> void:
	_streams = {
		"pew": _sweep(900.0, 280.0, 0.12, true),
		# A deeper, longer report than "pew" for the heavy profession guns
		# (Killshot, Lance). Drop-in audio/sfx/shot.* overrides it.
		"shot": _sweep(520.0, 120.0, 0.2, true),
		"hit": _noise_burst(0.06, 30.0, 0.5),
		"shield_hit": _sweep(1300.0, 700.0, 0.09, false),
		"explosion": _explosion(0.6),
		"pickup": _sweep(480.0, 960.0, 0.1, false),
		"dock": _tones([440.0, 660.0], 0.11),
		"jingle": _tones([523.25, 659.25, 783.99], 0.1),
		"scrape": _noise_burst(0.3, 9.0, 0.25),
		"slide": _noise_burst(0.35, 7.0, 0.3),
		"click": _sweep(900.0, 700.0, 0.025, true),
		"thrust_loop": _thrust_loop(0.5),
		"dread": _sweep(85.0, 30.0, 1.7, false),
		# A channel dissolving into static — a transmission cut off mid-word. Used
		# when a leviathan devours a ship (the distress goes dead) and at the end
		# of Krayt's final transmission. Drop-in audio/sfx/static.* overrides it.
		"static": _noise_burst(0.8, 1.8, 0.6),
	}


func play(sound: String, volume_db := -8.0, pitch := 1.0) -> void:
	var stream = _streams.get(sound)
	if stream == null:
		push_warning("Sfx.play: no sound named '%s' — ignored." % sound)
		return
	var p := _ui_pool[_ui_i]
	_ui_i = (_ui_i + 1) % _ui_pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_at(sound: String, pos: Vector2, volume_db := -6.0, pitch := 1.0) -> void:
	var stream = _streams.get(sound)
	if stream == null:
		push_warning("Sfx.play_at: no sound named '%s' — ignored." % sound)
		return
	var p := _world_pool[_world_i]
	_world_i = (_world_i + 1) % _world_pool.size()
	p.global_position = pos
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.96, 1.05)
	p.play()


func stream(sound: String) -> AudioStreamWAV:
	return _streams[sound]


# --- synthesis ---

func _make_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav


## Frequency sweep with exponential decay. Square-ish = laser, sine = chime.
func _sweep(f0: float, f1: float, dur: float, square: bool) -> AudioStreamWAV:
	var n := int(dur * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(f0, f1, t) / SAMPLE_RATE
		var s := sin(phase)
		if square:
			s = signf(s) * 0.55
		out[i] = s * 0.8 * exp(-4.0 * t)
	return _make_wav(out)


## Filtered white noise burst; higher decay = sharper, lower lowpass = duller.
func _noise_burst(dur: float, decay: float, lowpass: float) -> AudioStreamWAV:
	var n := int(dur * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / n
		prev += lowpass * (randf_range(-1.0, 1.0) - prev)
		out[i] = prev * 0.9 * exp(-decay * t)
	return _make_wav(out)


## Noise burst over a low rumble — bigger ships play it pitched down.
func _explosion(dur: float) -> AudioStreamWAV:
	var n := int(dur * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		prev += 0.18 * (randf_range(-1.0, 1.0) - prev)
		phase += TAU * 55.0 / SAMPLE_RATE
		out[i] = (prev * 0.85 + sin(phase) * 0.35) * exp(-5.0 * t)
	return _make_wav(out)


## Short note sequence (docking chime, reward jingle).
func _tones(freqs: Array, each: float) -> AudioStreamWAV:
	var per := int(each * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(per * freqs.size())
	for note in freqs.size():
		var phase := 0.0
		for i in per:
			var t := float(i) / per
			phase += TAU * freqs[note] / SAMPLE_RATE
			out[note * per + i] = sin(phase) * 0.7 * exp(-3.0 * t)
	return _make_wav(out)


## Looping engine rumble: heavily lowpassed noise at constant level.
func _thrust_loop(dur: float) -> AudioStreamWAV:
	var n := int(dur * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		prev += 0.06 * (randf_range(-1.0, 1.0) - prev)
		out[i] = prev * 0.9
	# Soften the loop seam.
	for i in 200:
		var w := float(i) / 200.0
		out[i] = out[i] * w + out[n - 200 + i] * (1.0 - w)
	return _make_wav(out, true)
