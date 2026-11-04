extends Node

var state
var streams: Dictionary = {}
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var voice_cursor: int = 0
var rain_level: float = 0.0
var music_gain: float = 0.08
var last_master: float = -1
var region: int = 0
const MAGIC_ELEMENTS := ["flame", "frost", "storm", "grove", "light", "shadow", "water", "wind", "earth", "metal", "void", "time"]
const MAGIC_PHASES := ["release", "flight", "impact"]
var magic_streams: Dictionary = {}
var magic_voices: Array[AudioStreamPlayer] = []
var magic_cursors := {"release": 0, "flight": 0, "impact": 0}
var last_step_surface = "grass"
var step_cursor = 0
var regional_ambience: AudioStreamPlayer
var regional_streams: Dictionary = {}
var ambient_key = "forest"
var indoors = false

func _ready() -> void:
	for id in ["step", "land", "jump", "grip", "throw", "punch", "beam", "hook", "bag", "hurt", "impact", "collect", "shrine", "ui", "splash"]:
		streams[id] = load("res://assets/audio/" + id + ".wav")
	music = loop_player("music", -22)
	ambience = loop_player("wind", -24)
	rain_player = loop_player("rain", -80)
	for surface in ["grass", "sand", "stone", "wood", "glass"]:
		for i in range(3):
			var key = "step_" + surface + "_" + str(i)
			streams[key] = load("res://assets/audio/polish/" + key + ".wav")
	for key in ["forest", "sweets", "field", "desert", "volcano", "haunted", "crystal"]:
		var stream: AudioStreamWAV = load("res://assets/audio/polish/ambience_" + key + ".wav")
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD; stream.loop_begin = 0; stream.loop_end = int(stream.get_length() * stream.mix_rate)
		regional_streams[key] = stream
	regional_ambience = AudioStreamPlayer.new(); regional_ambience.stream = regional_streams.forest; regional_ambience.volume_db = -46; add_child(regional_ambience); regional_ambience.play()
	for i in range(16):
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
		if i < 8: magic_voices.append(voice)
	for element in MAGIC_ELEMENTS:
		for phase in MAGIC_PHASES:
			magic_streams[element + ":" + phase] = load("res://assets/audio/magic_v16/" + element + "_" + phase + ".wav")

func loop_player(id: String, gain_db: float) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load("res://assets/audio/" + id + ".wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	player.stream = stream
	player.volume_db = gain_db
	add_child(player)
	player.play()
	return player

func _process(dt: float) -> void:
	if state != null:
		var master = float(state.settings.volume)
		if not is_equal_approx(master, last_master):
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, master)))
			last_master = master
		music_gain = lerpf(music_gain, float(state.settings.music) * 0.21, 1 - exp(-dt * 3))
		music.volume_db = linear_to_db(maxf(0.0001, music_gain))
	rain_player.volume_db = lerpf(rain_player.volume_db, linear_to_db(maxf(0.0001, rain_level * 0.14)), 1 - exp(-dt * 2))
	music.pitch_scale = lerpf(music.pitch_scale, 1.015 if region == 1 else 1.0, 1 - exp(-dt))
	var wanted = {9: "forest", 10: "sweets", 11: "field", 12: "desert", 13: "volcano", 14: "haunted", 15: "crystal", 1: "crystal", 4: "field", 5: "desert"}.get(region, "forest")
	var target = -42.0 if not indoors else -61.0
	if wanted != ambient_key:
		regional_ambience.volume_db = move_toward(regional_ambience.volume_db, -76, dt * 70)
		if regional_ambience.volume_db <= -74:
			regional_ambience.stop(); regional_ambience.stream = regional_streams[wanted]; regional_ambience.play(); ambient_key = wanted
	else: regional_ambience.volume_db = lerpf(regional_ambience.volume_db, target, 1 - exp(-dt * 2))
	ambience.volume_db = lerpf(ambience.volume_db, -38.0 if indoors else -24.0, 1 - exp(-dt * 2))

func set_context(biome: int, rain: float, interior: bool = false) -> void:
	region = biome
	indoors = interior
	rain_level = 0.0 if indoors else clampf(rain, 0, 1)

func step(surface: String) -> void:
	last_step_surface = surface if surface in ["grass", "sand", "stone", "wood", "glass"] else "grass"
	step_cursor = (step_cursor + 1) % 3
	cue("step_" + last_step_surface + "_" + str(step_cursor), [0.97, 1.015, 1.04][step_cursor])

func cue(id: String, pitch_value: float = 1.0) -> void:
	if not streams.has(id) or voices.is_empty():
		return
	var voice: AudioStreamPlayer
	for candidate in voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		voice_cursor = (voice_cursor + 1) % voices.size()
		voice = voices[voice_cursor]
	voice.stop()
	voice.stream = streams[id]
	voice.pitch_scale = clampf(pitch_value, 0.7, 1.35)
	voice.volume_db = -20 if id.begins_with("step") else -18 if id == "ui" else -15 if id in ["grip", "bag", "splash"] else -11
	voice.play()

func magic_cue(element: String, phase: String, power: float = 1.0) -> void:


	if magic_voices.size() < 8 or not phase in MAGIC_PHASES: return
	if element == "gravity": element = "void"
	if not element in MAGIC_ELEMENTS: element = "light"
	var key := element + ":" + phase
	if not magic_streams.has(key) or magic_streams[key] == null: return
	var first := 0 if phase == "release" else 3 if phase == "flight" else 5
	var amount := 2 if phase == "flight" else 3
	var index := first + int(magic_cursors[phase]) % amount
	magic_cursors[phase] = (int(magic_cursors[phase]) + 1) % amount
	var voice: AudioStreamPlayer = magic_voices[index]
	voice.stop(); voice.stream = magic_streams[key]
	voice.pitch_scale = randf_range(0.96, 1.04)
	var strength := clampf(power, 0.0, 6.0) if is_finite(power) else 1.0
	var base := -24.0 if phase == "flight" else -17.0 if phase == "release" else -16.0
	voice.volume_db = minf(-12.0, base + minf(3.0, strength * 0.5))
	voice.play()

func _exit_tree() -> void:
	for node in get_children():
		if node is AudioStreamPlayer:
			node.stream_paused = false
			node.stop()
			node.stream = null
	streams.clear()
	voices.clear()
	magic_streams.clear()
	magic_voices.clear()
	regional_streams.clear()
