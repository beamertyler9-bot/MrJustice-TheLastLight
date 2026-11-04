extends RefCounted

const PORTRAIT_SECONDS := 0.54
const DURATIONS := [0.72, 0.78, 0.84]
const PEAKS := [0.54, 0.69, 0.84]
const CRACKS := [
	[Vector2(18, 1), Vector2(32, 22), Vector2(22, 42), Vector2(47, 65)],
	[Vector2(1262, 1), Vector2(1248, 22), Vector2(1258, 42), Vector2(1233, 65)],
	[Vector2(18, 719), Vector2(32, 698), Vector2(22, 678), Vector2(47, 655)],
	[Vector2(1262, 719), Vector2(1248, 698), Vector2(1258, 678), Vector2(1233, 655)],
	[Vector2(1, 278), Vector2(22, 294), Vector2(12, 315), Vector2(44, 331)],
	[Vector2(1279, 278), Vector2(1258, 294), Vector2(1268, 315), Vector2(1236, 331)],
	[Vector2(410, 1), Vector2(404, 19), Vector2(426, 34), Vector2(416, 58)],
	[Vector2(875, 1), Vector2(884, 20), Vector2(862, 38), Vector2(876, 63)],
	[Vector2(405, 719), Vector2(418, 700), Vector2(403, 683), Vector2(425, 659)],
	[Vector2(877, 719), Vector2(868, 699), Vector2(889, 681), Vector2(872, 659)],
	[Vector2(47, 65), Vector2(65, 71), Vector2(61, 87)],
	[Vector2(1233, 655), Vector2(1215, 649), Vector2(1219, 633)],
	[Vector2(1, 496), Vector2(18, 482), Vector2(32, 501), Vector2(64, 508)],
	[Vector2(1279, 496), Vector2(1262, 482), Vector2(1248, 501), Vector2(1216, 508)],
	[Vector2(639, 1), Vector2(654, 19), Vector2(645, 35), Vector2(670, 55)],
	[Vector2(640, 719), Vector2(628, 700), Vector2(642, 683), Vector2(622, 662)],
	[Vector2(47, 65), Vector2(75, 74), Vector2(90, 96), Vector2(104, 89)],
	[Vector2(1233, 655), Vector2(1205, 646), Vector2(1190, 624), Vector2(1176, 631)]
]
var age := 10.0
var severity := 0
var suppressed := false

func notify_hit(before: int, after: int, maximum: int, low_flash: bool = false) -> bool:
	if maximum <= 0 or before <= 0 or after >= before: return false
	var missing := 1.0 - clampf(float(after) / float(maximum), 0.0, 1.0)
	severity = 3 if missing >= 0.75 else (2 if missing >= 0.5 else 1)
	age = 0.0
	suppressed = low_flash
	return true

func tick(dt: float) -> void:
	if is_finite(dt) and dt > 0.0: age += dt

func clear() -> void:
	age = 10.0
	severity = 0

func snapshot() -> Dictionary:
	var edge := 0.0
	var portrait := 0.0
	if severity > 0 and not suppressed:
		var t := age / float(DURATIONS[severity - 1])
		if t < 0.18: edge = float(PEAKS[severity - 1]) * sin(clampf(t / 0.18, 0.0, 1.0) * PI * 0.5)
		elif t < 0.35: edge = float(PEAKS[severity - 1]) * lerpf(1.0, 0.9, (t - 0.18) / 0.17)
		elif t < 1.0: edge = float(PEAKS[severity - 1]) * 0.9 * pow(1.0 - (t - 0.35) / 0.65, 1.7)
		var p := age / PORTRAIT_SECONDS
		if p < 0.2: portrait = 0.82 * sin(clampf(p / 0.2, 0.0, 1.0) * PI * 0.5)
		elif p < 0.55: portrait = lerpf(0.82, 0.32, (p - 0.2) / 0.35)
		elif p < 1.0: portrait = 0.32 * pow(1.0 - (p - 0.55) / 0.45, 1.5)
	return {"edge_alpha": edge, "portrait_alpha": portrait, "crack_count": severity * 6 if edge > 0.0 else 0, "severity": severity}

func draw_edges(canvas: CanvasItem) -> void:
	var status := snapshot()
	var alpha: float = status.edge_alpha
	if alpha <= 0.0: return
	var red := Color("#bd262b")
	var clear_red := Color(red, 0.0)
	var edge_red := Color(red, alpha)
	canvas.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(1280, 0), Vector2(1280, 88), Vector2(0, 88)]), PackedColorArray([edge_red, edge_red, clear_red, clear_red]))
	canvas.draw_polygon(PackedVector2Array([Vector2(0, 632), Vector2(1280, 632), Vector2(1280, 720), Vector2(0, 720)]), PackedColorArray([clear_red, clear_red, edge_red, edge_red]))
	canvas.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(100, 0), Vector2(100, 720), Vector2(0, 720)]), PackedColorArray([edge_red, clear_red, clear_red, edge_red]))
	canvas.draw_polygon(PackedVector2Array([Vector2(1180, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(1180, 720)]), PackedColorArray([clear_red, edge_red, edge_red, clear_red]))
	canvas.draw_rect(Rect2(1, 1, 1278, 718), Color(Color("#f36c58"), alpha * 0.6), false, 1.0)
	for i in range(int(status.crack_count)):
		var points := PackedVector2Array(CRACKS[i])
		canvas.draw_polyline(points, Color(Color("#730f1c"), alpha * 0.65), 3.0, true)
		canvas.draw_polyline(points, Color(Color("#ffc0af"), alpha * 0.9), 1.2 if i < 12 else 1.5, true)
		var junction: Vector2 = points[1]
		var end := junction + Vector2(-18 if i % 2 == 0 else 18, -7 if i % 3 == 0 else 8)
		canvas.draw_line(junction, end, Color(Color("#ffc0af"), alpha * 0.8), 1.0, true)
