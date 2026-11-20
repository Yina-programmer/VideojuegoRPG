extends SceneTree


func _initialize() -> void:
	call_deferred("_check_map")


func _check_map() -> void:
	var packed := load("res://scenes/map/Mapa_Chapinero.tscn") as PackedScene
	if packed == null:
		_fail("No se pudo cargar el mapa")
		return
	var map := packed.instantiate() as Node2D
	var buildings := map.get_node_or_null("EdificiosColision") as StaticBody2D
	if buildings == null or buildings.get_child_count() != 9:
		_fail("Faltan los nueve polígonos de edificios")
		return

	for name in ["DiscoveryNotification", "QuestNotebook", "ExplorationJournal"]:
		if map.get_node_or_null(name) == null:
			_fail("Falta el nodo %s" % name)
			return
	var journal := map.get_node("ExplorationJournal")
	for path in [
		"Root/Window/Margin/Content/SearchFilters/SearchInput",
		"Root/Window/Margin/Content/SearchFilters/CategoryFilter",
		"Root/Window/Margin/Content/SearchFilters/StateFilter",
	]:
		if journal.get_node_or_null(path) == null:
			_fail("Falta el filtro %s" % path)
			return

	for name in [
		"PlayerSpawn", "Polito", "Hippie", "TheatronHost", "TunnelAccess",
		"CartelArte", "CartelCalle", "CartelMemoria", "CartelFalso",
		"Documento1980", "Documento1981", "Documento1991",
		"BoletoUno", "BoletoDos",
	]:
		var item := map.get_node_or_null(name) as Node2D
		if item == null:
			_fail("Falta el nodo %s" % name)
			return
		for shape in buildings.get_children():
			var polygon := shape as CollisionPolygon2D
			if polygon == null or polygon.polygon.size() < 3:
				_fail("Colisión de edificio inválida")
				return
			if Geometry2D.is_point_in_polygon(item.position, polygon.polygon):
				_fail("%s quedó dentro de %s" % [name, polygon.name])
				return

	var tunnel_access := map.get_node("TunnelAccess")
	if tunnel_access.visible or not tunnel_access.has_method("set_unlocked") or not tunnel_access.has_signal("enter_requested"):
		_fail("El pasadizo del túnel no inicia oculto o no es interactivo")
		return

	for scene_path in ["res://scenes/player/player.tscn", "res://scenes/player/player_male.tscn"]:
		var player := (load(scene_path) as PackedScene).instantiate() as CharacterBody2D
		var collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision == null or collision.shape == null or (player.collision_mask & 1) == 0:
			_fail("El personaje no puede colisionar: %s" % scene_path)
			return
		player.free()

	map.free()
	print("Mapa integrado: POI, misiones, filtros, ambos personajes y 9 colisiones cargan correctamente")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
