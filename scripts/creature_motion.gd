extends RefCounted


const Profiles = preload("res://scripts/creature_animation_profiles.gd")
const Attacks = preload("res://scripts/enemy_attack_motion.gd")
const EMPTY: Array = []

static func _rotate(node: Node3D, offset: Vector3) -> void:
	if node == null: return
	if not node.has_meta("pose_rest_rotation"): node.set_meta("pose_rest_rotation", node.rotation)
	node.rotation = node.get_meta("pose_rest_rotation") + offset
static func _place(node: Node3D, offset: Vector3) -> void:
	if not node.has_meta("pose_rest_position"): node.set_meta("pose_rest_position", node.position)
	node.position = node.get_meta("pose_rest_position") + offset
static func _stretch(node: Node3D, factor: Vector3) -> void:
	if not node.has_meta("pose_rest_scale"): node.set_meta("pose_rest_scale", node.scale)
	node.scale = node.get_meta("pose_rest_scale") * factor
static func _pulse(value: float) -> float:
	return pow(maxf(0.0, sin(value)), 4.0)

static func _prepare_rig(rig: Dictionary) -> void:
	for key in ["ears", "tails", "wings", "knees"]:
		if not rig.has(key): rig[key] = []
	if not rig.has("features"): rig.features = {}


	if rig.features.has("mist_tail") and rig.tails.is_empty(): rig.tails = [rig.features.mist_tail]
static func _enemy_rig(actor) -> Dictionary:
	if actor.animation_profile.is_empty():
		actor.animation_profile = Profiles.for_species(actor.species_id)
		if not actor.visual_rig.is_empty(): actor.animation_rig = actor.visual_rig
		else:
			actor.animation_rig = {"ears": [], "tails": [], "wings": [], "knees": actor.knees, "features": {}}
			match actor.species_id:
				"thorn_wolf", "wild_boar": actor.animation_rig.tails = actor.leaves
				"moss_guardian", "rootling_sentinel": actor.animation_rig.features.fronds = actor.leaves
				"cinder_wisp": actor.animation_rig.features.smoke = actor.leaves
		_prepare_rig(actor.animation_rig)
	return actor.animation_rig



static func _idle_head(p: Dictionary, t: float) -> Vector3:
	var nod = sin(t * 1.33) * 0.28
	var turn = sin(t * 0.63) * 0.7 + sin(t * 1.23) * 0.15
	var tilt = sin(t * 0.91) * 0.36
	match str(p.idle):
		"fern_browse", "herb_browse", "mineral_nose":
			nod = 0.45 + _pulse(t * 0.67) * 0.72 + sin(t * 5.1) * 0.055; turn *= 0.45
		"crown_scan", "prism_turn", "horizon":
			nod = 0.28 + sin(t * 0.71) * 0.38; turn = sin(t * 0.53) * 0.85; tilt = sin(t * 0.53 + 0.6) * 0.28
		"root", "hoof_scrape", "lane_stamp":
			nod = 0.64 + _pulse(t * 0.88) * 0.65; turn = sin(t * 1.1) * 0.35; tilt = sin(t * 2.2) * 0.45
		"chew", "ruminate":
			nod = 0.49 + sin(t * 4.8) * 0.13; turn = sin(t * 0.46) * 0.38; tilt = 0.24 * sin(t * 2.4)
		"nibble", "chitter":
			nod = sin(t * 7.1) * 0.28 + _pulse(t * 1.7) * 0.55; turn = sin(t * 1.4) * 0.62; tilt = sin(t * 3.1) * 0.55
		"doze":
			nod = 0.68 + sin(t * 0.78) * 0.2; turn = sin(t * 0.37) * 0.22; tilt = 0.6 + sin(t * 0.51) * 0.17
		"croak", "bubble_throat", "cold_inhale", "furnace_inhale", "smoke_breath":
			nod = -0.24 - _pulse(t * 1.45) * 0.55; turn = sin(t * 0.69) * 0.32; tilt = sin(t * 0.94) * 0.23
		"reed_probe", "water_probe":
			nod = _pulse(t * 0.92) * 1.05; turn = sin(t * 0.57) * 0.54; tilt = -0.25 * sin(t * 1.84)
		"sight_dive", "shadow_sight":
			nod = 0.12 + _pulse(t * 1.03) * 0.94; turn = sin(t * 0.82) * 0.54; tilt = -sin(t * 0.82) * 0.35
		"sing":
			nod = -0.5 + sin(t * 6.6) * 0.13; turn = sin(t * 0.77) * 0.6; tilt = sin(t * 2.7) * 0.62
		"watch", "ledge_survey", "ledge_wake", "royal_measure":
			nod = sin(t * 0.74) * 0.24; turn = tanh(sin(t * 0.81) * 2.1) * 0.82; tilt = -turn * 0.32
		"scent_wind", "sniff", "taste_air":
			nod = 0.32 + sin(t * 5.4) * 0.1; turn = sin(t * 0.93) * 0.76; tilt = sin(t * 1.86) * 0.52
		"balance", "toe_test", "antenna", "feel":
			nod = sin(t * 2.1) * 0.41; turn = sin(t * 0.84) * 0.85; tilt = sin(t * 1.31) * 0.72
		"seed_roll", "carapace_brace", "basalt_brace", "chisel_claw":
			nod = 0.34 + _pulse(t * 1.15) * 0.4; turn = sin(t * 0.72) * 0.4; tilt = sin(t * 1.44) * 0.42
		"warm_rock", "bask":
			nod = -0.34 + sin(t * 0.61) * 0.34; turn = sin(t * 0.48) * 0.59; tilt = sin(t * 0.67) * 0.42
		"shoal", "sky_swim", "thermal":
			nod = sin(t * 1.05) * 0.42; turn = sin(t * 0.71) * 0.58; tilt = sin(t * 1.05 + 0.8) * 0.72
		"star_drift", "moon_drift", "dust_shiver":
			nod = sin(t * 1.52) * 0.34; turn = sin(t * 0.83) * 0.58; tilt = sin(t * 2.45) * 0.68
		"play":
			nod = sin(t * 2.1) * 0.54; turn = sin(t * 1.07) * 0.78; tilt = sin(t * 1.65) * 0.85
		"freeze", "edge_glint", "prism_lock", "mask_gaze":
			var glance = _pulse(t * 0.63)
			nod = -0.12 + glance * 0.4; turn = glance * 0.9; tilt = -glance * 0.55
		"growl", "fog_growl", "whistle", "flank_pause":
			nod = 0.25 + sin(t * 3.2) * 0.11; turn = sin(t * 0.72) * 0.7; tilt = sin(t * 1.44) * 0.41
		"root_settle", "sprout_listen", "wood_uncurl", "earth_rise":
			nod = 0.22 + sin(t * 0.84) * 0.53; turn = sin(t * 0.51) * 0.64; tilt = sin(t * 0.97) * 0.56
		"sticky_wobble", "parcel_twitch", "knot_test", "geode_chime":
			nod = sin(t * 2.23) * 0.44 + _pulse(t * 1.13) * 0.28; turn = sin(t * 1.11) * 0.57; tilt = sin(t * 2.23 + 0.4) * 0.73
		"beater_wind", "spear_guard", "mourning_guard", "crystal_settle", "oath_listen":
			nod = sin(t * 1.07) * 0.25; turn = sin(t * 0.59) * 0.69; tilt = -sin(t * 0.59) * 0.42
		"stone_surface", "sand_ridge", "rib_vibration", "stone_unfold":
			nod = 0.3 + sin(t * 1.46) * 0.47; turn = sin(t * 0.81) * 0.65; tilt = sin(t * 1.62) * 0.49
		"ember_gather", "sand_condense", "aurora_orbit":
			nod = sin(t * 1.13) * 0.54; turn = sin(t * 0.58) * 0.84; tilt = sin(t * 0.93) * 0.73
		"buzz_lock", "feather_shake", "eye_fold", "blade_align":
			nod = sin(t * 1.81) * 0.47; turn = sin(t * 0.91) * 0.64; tilt = sin(t * 2.72) * 0.58
		"mandible_test", "steam_vent", "web_listen", "antler_moon":
			nod = 0.18 + _pulse(t * 1.37) * 0.53; turn = sin(t * 0.67) * 0.82; tilt = sin(t * 2.01) * 0.61


	return Vector3(-nod, turn, tilt) * p.head

static func _leg_phase(gait: String, index: int, count: int) -> float:
	var side = float(index % 2)
	var pair = floorf(float(index) / 2.0)
	match gait:
		"bound", "hop", "pronk": return 0.0 if index < 2 else PI + 0.22
		"jerboa": return PI * 0.78 if index < 2 else 0.0
		"pace": return side * PI + pair * 0.16
		"amble", "crawl", "paddle": return side * PI + pair * PI * 0.55
		"six": return float((int(pair) + index % 2) % 2) * PI
		"eight": return side * PI + pair * PI * 0.43
		"spring_six": return (side * PI + pair * 0.75) if index < 4 else PI * 0.45
		"sprawl": return side * PI + pair * (PI + 0.25)
		_: return side * PI + (PI if count >= 4 and index >= 2 else 0.0)
static func _legs(legs: Array, knees: Array, p: Dictionary, t: float, gait: float, load: float, settle: float) -> void:
	var kind: String = p.gait
	var arthropod = kind == "six" or kind == "eight" or kind == "spring_six"
	var bound = kind == "bound" or kind == "pronk" or kind == "hop" or kind == "jerboa"
	for i in range(legs.size()):
		var side = -1.0 if i % 2 == 0 else 1.0
		var cycle = t * float(p.rate) + _leg_phase(kind, i, legs.size())
		var raw = sin(cycle)


		var step = signf(raw) * pow(absf(raw), lerpf(0.82, 1.65, float(p.weight)))
		var swing = maxf(0.0, -raw)
		var stride = float(p.stride) * gait
		var angle = step * stride
		var splay = 0.0
		var knee = -pow(swing, 1.35) * stride * (1.55 if bound else 1.42)


		knee -= maxf(0.0, raw) * stride * float(p.weight) * 0.16
		if arthropod:
			splay = -side * maxf(0.0, raw) * stride * 0.48
			knee = -swing * stride * 0.44
		elif kind == "wade": knee = -pow(swing, 0.7) * stride * 1.85
		elif kind == "sprawl": splay = side * raw * stride * 0.24
		elif kind == "jerboa": angle *= 0.54 if i < 2 else 1.18
		elif kind == "stalk": angle *= 0.88; knee *= 1.14

		var front_load = 1.0 if i < 2 else 0.55
		angle += load * front_load * (0.12 if arthropod else -0.1) + settle * 0.055 * front_load
		_rotate(legs[i], Vector3(angle, side * load * float(p.accent) * 0.25, splay))
		if i < knees.size(): _rotate(knees[i], Vector3(knee - load * 0.1 * front_load, 0, side * maxf(0.0, raw) * stride * 0.62 if arthropod else 0.0))

static func _secondary(rig: Dictionary, p: Dictionary, t: float, motion: float, load: float = 0.0, release: float = 0.0, settle: float = 0.0) -> void:
	for i in range(rig.ears.size()):
		var side = -1.0 if i % 2 == 0 else 1.0
		var listen = _pulse(t * (1.47 if i % 2 == 0 else 1.13) + i * 1.2)
		var flick = _pulse(t * 3.6 + i * 2.1) * listen
		_rotate(rig.ears[i], Vector3(listen * 0.11 - motion * 0.08 - load * 0.18, sin(t * 0.73 + i) * float(p.head.y) * 0.36, side * (flick * 0.22 + listen * absf(float(p.accent)))))
	var kind: String = p.gait
	var flowing = kind == "swim" or kind == "slither" or kind == "sprawl" or kind == "ray"
	for i in range(rig.tails.size()):
		var wave = t * (float(p.rate) if flowing else 2.05) - float(i) * 0.57
		var sweep = sin(wave) * (float(p.tail.x) + motion * float(p.tail.y))
		var pitch = float(p.tail.z) + sin(t * 1.31 - float(i) * 0.43) * 0.035
		if kind == "slither": pitch += sin(wave * 0.72) * (0.025 + load * 0.09)
		if str(p.attack) == "tail_sting": pitch -= load * 0.49 - release * 0.18
		sweep *= 1.0 - settle * 0.48
		pitch += sin(settle * PI) * float(p.tail.y) * 0.12
		if str(p.attack) == "resonate": sweep += sin(t * 10.0 - float(i) * 0.9) * (load * 0.13 + settle * 0.075)
		_rotate(rig.tails[i], Vector3(pitch, sweep * (1.0 - load * 0.45) + float(p.accent) * load, sin(wave + 0.7) * 0.035 if flowing else 0.0))
	var features: Dictionary = rig.features
	if features.has("fern_ears"): _rotate(features.fern_ears, Vector3(sin(t * 1.47) * 0.052 - motion * 0.09, sin(t * 0.67) * 0.07, _pulse(t * 1.13) * 0.095))
	if features.has("seedlit_antlers"): _rotate(features.seedlit_antlers, Vector3(sin(t * 1.11) * 0.012, 0, sin(t * 0.83) * 0.016))
	if features.has("moss_brow"): _rotate(features.moss_brow, Vector3(sin(t * 2.2) * 0.035, 0, sin(t * 1.1) * 0.022))
	if features.has("glowing_throat"): _stretch(features.glowing_throat, Vector3.ONE * (1.0 + _pulse(t * 3.3) * 0.045))
	if features.has("jaw"): _rotate(features.jaw, Vector3(-0.025 - _pulse(t * 2.1) * 0.045 - load * (0.71 if str(p.attack) == "snap" else 0.46) + release * 0.3 - settle * 0.11, 0, 0))
	for i in range(features.get("fronds", EMPTY).size()):
		_rotate(features.fronds[i], Vector3(sin(t * 1.6 - i * 0.6) * (0.045 + motion * 0.045) + settle * 0.08, 0, sin(t * 1.13 + i) * 0.025))
	for i in range(features.get("smoke", EMPTY).size()):
		var plume: Node3D = features.smoke[i]
		_place(plume, Vector3(sin(t * 2.3 + i) * (0.045 + load * 0.035), sin(t * 1.8 - i) * 0.035, 0))
		_rotate(plume, Vector3(sin(t * 1.7 + i) * 0.06, sin(t * 1.3 + i) * 0.09, sin(t * 2.2 + i) * 0.075))
		_stretch(plume, Vector3.ONE * (1.0 + sin(t * 3.5 + i) * 0.045 + load * 0.14 - release * 0.08))

static func _wings(rig: Dictionary, p: Dictionary, t: float, movement: float, load: float, release: float, airborne: bool, settle: float = 0.0) -> void:
	var kind: String = p.gait
	var cycle = t * float(p.rate)
	var beat = sin(cycle)
	var spread = 0.52
	var bank = sin(t * 0.83) * float(p.accent) * 0.18
	match kind:
		"flutter": beat = sin(cycle) * 0.78 + sin(cycle * 2.0) * 0.19; spread = 0.81
		"hover": beat = sin(cycle); spread = 0.49
		"glide": beat = sin(cycle) * _pulse(t * 0.63); spread = 0.58
		"ray": beat = sin(cycle) * 0.71 + sin(cycle * 2.0) * 0.11; spread = 0.43
		"flight": beat = signf(beat) * pow(absf(beat), 0.73); spread = 0.61 + float(p.weight) * 0.18
	for i in range(rig.wings.size()):
		var side = -1.0 if i % 2 == 0 else 1.0
		var flap = side * (0.11 + beat * spread)
		var sweep = side * (0.055 + sin(cycle - 0.65) * 0.065)
		if not airborne:


			flap = -side * (0.36 + movement * 0.05 + _pulse(t * 0.73) * 0.025 * (1.0 - movement))
			sweep = -side * (1.2 + sin(t * 0.61) * 0.018)
		match str(p.attack):
			"fold": flap = lerpf(flap, side * 0.93, load) * (1.0 - release * 0.85) + side * settle * 0.19
			"align": flap = lerpf(flap, side * 0.06, load) + side * (release * 0.4 + settle * 0.22); sweep += side * (load * 0.23 - settle * 0.1)
			"dive": flap = lerpf(flap, side * 0.2, load) * (1.0 - settle * 0.36); sweep += side * (load * 0.38 - settle * 0.17)
			"gust": flap += side * (load * 0.7 - release * 0.8 - settle * 0.24)
			"sting": sweep += side * (load * 0.22 - release * 0.29 - settle * 0.12)
		_rotate(rig.wings[i], Vector3(0.065 + absf(beat) * 0.07 + load * 0.08, sweep, flap + bank))

static func wildlife_pose(critter: Dictionary, time: float, dt: float, movement: float, fleeing: bool) -> void:
	if not critter.has("animation_profile"):
		critter.animation_profile = Profiles.for_species(critter.species)
		_prepare_rig(critter.visual_rig)
	var p: Dictionary = critter.animation_profile
	var rig: Dictionary = critter.visual_rig
	var gait = lerpf(float(critter.get("gait", 0.0)), clampf(movement, 0.0, 1.0), 1.0 - exp(-maxf(0.0, dt) * 9.0))
	critter.gait = gait
	var t = time + float(critter.phase)
	var idle = 1.0 - gait
	var kind: String = p.gait
	var cycle = t * float(p.rate)
	var breath = sin(t * (1.35 if float(p.weight) > 0.65 else 2.1)) * 0.004
	var lift = absf(sin(cycle)) * 0.02 * gait * (1.0 - float(p.weight) * 0.55)
	var lean = 0.0
	match kind:
		"bound", "pronk", "hop", "jerboa", "spring_six":
			lift = pow(maxf(0.0, sin(cycle)), 1.55) * (0.105 if kind != "jerboa" else 0.15) * gait
			lean = sin(cycle - 0.5) * 0.07 * gait
		"creep": lift = sin(cycle * 2.0) * 0.003 * gait
		"swim": lift = sin(cycle * 0.5) * 0.012; lean = sin(cycle * 0.5) * 0.025
		"paddle": lean = sin(cycle) * 0.025 * gait
		"pace": lean = sin(cycle) * 0.018 * gait
		"glide", "ray", "flight", "flutter", "hover": lift = sin(cycle * 0.5) * 0.009; lean = sin(t * 0.83) * 0.018
	_place(critter.body, Vector3(0, lift + breath * 0.5, 0))
	_stretch(critter.body, Vector3(1.0 - breath * 0.25, 1.0 + breath, 1.0))


	var head_pose = _idle_head(p, t) * idle
	if fleeing: head_pose = Vector3(-0.1 - float(p.head.x) * 0.28, sin(t * 1.2) * float(p.head.y) * 0.2, -float(p.accent) * 0.12)
	head_pose.x -= lean
	_rotate(critter.head, head_pose)
	_legs(critter.legs, rig.knees, p, t, gait, 0.12 if fleeing and kind == "jerboa" else 0.0, 0.0)
	_wings(rig, p, t, gait, 0.0, 0.0, bool(critter.flying))
	_secondary(rig, p, t, gait)

static func _arm_tell(p: Dictionary, progress: float, index: int) -> Vector3:
	var side = -1.0 if index % 2 == 0 else 1.0
	var load = smoothstep(0.0, 0.72, progress)
	var release = smoothstep(0.79, 1.0, progress)
	var peak = 2.65
	var contact = 0.25
	var yaw = 0.0
	var spread = 0.055 + load * 0.13
	match str(p.attack):
		"sweep", "royal_cleave", "guard_cut": peak = 2.25; contact = 0.52; yaw = side * (load * 0.38 - release * 0.57); spread += load * 0.16
		"thrust": peak = 1.4 if index == 0 else 0.72; contact = 1.04 if index == 0 else 0.31; yaw = -side * load * 0.13
		"mix": peak = 2.08 + side * 0.22; contact = 0.62; yaw = sin(progress * TAU + side) * load * 0.22
		"breath": peak = 1.31; contact = 0.43; spread += load * 0.23; yaw = side * load * 0.18
		"cast", "condense", "gaze", "aurora", "beam": peak = 1.45 + side * float(p.accent); contact = 0.83; yaw = -side * load * 0.22; spread += load * 0.15
		"uncurl": peak = 2.2 + side * 0.15; contact = 0.42; spread += load * 0.25; yaw = side * load * 0.24
		"root_slap": peak = 2.3 + side * 0.19; contact = 0.31; spread += load * 0.1
		"sticky_slam": peak = 2.74; contact = 0.18; yaw = sin(progress * PI) * float(p.accent) * 0.38
		"stomp": peak = 1.9; contact = 0.38; spread += load * 0.21
		"hammer": peak = 2.81 if index == 0 else 2.48; contact = 0.29; spread += load * 0.05
	return Vector3(lerpf(0.045, peak, load) * (1.0 - release) + contact * release, yaw, side * spread)

static func _arm_recovery(p: Dictionary, settle: float, index: int) -> Vector3:
	var side = -1.0 if index % 2 == 0 else 1.0
	var pitch = settle * (0.25 + float(p.weight) * 0.08)
	var yaw = 0.0
	var spread = 0.0
	match str(p.attack):
		"sweep": pitch = settle * 0.46; yaw = -side * settle * 0.3; spread = side * settle * 0.09
		"royal_cleave": pitch = settle * (0.53 if index == 0 else 0.38); yaw = -side * settle * 0.35
		"guard_cut": pitch = settle * 0.39; yaw = -side * settle * 0.23
		"thrust": pitch = settle * (1.04 if index == 0 else 0.31); yaw = side * settle * 0.08
		"cast", "condense", "gaze", "aurora", "beam": pitch = settle * 0.74; yaw = -side * settle * 0.17; spread = side * settle * 0.1
		"breath": pitch = settle * 0.4; spread = side * settle * 0.15
		"uncurl": pitch = settle * 0.4; yaw = side * settle * 0.11; spread = side * settle * 0.2
		"stomp": pitch = settle * 0.52; spread = side * settle * 0.08
		"mix": pitch = settle * (0.58 + side * 0.11); yaw = side * sin(settle * PI) * 0.18
		"root_slap": pitch = settle * 0.4; yaw = side * settle * 0.14
		"sticky_slam": pitch = settle * 0.42 * (1.0 + sin(settle * TAU) * 0.15)
		"hammer": pitch = settle * (0.5 if index == 0 else 0.3); yaw = side * settle * 0.1
	return Vector3(pitch, yaw, spread)

static func enemy_pose(actor, dt: float, speed: float) -> void:
	_enemy_pose(actor, dt, speed, false)



static func enemy_contact_pose(actor) -> void:
	_enemy_pose(actor, 0.0, 0.0, true)

static func _enemy_pose(actor, dt: float, speed: float, contact: bool) -> void:
	var rig: Dictionary = _enemy_rig(actor)
	var p: Dictionary = actor.animation_profile
	actor.gait_weight = lerpf(actor.gait_weight, clampf(speed, 0.0, 1.0), 1.0 - exp(-maxf(0.0, dt) * 8.0))
	var gait: float = actor.gait_weight
	var t: float = actor.clock
	var progress = clampf(1.0 - actor.windup / float(actor.profile.windup), 0.0, 1.0) if actor.windup > 0.0 else 0.0
	var settle = clampf(actor.recovery / float(actor.profile.recovery), 0.0, 1.0)
	if contact: progress = 1.0; settle = 0.0
	var load = smoothstep(0.0, 0.7, progress) * (1.0 - smoothstep(0.82, 1.0, progress))
	var release = smoothstep(0.76, 1.0, progress)
	var weight: float = p.weight
	var cycle = t * float(p.rate)
	var idle = 1.0 - gait
	var bob = absf(sin(cycle)) * 0.028 * gait * (1.0 - weight * 0.62)
	var roll = sin(cycle * 0.5) * gait * (0.018 + absf(float(p.accent)) * 0.025)
	var lean = -load * 0.12 + release * 0.09 + settle * 0.1
	var head_pose = _idle_head(p, t) * idle
	var kind: String = p.gait
	var breath = sin(t * (1.35 if weight > 0.7 else 1.9)) * 0.0035 * idle
	match str(p.attack):
		"charge", "stamp", "pounce", "web_pounce", "rush", "feint", "whistle_lunge", "growl_lunge", "refract", "antler":
			lean = load * 0.13 - release * 0.16 + settle * 0.12
			head_pose.x -= load * (0.23 + float(p.head.x)) - 0.12 * release
			bob -= load * 0.028
		"snap", "split":
			head_pose.x -= load * 0.17 - release * 0.12; roll += float(p.accent) * load * 0.18
		"rise", "emerge", "resonate":
			lean = -load * 0.16 + release * 0.12 + settle * 0.09
			head_pose.x += load * 0.3 - release * 0.12
			bob += sin(progress * PI) * 0.035
		"spray", "breath", "vent":
			head_pose.x += load * 0.25 - release * 0.32
			breath += load * 0.014 - release * 0.006
		"spin", "claw_spread", "unfold", "tail_sting":
			roll += load * float(p.accent) * 0.25; head_pose.y += load * float(p.accent)
		_:
			head_pose.x -= load * 0.19 - release * 0.08
			head_pose.z += float(p.accent) * load * 0.23
	if settle > 0.0:
		match str(p.attack):
			"charge", "stamp", "pounce", "web_pounce", "rush", "feint", "whistle_lunge", "growl_lunge", "refract", "antler":
				head_pose.x -= settle * (0.08 + float(p.head.x) * 0.2)
				head_pose.y += sin(settle * PI) * float(p.accent) * 0.35
			"sweep", "royal_cleave", "guard_cut": head_pose.y -= settle * float(p.accent) * 0.38; roll -= settle * float(p.accent) * 0.08
			"rise", "emerge", "resonate": head_pose.x += settle * 0.095
			"cast", "condense", "gaze", "aurora", "beam": head_pose.x -= settle * 0.06
	if kind == "hop": bob += maxf(0.0, sin(cycle)) * 0.065 * gait
	if kind == "slither": roll += sin(cycle * 0.5) * (0.012 + gait * 0.02); lean += sin(cycle * 0.5) * 0.015 * gait
	if kind == "float": bob = 0.13 + sin(t * 1.6) * (0.055 + float(p.stride) * 0.15); roll += sin(t * 0.89) * float(p.accent) * 0.12
	if not rig.wings.is_empty(): bob += 0.1 + sin(t * 2.0) * 0.045
	_place(actor.model, Vector3(0, bob - sin(settle * PI) * (0.025 + weight * 0.02), 0))
	actor.model.rotation.x = lean
	actor.model.rotation.z = roll
	actor.model.scale = actor.rest_scale * Vector3(1.0 + load * 0.018 - breath * 0.25, 1.0 - load * 0.025 + breath, 1.0 + load * 0.018)
	head_pose.z -= roll * 0.45
	_rotate(actor.head, head_pose)
	_legs(actor.feet, actor.knees, p, t, gait, load, settle)
	for i in range(actor.arms.size()):
		var side = -1.0 if i % 2 == 0 else 1.0
		var arm_pose = Vector3(-sin(cycle + i * PI) * float(p.stride) * 0.78 * gait, 0, side * (0.035 + absf(float(p.accent)) * 0.09)) + _arm_recovery(p, settle, i)
		if actor.windup > 0.0: arm_pose = _arm_tell(p, progress, i)
		elif str(p.idle) == "beater_wind": arm_pose.y = sin(t * 2.2 + i * PI) * 0.13 * idle
		elif kind == "stalk": arm_pose.x += sin(t * 1.23 + i) * 0.035 * idle; arm_pose.z += side * 0.035 * idle
		_rotate(actor.arms[i], arm_pose)
		if i < actor.forearms.size(): _rotate(actor.forearms[i], Vector3(-0.1 - load * (0.22 + weight * 0.13) - settle * 0.055, side * load * float(p.accent) * 0.22, 0))


	var secondary_release = release
	var secondary_settle = settle
	if actor.windup <= 0.0 and (settle > 0.0 or actor.charge_time > 0.0) and not contact:
		secondary_release = 1.0 if actor.charge_time > 0.0 else settle
		secondary_settle = settle * (1.0 - settle)
	_wings(rig, p, t, gait, load, secondary_release, true, secondary_settle)
	_secondary(rig, p, t, gait, load, secondary_release, secondary_settle)
	Attacks.apply(actor, progress, settle, contact)
	if not contact: enemy_hurt_pose(actor)



static func enemy_hurt_pose(actor) -> void:
	if actor.hurt_timer <= 0.0: return
	var p: Dictionary = actor.animation_profile
	var rig: Dictionary = actor.animation_rig
	var remaining = clampf(actor.hurt_timer / 0.3, 0.0, 1.0)
	var hurt = remaining * remaining * (3.0 - 2.0 * remaining)

	if actor.windup > 0.0 or actor.charge_time > 0.0: hurt *= 0.42
	var side: float = actor.hurt_side
	var weight: float = p.weight
	var pitch = 0.16 - weight * 0.045
	var roll = side * 0.075
	var lift = -0.035
	var back = 0.105
	var head = Vector3(0.28, side * 0.12, -side * 0.1)
	var arm = 0.28
	var brace = 0.08
	match str(p.gait):
		"six", "eight", "crawl", "scurry":
			pitch = -0.07; roll = side * 0.13; lift = -0.04; back = 0.09
			head = Vector3(0.23, -side * 0.16, side * 0.12); arm = 0.15; brace = 0.2
		"digitigrade", "amble", "pace", "trot", "pronk", "sprawl":
			pitch = 0.1; roll = side * 0.085; lift = -0.05; back = 0.13
			head = Vector3(0.34, side * 0.15, -side * 0.09); arm = 0.19; brace = 0.12
		"float", "hover", "flutter", "flight", "ray":
			pitch = -0.12; roll = side * 0.21; lift = 0.065; back = 0.16
			head = Vector3(0.24, -side * 0.18, side * 0.15); arm = 0.24; brace = 0.05
		"slither":
			pitch = 0.07; roll = side * 0.17; lift = -0.025; back = 0.12
			head = Vector3(0.27, side * 0.28, -side * 0.13); arm = 0.13; brace = 0.07
	actor.model.position += Vector3(side * 0.025, lift, back) * hurt
	actor.model.rotation.x += pitch * hurt
	actor.model.rotation.z += roll * hurt
	actor.model.scale *= Vector3(1.0 + 0.025 * hurt, 1.0 - 0.035 * hurt, 1.0 + 0.02 * hurt)
	if actor.head != null: actor.head.rotation += head * hurt
	for i in range(actor.arms.size()):
		var limb_side = -1.0 if i % 2 == 0 else 1.0
		actor.arms[i].rotation += Vector3(arm, side * 0.07, limb_side * 0.14) * hurt
		if i < actor.forearms.size(): actor.forearms[i].rotation.x -= 0.23 * hurt
	for i in range(actor.feet.size()):
		var limb_side = -1.0 if i % 2 == 0 else 1.0
		actor.feet[i].rotation += Vector3(-brace, limb_side * brace * 0.6, limb_side * brace) * hurt
		if i < actor.knees.size(): actor.knees[i].rotation.x -= brace * 1.3 * hurt
	for wing in rig.get("wings", EMPTY): wing.rotation.z += side * 0.38 * hurt
	for tail in rig.get("tails", EMPTY): tail.rotation.y -= side * 0.24 * hurt
	for ear in rig.get("ears", EMPTY): ear.rotation.x += 0.2 * hurt
