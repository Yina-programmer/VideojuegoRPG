extends Node

const MAP_SCENE := preload("res://scenes/map/Mapa_Chapinero.tscn")


func _ready() -> void:
	call_deferred("_capture_return")


func _capture_return() -> void:
	QuestManager._loading = false
	ProgressManager._loading = false
	for place_id in QuestManager.MAIN_PLACE_IDS:
		QuestManager._confirmed[place_id] = {"status": "completed"}
		ProgressManager._confirmed[place_id] = {
			"place_id": place_id,
			"visited_at": "2026-11-20T00:00:00.000Z",
			"discovered_at": "2026-11-20T00:00:01.000Z",
		}
	var map := MAP_SCENE.instantiate()
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	await get_tree().process_frame
	map.call("_enter_tunnel")
	await get_tree().process_frame
	await get_tree().process_frame
	var tunnel := get_tree().current_scene
	tunnel.call("_on_tunnel_interaction", "return_exit", "Salida", "Volver")
	await get_tree().process_frame
	await get_tree().process_frame
	map = get_tree().current_scene
	map.tunnel_access.set_unlocked(true)
	map.active_player.velocity = Vector2.ZERO
	var camera := map.active_player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.position_smoothing_enabled = false
		camera.reset_smoothing()
	map.tunnel_access.set_interaction_focus(true, map.active_player)
	map.quest_toast.hide()
	await get_tree().physics_frame
	await get_tree().process_frame
	print(
		"Acceso visual: map_ui=%s acceso=%s placa=%s jugador=%s entrada=%s" % [
			map.map_ui.visible,
			map.tunnel_access.is_visible_in_tree(),
			map.tunnel_access.get_node("Plaque").is_visible_in_tree(),
			map.active_player.global_position,
			map.tunnel_access.global_position,
		]
	)
	await RenderingServer.frame_post_draw
	var capture_path := OS.get_environment("VIDEOJUEGO_MAP_TUNNEL_CAPTURE")
	if not capture_path.is_empty():
		var image := get_viewport().get_texture().get_image()
		var error := image.save_png(capture_path)
		if error != OK:
			push_error("No se pudo guardar la captura del acceso al túnel")
	get_tree().quit()
