extends Node

const TUNNEL_SCENE := preload("res://scenes/map/TunelEcosChapinero_Generado.tscn")

const STOPS := {
	KEY_1: Vector2(351, 390),
	KEY_2: Vector2(1200, 390),
	KEY_3: Vector2(2350, 390),
	KEY_4: Vector2(3770, 300),
	KEY_5: Vector2(2500, 1050),
	KEY_6: Vector2(4720, 840),
	KEY_7: Vector2(4720, 1200),
	KEY_8: Vector2(5750, 390),
	KEY_9: Vector2(6240, -220),
	KEY_0: Vector2(7100, 390),
	KEY_F1: Vector2(4720, 725),
}

const CAPTURE_STOPS := [
	[KEY_1, "01_entrada.png"],
	[KEY_2, "02_corredor.png"],
	[KEY_3, "03_recuerdos.png"],
	[KEY_4, "04_puertas_culturales.png"],
	[KEY_5, "05_archivo_secreto.png"],
	[KEY_6, "06_entrada_kinder.png"],
	[KEY_F1, "06b_cruce_umbral_kinder.png"],
	[KEY_7, "07_interior_kinder.png"],
	[KEY_8, "08_terror.png"],
	[KEY_9, "09_bifurcacion_secreta.png"],
	[KEY_0, "10_puerta_final.png"],
]

var tunnel: Node2D


func _ready() -> void:
	tunnel = TUNNEL_SCENE.instantiate() as Node2D
	add_child(tunnel)
	await get_tree().process_frame
	_focus_stop(KEY_1)
	var capture_dir := OS.get_environment("VIDEOJUEGO_TUNNEL_CAPTURE_DIR")
	if not capture_dir.is_empty():
		_capture_tour.call_deferred(capture_dir)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and STOPS.has(event.keycode):
		_focus_stop(event.keycode)


func _focus_stop(keycode: Key) -> void:
	if is_instance_valid(tunnel.active_player):
		tunnel.active_player.position = STOPS[keycode]
		tunnel.active_player.velocity = Vector2.ZERO


func _capture_tour(capture_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var camera := tunnel.active_player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.position_smoothing_enabled = false
	for stop in CAPTURE_STOPS:
		_focus_stop(stop[0])
		if camera != null:
			camera.reset_smoothing()
		await get_tree().physics_frame
		await get_tree().process_frame
		await get_tree().process_frame
		tunnel.notice_panel.hide()
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var error := image.save_png(capture_dir.path_join(stop[1]))
		if error != OK:
			push_error("No se pudo guardar la captura visual %s" % stop[1])
	get_tree().quit()
