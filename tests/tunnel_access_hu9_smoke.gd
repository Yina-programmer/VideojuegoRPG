extends Node


func _ready() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var original_quest_loading: bool = QuestManager._loading
	var original_progress_loading: bool = ProgressManager._loading
	var original_quests: Dictionary = QuestManager._confirmed.duplicate(true)
	var original_progress: Dictionary = ProgressManager._confirmed.duplicate(true)

	QuestManager._loading = false
	ProgressManager._loading = false
	QuestManager._confirmed.clear()
	ProgressManager._confirmed.clear()

	if QuestManager.is_tunnel_access_unlocked():
		_restore(original_quest_loading, original_progress_loading, original_quests, original_progress)
		_fail("El túnel se desbloqueó sin progreso")
		return

	for place_id in QuestManager.MAIN_PLACE_IDS:
		QuestManager._confirmed[place_id] = {"status": "completed"}
		ProgressManager._confirmed[place_id] = {
			"place_id": place_id,
			"visited_at": "2026-11-20T00:00:00.000Z",
			"discovered_at": "2026-11-20T00:00:01.000Z",
		}

	if not QuestManager.is_tunnel_access_unlocked():
		_restore(original_quest_loading, original_progress_loading, original_quests, original_progress)
		_fail("Las tres misiones y descubrimientos confirmados no desbloquearon el túnel")
		return

	var theatron_record: Dictionary = ProgressManager._confirmed["theatron"]
	theatron_record["discovered_at"] = null
	ProgressManager._confirmed["theatron"] = theatron_record
	if QuestManager.is_tunnel_access_unlocked():
		_restore(original_quest_loading, original_progress_loading, original_quests, original_progress)
		_fail("El túnel ignoró un descubrimiento pendiente")
		return
	theatron_record["discovered_at"] = "2026-11-20T00:00:01.000Z"
	ProgressManager._confirmed["theatron"] = theatron_record

	var access := (load("res://scenes/map/tunnel_access.tscn") as PackedScene).instantiate()
	add_child(access)
	await get_tree().process_frame
	access.set_unlocked(true)
	await get_tree().physics_frame
	if not access.visible or not access.monitoring:
		_restore(original_quest_loading, original_progress_loading, original_quests, original_progress)
		_fail("El pasadizo no se activó visual y físicamente")
		return
	var entered := {"value": false}
	access.enter_requested.connect(func() -> void: entered["value"] = true)
	var player := CharacterBody2D.new()
	player.add_to_group("player")
	access.interact(player)
	if not bool(entered["value"]):
		_restore(original_quest_loading, original_progress_loading, original_quests, original_progress)
		_fail("La tecla E no solicita entrar al túnel")
		return
	player.free()
	access.free()

	var map := (load("res://scenes/map/Mapa_Chapinero.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	await get_tree().process_frame
	map.call("_enter_tunnel")
	await get_tree().process_frame
	await get_tree().process_frame
	var tunnel := get_tree().current_scene
	if tunnel == null or tunnel.scene_file_path != "res://scenes/map/TunelEcosChapinero_Generado.tscn":
		_restore(original_quest_loading, original_progress_loading, original_quests, original_progress)
		_fail("El pasadizo no cambió a la escena del túnel")
		return
	tunnel.call("_on_tunnel_interaction", "return_exit", "Salida", "Volver")
	await get_tree().process_frame
	await get_tree().process_frame
	var returned_map := get_tree().current_scene
	if returned_map == null or returned_map.scene_file_path != "res://scenes/map/Mapa_Chapinero.tscn":
		_restore(original_quest_loading, original_progress_loading, original_quests, original_progress)
		_fail("La escalera no regresó a Mapa_Chapinero")
		return
	var expected_spawn: Vector2 = returned_map.tunnel_access.get_surface_spawn_position()
	if not returned_map.active_player.position.is_equal_approx(expected_spawn):
		_restore(original_quest_loading, original_progress_loading, original_quests, original_progress)
		_fail("El jugador no reapareció junto al pasadizo al volver a la superficie")
		return
	var return_camera := returned_map.active_player.get_node_or_null("Camera2D") as Camera2D
	if (
		return_camera == null
		or return_camera.get_parent() != returned_map.active_player
		or not return_camera.position.is_equal_approx(Vector2.ZERO)
		or not return_camera.is_current()
		or not returned_map.active_player.is_visible_in_tree()
	):
		_restore(original_quest_loading, original_progress_loading, original_quests, original_progress)
		_fail("La cámara no regresó centrada sobre el personaje en la superficie")
		return

	_restore(original_quest_loading, original_progress_loading, original_quests, original_progress)
	print("HU_9 acceso: bloqueo estricto, cambio de escena con E y regreso junto al pasadizo verificados")
	get_tree().quit(0)


func _restore(quest_loading: bool, progress_loading: bool, quests: Dictionary, progress: Dictionary) -> void:
	QuestManager._loading = quest_loading
	ProgressManager._loading = progress_loading
	QuestManager._confirmed = quests
	ProgressManager._confirmed = progress
	if get_tree().root.has_meta("returning_from_tunnel"):
		get_tree().root.remove_meta("returning_from_tunnel")


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
