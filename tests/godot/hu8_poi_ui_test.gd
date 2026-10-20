extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var quest_manager: Node = root.get_node("QuestManager")
	var progress_manager: Node = root.get_node("ProgressManager")
	var map_scene: PackedScene = load("res://scenes/map/Mapa_Chapinero.tscn")
	var map: Node2D = map_scene.instantiate()
	root.add_child(map)
	await process_frame
	await physics_frame

	var pois: Dictionary = {}
	for poi in get_nodes_in_group("point_of_interest"):
		pois[str(poi.get("place_id"))] = poi
	var prompt: CanvasLayer = map.get_node("POIPrompt")
	var card: Control = prompt.get_node("Root/Card")
	var button: Button = prompt.get_node("Root/Card/Margin/Content/DiscoverButton")
	var hippies: Area2D = pois["hippies"]
	var politecnico: Area2D = pois["politecnico"]
	var theatron: Area2D = pois["theatron"]

	quest_manager._loading = false
	progress_manager._loading = false
	quest_manager._confirmed.clear()
	quest_manager._pending.clear()
	progress_manager._confirmed.clear()
	progress_manager._pending.clear()
	map.active_pois.clear()
	map.active_pois.append(hippies)
	map._refresh_poi_prompt()
	_check(not card.visible and not button.visible, "Jugador nuevo: POI sin tarjeta ni botón")
	map._on_poi_selected(hippies)
	_check(not map.narrative_open and progress_manager.get_state("hippies") == 0, "Interacción directa bloqueada no descubre")

	quest_manager._confirmed["hippies"] = {"status": "active", "collected_items": ["arte", "calle", "memoria"], "solved_steps": ["order"]}
	map._refresh_poi_prompt()
	_check(not card.visible and not button.visible, "Pistas y acertijo sin aprobación final no muestran POI")

	quest_manager._confirmed["hippies"] = {"status": "completed"}
	map._refresh_poi_prompt()
	_check(card.visible and button.visible and prompt.get_current_poi() == hippies, "Misión confirmada muestra solo su POI")
	prompt.set_suspended(true)
	prompt.set_suspended(false)
	_check(card.visible and button.visible, "La tarjeta vuelve tras cerrar una interacción")
	map.active_pois.clear()
	map.active_pois.append(politecnico)
	map._refresh_poi_prompt()
	_check(not card.visible and not button.visible, "Otro lugar pendiente sigue bloqueado")

	progress_manager._confirmed["politecnico"] = {"discovered_at": "2026-01-01T00:00:00Z"}
	map._refresh_poi_prompt()
	_check(card.visible and button.visible and prompt.get_current_poi() == politecnico, "Descubrimiento histórico conserva acceso")

	map.active_pois.clear()
	map.active_pois.append(theatron)
	progress_manager._pending["theatron"] = progress_manager.DISCOVERED
	map._refresh_poi_prompt()
	_check(not card.visible and not button.visible, "Descubrimiento sin confirmar no desbloquea")
	quest_manager._loading = true
	map.active_pois.clear()
	map.active_pois.append(hippies)
	map._refresh_poi_prompt()
	_check(not card.visible and not button.visible, "Durante carga no aparece un fotograma de Conocer")

	var hint_panel: PanelContainer = map.get_node("MapUI/QuestHintPanel")
	print("Viewport de prueba: ", map.get_viewport_rect().size)
	var hint: Label = map.get_node("MapUI/QuestHintPanel/Margin/QuestHint")
	var hint_style: StyleBoxFlat = hint_panel.get_theme_stylebox("panel")
	_check(hint.get_theme_font_size("font_size") >= 22 and hint_style.bg_color.a >= 0.75, "Objetivo legible sobre fondo oscuro")
	hint.text = "Viste Formal (hombre) o Lazo blanco (mujer), guarda la personalización y vuelve con Polito."
	await process_frame
	_check(hint.get_visible_line_count() == hint.get_line_count(), "Objetivo largo muestra todas sus líneas")
	_check(hint_panel.get_global_rect().encloses(hint.get_global_rect()), "Texto del objetivo dentro del panel")
	_check(map.get_viewport_rect().encloses(hint_panel.get_global_rect()), "Panel de objetivo dentro de la pantalla")
	var toast: PanelContainer = map.get_node("MapUI/QuestToast")
	var toast_text: Label = map.get_node("MapUI/QuestToast/Text")
	map._show_quest_toast("Has encontrado una pista importante para el archivo histórico del Politécnico Grancolombiano.")
	await process_frame
	_check(toast_text.get_visible_line_count() == toast_text.get_line_count(), "Notificación muestra todas sus líneas")
	_check(map.get_viewport_rect().encloses(toast.get_global_rect()), "Notificación dentro de la pantalla")
	var notebook: CanvasLayer = map.get_node("QuestNotebook")
	notebook.open_notebook()
	var status: Label = notebook.get_node("Root/Window/Margin/Content/StatusPanel/Status")
	_check(status.get_theme_font_size("font_size") >= 22, "Estado de la Libreta legible")
	for requested_size in [Vector2i(1024, 576), Vector2i(1920, 1080)]:
		root.content_scale_size = requested_size
		root.size = requested_size
		await process_frame
		_check(map.get_viewport_rect().size == Vector2(requested_size), "Viewport simulado %s" % requested_size)
		_check(map.get_viewport_rect().encloses(hint_panel.get_global_rect()), "Objetivo dentro de %s" % requested_size)
		_check(map.get_viewport_rect().encloses(toast.get_global_rect()), "Notificación dentro de %s" % requested_size)
		_check(hint.get_visible_line_count() == hint.get_line_count() and hint_panel.get_global_rect().encloses(hint.get_global_rect()), "Objetivo sin recortes en %s" % requested_size)
		_check(toast_text.get_visible_line_count() == toast_text.get_line_count(), "Notificación sin recortes en %s" % requested_size)
	var npc_indicator: Control = map.get_node("Polito/InteractionIndicator")
	var npc_action: Label = map.get_node("Polito/InteractionIndicator/Panel/Margin/Content/Action")
	_check(npc_action.get_theme_font_size("font_size") >= 22 and npc_indicator.get_global_rect().encloses(npc_action.get_global_rect()), "Indicador de NPC legible y encuadrado")
	var collectible_scene: PackedScene = load("res://scenes/quests/QuestCollectible.tscn")
	var collectible: Area2D = collectible_scene.instantiate()
	root.add_child(collectible)
	var item_prompt: PanelContainer = collectible.get_node("Prompt")
	var item_label: Label = collectible.get_node("Prompt/Text")
	_check(item_label.get_theme_font_size("font_size") >= 24 and item_prompt.get_theme_stylebox("panel").bg_color.a >= 0.75, "Aviso de coleccionable legible")

	print("Resultado: ", failures, " fallos")
	quit(0 if failures == 0 else 1)
