extends SceneTree


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	# La entrada conserva su composición anterior: los objetos manuales grandes
	# que invadían el punto de aparición no deben volver al TileMap de detalles.
	for entrance_scene_path in [
		"res://scenes/map/TunelEcosChapinero_Generado.tscn",
	]:
		var entrance_packed := load(entrance_scene_path) as PackedScene
		var entrance_tunnel := entrance_packed.instantiate()
		var entrance_details := entrance_tunnel.get_node("Detalles") as TileMapLayer
		for rejected_cell in [Vector2i(5, 2), Vector2i(9, 2), Vector2i(6, 4), Vector2i(8, 4), Vector2i(0, 2)]:
			if entrance_details.get_cell_source_id(rejected_cell) == 4:
				entrance_tunnel.free()
				_fail("La entrada todavía contiene una decoración manual rechazada")
				return
		var entrance_barrel := entrance_tunnel.get_node_or_null("DecoracionRetro/Entrada/BarrilMadera") as Sprite2D
		if entrance_barrel == null or entrance_barrel.texture == null:
			entrance_tunnel.free()
			_fail("Se perdió el barril decorativo correcto de la entrada")
			return
		entrance_tunnel.free()

	var packed := load("res://scenes/map/TunelEcosChapinero_Generado.tscn") as PackedScene
	if packed == null:
		_fail("No se pudo cargar la escena generada")
		return
	var tunnel := packed.instantiate() as Node2D
	root.add_child(tunnel)
	await process_frame
	await physics_frame

	var minimum_cells := {
		"Piso": 600,
		"Arquitectura": 180,
		"Detalles": 8,
		"Brillos": 0,
	}
	var sources: Dictionary = {}
	for layer_name in minimum_cells:
		var layer := tunnel.get_node(layer_name) as TileMapLayer
		var cells := layer.get_used_cells()
		if cells.size() < int(minimum_cells[layer_name]):
			_fail("%s tiene solo %d tiles" % [layer_name, cells.size()])
			return
		for cell in cells:
			sources[layer.get_cell_source_id(cell)] = true
	for expected_source in [0, 1, 2]:
		if not sources.has(expected_source):
			_fail("No se utilizó el atlas fuente %d" % expected_source)
			return
	for layer_name in ["Piso", "Arquitectura", "Detalles", "Brillos"]:
		var layer := tunnel.get_node(layer_name) as TileMapLayer
		if not layer.scale.is_equal_approx(Vector2(0.5, 0.5)):
			_fail("%s no conserva el módulo arquitectónico uniforme de 78 px" % layer_name)
			return

	var interactables := get_nodes_in_group("tunnel_interactable")
	if interactables.size() < 12:
		_fail("Faltan puertas y recuerdos interactivos")
		return
	for interactable in interactables:
		if not interactable.has_method("interact") or str(interactable.get("interaction_id")).is_empty():
			_fail("Interactuable incompleto: %s" % interactable.name)
			return

	if tunnel.get_node_or_null("PlayerSpawn") == null or tunnel.get_node_or_null("ExitSpawn") == null:
		_fail("Faltan los puntos de aparición o salida")
		return
	if tunnel.get_node("Colisiones/Paredes").get_child_count() < 20:
		_fail("Las paredes no generaron suficientes colisiones")
		return
	if tunnel.get_node("Colisiones/Obstaculos").get_child_count() < 6:
		_fail("Faltan colisiones de obstáculos")
		return
	for complete_sprite_path in [
		"ElementosDestacados/EscaleraInicialYRegreso",
		"ElementosDestacados/PuertaKinder",
		"ElementosDestacados/PuertaFinalEncadenada",
		"ElementosDestacados/PuertaTerror",
		"ElementosDestacados/BustoArchivoCompleto",
		"ElementosDestacados/AngelTerrorCompleto",
		"ElementosDestacados/CabinaKinderCompleta",
		"Efectos/FantasmaFiccional",
	]:
		var complete_sprite := tunnel.get_node_or_null(complete_sprite_path) as Sprite2D
		if complete_sprite == null or complete_sprite.texture == null or complete_sprite.material == null:
			_fail("Falta un elemento completo del atlas nuevo: %s" % complete_sprite_path)
			return
	var kinder_foreground := tunnel.get_node_or_null("ElementosDestacados/UmbralKinderFrontal") as Sprite2D
	if kinder_foreground == null or kinder_foreground.z_index <= 0:
		_fail("La puerta KINDER no generó su umbral de profundidad")
		return

	# La decoracion retro usa el atlas transparente entregado y queda separada
	# del TileMap del piso para que la composicion original no cambie.
	var retro_root := tunnel.get_node_or_null("DecoracionRetro")
	if retro_root == null or _count_sprite_descendants(retro_root) < 50:
		_fail("Falta la ambientacion retro distribuida por el tunel")
		return
	for sticker_path in [
		"DecoracionRetro/Entrada/BarrilMadera",
		"DecoracionRetro/CorredorIndustrial/CartelPeligro",
		"DecoracionRetro/Recuerdos/MapaChapinero",
		"DecoracionRetro/Kinder/BolaDisco",
		"DecoracionRetro/Terror/Ojo",
		"DecoracionRetro/CamaraFinal/CirculoMistico",
		"DecoracionRetro/RinconesDecorativos/DescansoEntrada/Banco",
		"DecoracionRetro/RinconesDecorativos/SalitaRecuerdos/BancoDerecho",
		"DecoracionRetro/RinconesDecorativos/AntesalaCultural/BancoConocimiento",
		"DecoracionRetro/RinconesDecorativos/EsperaKinder/BancoIzquierdo",
		"DecoracionRetro/RinconesDecorativos/DescansoFinal/BancoDerecho",
	]:
		var sticker := tunnel.get_node_or_null(sticker_path) as Sprite2D
		if sticker == null or sticker.texture == null:
			_fail("Falta una decoracion retro: %s" % sticker_path)
			return
	var park_benches: Array[Sprite2D] = []
	for bench_path in [
		"DecoracionRetro/Recuerdos/Banco",
		"DecoracionRetro/RinconesDecorativos/SalitaRecuerdos/BancoIzquierdo",
		"DecoracionRetro/RinconesDecorativos/SalitaRecuerdos/BancoDerecho",
		"DecoracionRetro/RinconesDecorativos/SalitaRecuerdos/BancoFinal",
	]:
		park_benches.append(tunnel.get_node(bench_path) as Sprite2D)
	for bench in park_benches:
		if not bench.scale.is_equal_approx(Vector2(0.34, 0.34)) or not is_equal_approx(bench.position.y, 548.0):
			_fail("La fila tipo parque perdio su tamano o alineacion uniforme")
			return

	# El personaje que la escena crea debe conservar el movimiento y una cámara activa.
	var spawned_player := tunnel.get_node_or_null("player") as CharacterBody2D
	if spawned_player == null or not spawned_player.has_method("set_movement_enabled"):
		_fail("No se reutilizó el personaje actual")
		return
	if spawned_player.get_node_or_null("Camera2D") == null:
		_fail("El personaje no recibió la cámara del túnel")
		return

	# La misma ruta de interacción existente debe enfocar el prompt y activar
	# el mensaje del túnel; la acción Interact del proyecto sigue ligada a E.
	var calendar: Node = null
	for candidate in interactables:
		if candidate.interaction_id == "pozzetto_calendar":
			calendar = candidate
			break
	if calendar == null:
		_fail("No se encontró el calendario interactivo de Pozzetto")
		return
	calendar.call("_on_body_entered", spawned_player)
	if not calendar.get_node("Prompt").visible:
		_fail("InteractionManager no enfocó el prompt de la tecla E")
		return
	calendar.interact(spawned_player)
	if not tunnel.notice_panel.visible or not tunnel.notice_title.text.begins_with("Calendario"):
		_fail("La interacción no mostró el contenido histórico de Pozzetto")
		return
	calendar.call("_on_body_exited", spawned_player)
	tunnel.notice_panel.hide()
	if not tunnel.ambient_player.playing:
		_fail("El ambiente sonoro del túnel no inició")
		return
	var ghost_trigger := tunnel.ghost_trigger as Area2D
	spawned_player.position = ghost_trigger.global_position + Vector2(-900, 0)
	await physics_frame
	spawned_player.position = ghost_trigger.global_position
	await physics_frame
	await process_frame
	if not tunnel.ghost.visible or not tunnel._ghost_seen:
		_fail("El área física no activó el fantasma ficticio")
		return
	tunnel.ghost.hide()
	tunnel.notice_panel.hide()

	# Validación física con las dos variantes, recorriendo el corredor y cada ramal.
	spawned_player.queue_free()
	await process_frame
	for player_scene_path in ["res://scenes/player/player.tscn", "res://scenes/player/player_male.tscn"]:
		var player := (load(player_scene_path) as PackedScene).instantiate() as CharacterBody2D
		player.set_script(null)
		player.z_index = 20
		tunnel.add_child(player)
		await physics_frame
		if not await _walk_route(player, [
			Vector2(351, 390), Vector2(7200, 390),
			Vector2(4720, 390), Vector2(4720, 1150), Vector2(4400, 1150), Vector2(4400, 1350),
			Vector2(4400, 1150), Vector2(4720, 1150), Vector2(4720, 390), Vector2(6240, 390), Vector2(6240, -250),
			Vector2(6240, 390), Vector2(2500, 390), Vector2(2350, 850), Vector2(2300, 1100),
		]):
			_fail("Una ruta quedó bloqueada para %s" % player_scene_path)
			return
		player.free()

	var signal_state := {"exit_emitted": false}
	tunnel.exit_requested.connect(func() -> void: signal_state.exit_emitted = true)
	tunnel.call("_on_tunnel_interaction", "return_exit", "Salida", "Prueba")
	if not signal_state.exit_emitted:
		_fail("La escalera de regreso no emite exit_requested")
		return

	print("HU_9: túnel completo, recorrido, colisiones, interacción y regreso a la superficie verificados")
	tunnel.call("_shutdown_ambient_audio")
	await create_timer(0.5).timeout
	tunnel.queue_free()
	await process_frame
	quit(0)


func _walk_route(player: CharacterBody2D, points: Array[Vector2]) -> bool:
	player.position = points[0]
	await physics_frame
	for index in range(1, points.size()):
		var target := points[index]
		while player.position.distance_to(target) > 1.0:
			var motion := player.position.direction_to(target) * minf(52.0, player.position.distance_to(target))
			var collision := player.move_and_collide(motion)
			if collision != null:
				print("Bloqueo en %s hacia %s, contacto %s" % [player.position, target, collision.get_position()])
				return false
	return true


func _count_sprite_descendants(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is Sprite2D:
			count += 1
		count += _count_sprite_descendants(child)
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
