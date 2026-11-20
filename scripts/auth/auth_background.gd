extends Control

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	for band in range(24):
		var ratio := float(band) / 23.0
		var color := Color(0.018 + ratio * 0.018, 0.018, 0.075 + ratio * 0.06, 1.0)
		draw_rect(Rect2(0, size.y * ratio, size.x, size.y / 23.0 + 2.0), color)

	_draw_stars(size)
	_draw_city(size)
	_draw_arches(size)
	_draw_floor(size)
	_draw_glow(Vector2(size.x * 0.18, size.y * 0.58), Color(0.05, 0.78, 1.0, 0.07), size.y * 0.23)
	_draw_glow(Vector2(size.x * 0.82, size.y * 0.55), Color(1.0, 0.08, 0.78, 0.07), size.y * 0.25)


func _draw_stars(size: Vector2) -> void:
	for index in range(36):
		var x := fmod(float(index * 173 + 61), size.x)
		var y := fmod(float(index * 83 + 37), size.y * 0.55)
		var pulse := 0.45 + 0.45 * sin(_time * 1.7 + float(index))
		var star_color := Color(0.55, 0.82, 1.0, pulse)
		draw_circle(Vector2(x, y), 1.2 + float(index % 3), star_color)
		if index % 7 == 0:
			draw_line(Vector2(x - 7, y), Vector2(x + 7, y), star_color, 1.0)
			draw_line(Vector2(x, y - 7), Vector2(x, y + 7), star_color, 1.0)


func _draw_city(size: Vector2) -> void:
	var baseline := size.y * 0.43
	var width := size.x * 0.46
	var start := (size.x - width) * 0.5
	var building_width := width / 18.0
	for index in range(18):
		var height := size.y * (0.045 + float((index * 7) % 8) * 0.012)
		var rect := Rect2(start + index * building_width, baseline - height, building_width - 3, height)
		draw_rect(rect, Color(0.035, 0.035, 0.12, 0.96))
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(0.35, 0.15, 0.72, 0.8), 2.0)
		for row in range(2):
			var light := Color(1.0, 0.65, 0.18, 0.65 if (index + row) % 2 == 0 else 0.2)
			draw_rect(Rect2(rect.position + Vector2(7, 10 + row * 13), Vector2(4, 6)), light)


func _draw_arches(size: Vector2) -> void:
	var cyan := Color(0.05, 0.78, 1.0, 0.65)
	var pink := Color(1.0, 0.12, 0.76, 0.6)
	for side in [-1.0, 1.0]:
		var center := Vector2(size.x * (0.18 if side < 0 else 0.82), size.y * 0.59)
		for ring in range(4):
			var radius := size.y * (0.12 + ring * 0.035)
			var points := PackedVector2Array()
			for step in range(25):
				var angle := PI + float(step) / 24.0 * PI
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
			draw_polyline(points, cyan if side < 0 else pink, 2.5, true)
			draw_line(center + Vector2(-radius, 0), center + Vector2(-radius, size.y * 0.3), cyan if side < 0 else pink, 2.5)
			draw_line(center + Vector2(radius, 0), center + Vector2(radius, size.y * 0.3), cyan if side < 0 else pink, 2.5)


func _draw_floor(size: Vector2) -> void:
	var horizon := size.y * 0.72
	draw_rect(Rect2(0, horizon, size.x, size.y - horizon), Color(0.018, 0.018, 0.06, 0.95))
	for row in range(7):
		var ratio := float(row) / 6.0
		var y := lerpf(horizon, size.y, ratio * ratio)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.18, 0.2, 0.55, 0.38), 1.0)
	for column in range(15):
		var top_x := size.x * 0.5 + (column - 7) * size.x * 0.026
		var bottom_x := size.x * 0.5 + (column - 7) * size.x * 0.09
		draw_line(Vector2(top_x, horizon), Vector2(bottom_x, size.y), Color(0.15, 0.42, 0.75, 0.28), 1.0)


func _draw_glow(center: Vector2, color: Color, radius: float) -> void:
	for ring in range(10, 0, -1):
		var glow := color
		glow.a *= float(11 - ring) / 10.0
		draw_circle(center, radius * float(ring) / 10.0, glow)
