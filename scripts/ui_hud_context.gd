extends RefCounted

const QUIET_TIME := 2.3
const READING_TIME := 7.0
const IDLE_FADE_SECONDS := 0.65
const IDLE_ALPHA := 0.24
const QUEST_FOLD_SECONDS := 0.54
var quest_folded := false
var quest_fold_progress := 0.0
var magic_alpha := 1.0
var quest_left := QUIET_TIME
var magic_left := QUIET_TIME
var _quest_signature := ""
var _has_quest := false

func tick(dt: float, quest: Dictionary, magic_relevant: bool, enabled: bool = true, motion: bool = true) -> void:
	dt = maxf(0.0, dt) if is_finite(dt) else 0.0
	var was_folded := quest_folded
	var previous_reading_time := quest_left
	var quest_visual_time := dt
	_has_quest = not quest.is_empty()
	var signature := "%s|%s|%s" % [quest.get("id", ""), quest.get("objective", ""), quest.get("progress", "")] if _has_quest else ""
	if signature != _quest_signature:
		_quest_signature = signature
		quest_left = QUIET_TIME
		quest_visual_time = 0.0
	else:
		quest_left = maxf(0.0, quest_left - dt)
	var fade_time := dt
	if magic_relevant:
		magic_left = QUIET_TIME
	else:
		fade_time = maxf(0.0, dt - magic_left)
		magic_left = maxf(0.0, magic_left - dt)
	quest_folded = enabled and _has_quest and quest_left <= 0.0
	if quest_folded and not was_folded:
		quest_visual_time = maxf(0.0, dt - previous_reading_time)
	var fold_target := 1.0 if quest_folded else 0.0
	quest_fold_progress = move_toward(quest_fold_progress, fold_target, quest_visual_time / QUEST_FOLD_SECONDS) if motion else fold_target
	if quest_fold_progress < 1.0e-06: quest_fold_progress = 0.0
	elif quest_fold_progress > 0.999999: quest_fold_progress = 1.0
	if not _has_quest: quest_fold_progress = 0.0
	var target := IDLE_ALPHA if enabled and magic_left <= 0.0 else 1.0
	magic_alpha = move_toward(magic_alpha, target, fade_time * (1.0 - IDLE_ALPHA) / IDLE_FADE_SECONDS)
	if not enabled or magic_relevant: magic_alpha = 1.0

func reveal_quest() -> void:
	quest_left = READING_TIME
	quest_folded = false

func fold_quest() -> void:
	quest_left = 0.0
	quest_folded = _has_quest

func reveal_magic() -> void:
	magic_left = QUIET_TIME
	magic_alpha = 1.0
