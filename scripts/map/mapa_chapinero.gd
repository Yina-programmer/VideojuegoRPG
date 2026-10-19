extends Node2D

const CUSTOMIZATION_PATH = "user://player_customization.cfg"
const CLOSET_SCENE = "res://scenes/player/wardrobe_ui.tscn"
const FEMALE_PLAYER_SCENE = "res://scenes/player/player.tscn"
const MALE_PLAYER_SCENE = "res://scenes/player/player_male.tscn"

@onready var calles: TileMapLayer = $Calles
@onready var map_ui: CanvasLayer = $MapUI
@onready var closet_button: Button = $MapUI/ClosetButton
@onready var journal_button: Button = $MapUI/JournalButton
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var narrative_panel = $UI_narrative/NarrativePanel
@onready var poi_prompt = $POIPrompt
@onready var journal = $ExplorationJournal
@onready var discovery_notification = $DiscoveryNotification

var active_player: CharacterBody2D
var active_pois: Array[Area2D] = []
var narrative_open := false
var journal_open := false
var _spawn_position := Vector2.ZERO
var _has_moved_from_spawn := false


func _ready() -> void:
	_spawn_selected_player()
	closet_button.pressed.connect(_open_closet)
	journal_button.pressed.connect(_open_journal)
	journal.closed.connect(_on_journal_closed)
	discovery_notification.finished.connect(_try_show_discovery_notification)
	ProgressManager.discovery_reward_available.connect(_try_show_discovery_notification)
	InteractionManager.dialogue_started.connect(_on_dialogue_started)
	InteractionManager.dialogue_finished.connect(_on_dialogue_finished)
	poi_prompt.poi_selected.connect(_on_poi_selected)
	narrative_panel.closed.connect(_on_narrative_closed)
	crear_limites_del_mapa()
	var catalog: Array[Dictionary] = []
	for point_of_interest in get_tree().get_nodes_in_group("point_of_interest"):
		if point_of_interest is Area2D:
			catalog.append(point_of_interest.get_poi_data())
			point_of_interest.zone_entered.connect(_on_poi_zone_entered)
			point_of_interest.zone_exited.connect(_on_poi_zone_exited)
	ProgressManager.register_places(catalog)
	call_deferred("_try_show_discovery_notification")


func _spawn_selected_player() -> void:
	var character_type := _load_character_type()
	var scene_path := MALE_PLAYER_SCENE if character_type == "hombre" else FEMALE_PLAYER_SCENE
	var player_scene: PackedScene = load(scene_path)
	var selected_player: CharacterBody2D = player_scene.instantiate()
	var player_camera: Camera2D = player_spawn.get_node("Camera2D")

	selected_player.name = "player"
	selected_player.position = player_spawn.position
	add_child(selected_player)
	if not selected_player.is_in_group("player"):
		selected_player.add_to_group("player")
	player_camera.reparent(selected_player, true)
	player_spawn.free()
	active_player = selected_player
	_spawn_position = selected_player.global_position


func _physics_process(_delta: float) -> void:
	if _has_moved_from_spawn or not is_instance_valid(active_player):
		return
	if active_player.global_position.distance_to(_spawn_position) < 8.0:
		return
	_has_moved_from_spawn = true
	for point_of_interest in active_pois:
		ProgressManager.record_visit(str(point_of_interest.get("place_id")))


func _load_character_type() -> String:
	var config := ConfigFile.new()
	if config.load(CUSTOMIZATION_PATH) != OK:
		return "mujer"
	return str(config.get_value("character", "type", "mujer"))


func _open_closet() -> void:
	get_tree().change_scene_to_file(CLOSET_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("OpenJournal") and not journal_open:
		get_viewport().set_input_as_handled()
		_open_journal()


func _open_journal() -> void:
	if journal_open or narrative_open or InteractionManager.is_dialogue_active():
		return
	journal_open = true
	map_ui.hide()
	poi_prompt.set_suspended(true)
	if is_instance_valid(active_player):
		active_player.set_movement_enabled(false)
	discovery_notification.dismiss()
	journal.open_journal()


func _on_journal_closed() -> void:
	journal_open = false
	if is_instance_valid(active_player) and not narrative_open and not InteractionManager.is_dialogue_active():
		active_player.set_movement_enabled(true)
	map_ui.visible = not narrative_open and not InteractionManager.is_dialogue_active()
	poi_prompt.set_suspended(narrative_open or InteractionManager.is_dialogue_active())
	_refresh_poi_prompt()
	_try_show_discovery_notification()


func _on_dialogue_started() -> void:
	map_ui.visible = false
	poi_prompt.set_suspended(true)
	discovery_notification.dismiss()


func _on_dialogue_finished() -> void:
	map_ui.visible = not narrative_open and not journal_open
	poi_prompt.set_suspended(narrative_open or journal_open)
	_try_show_discovery_notification()


func _on_poi_zone_entered(point_of_interest: Area2D) -> void:
	if point_of_interest not in active_pois:
		active_pois.append(point_of_interest)
		# Al aparecer dentro del Politécnico, aún no hubo exploración real.
		if _has_moved_from_spawn or active_player.global_position.distance_to(_spawn_position) >= 8.0:
			ProgressManager.record_visit(str(point_of_interest.get("place_id")))
	_refresh_poi_prompt()


func _on_poi_zone_exited(point_of_interest: Area2D) -> void:
	active_pois.erase(point_of_interest)
	_refresh_poi_prompt()


func _refresh_poi_prompt() -> void:
	for index in range(active_pois.size() - 1, -1, -1):
		if not is_instance_valid(active_pois[index]):
			active_pois.remove_at(index)
	if active_pois.is_empty():
		poi_prompt.clear_poi()
	else:
		poi_prompt.show_poi(active_pois.back())


func _on_poi_selected(point_of_interest: Area2D) -> void:
	if narrative_open or journal_open or InteractionManager.is_dialogue_active():
		return
	if point_of_interest not in active_pois or not point_of_interest.has_method("get_poi_data"):
		return
	var data: Dictionary = point_of_interest.get_poi_data()
	narrative_open = true
	poi_prompt.set_suspended(true)
	map_ui.visible = false
	if is_instance_valid(active_player):
		active_player.set_movement_enabled(false)
	ProgressManager.record_visit(str(data.get("place_id", "")))
	narrative_panel.show_narrative(
		str(data.get("name", "Lugar cultural")),
		str(data.get("description", "")),
		str(data.get("category", "Cultura")),
		data.get("category_color", Color("d99a45")) as Color,
	)
	ProgressManager.record_discovery(str(data.get("place_id", "")))


func _on_narrative_closed() -> void:
	narrative_open = false
	if is_instance_valid(active_player) and not journal_open and not InteractionManager.is_dialogue_active():
		active_player.set_movement_enabled(true)
	map_ui.visible = not journal_open and not InteractionManager.is_dialogue_active()
	poi_prompt.set_suspended(journal_open or InteractionManager.is_dialogue_active())
	_refresh_poi_prompt()
	_try_show_discovery_notification()


func _try_show_discovery_notification() -> void:
	if narrative_open or journal_open or InteractionManager.is_dialogue_active():
		return
	if discovery_notification.is_showing():
		return
	var place_id := ProgressManager.take_discovery_reward()
	if place_id.is_empty():
		return
	var place := ProgressManager.get_place_data(place_id)
	if place.is_empty():
		return
	discovery_notification.show_discovery(
		place,
		ProgressManager.get_discovered_count(),
		ProgressManager.get_total_count(),
	)


## Crea cuatro paredes invisibles alrededor de todas las celdas usadas del mapa.
## Los limites se calculan en tiempo de ejecucion para seguir funcionando aunque
## el TileMap crezca o cambie de posicion.
func crear_limites_del_mapa() -> void:
	var celdas_usadas := calles.get_used_rect()
	if celdas_usadas.size == Vector2i.ZERO:
		push_warning("No se pudieron crear los limites: el mapa no tiene celdas.")
		return

	var tamano_celda := Vector2(calles.tile_set.tile_size)
	var ultima_celda := celdas_usadas.position + celdas_usadas.size - Vector2i.ONE
	var esquina_superior_izquierda := calles.map_to_local(celdas_usadas.position) - tamano_celda * 0.5
	var esquina_inferior_derecha := calles.map_to_local(ultima_celda) + tamano_celda * 0.5

	# Convertir del espacio local del TileMap al espacio local de esta escena.
	esquina_superior_izquierda = to_local(calles.to_global(esquina_superior_izquierda))
	esquina_inferior_derecha = to_local(calles.to_global(esquina_inferior_derecha))

	var rectangulo_mapa := Rect2(
		esquina_superior_izquierda,
		esquina_inferior_derecha - esquina_superior_izquierda,
	).abs()
	var grosor_pared := maxf(tamano_celda.x, tamano_celda.y)
	var limites := StaticBody2D.new()
	limites.name = "LimitesDelMapa"
	add_child(limites)

	_agregar_pared(
		limites,
		Vector2(rectangulo_mapa.get_center().x, rectangulo_mapa.position.y - grosor_pared * 0.5),
		Vector2(rectangulo_mapa.size.x + grosor_pared * 2.0, grosor_pared),
	)
	_agregar_pared(
		limites,
		Vector2(rectangulo_mapa.get_center().x, rectangulo_mapa.end.y + grosor_pared * 0.5),
		Vector2(rectangulo_mapa.size.x + grosor_pared * 2.0, grosor_pared),
	)
	_agregar_pared(
		limites,
		Vector2(rectangulo_mapa.position.x - grosor_pared * 0.5, rectangulo_mapa.get_center().y),
		Vector2(grosor_pared, rectangulo_mapa.size.y),
	)
	_agregar_pared(
		limites,
		Vector2(rectangulo_mapa.end.x + grosor_pared * 0.5, rectangulo_mapa.get_center().y),
		Vector2(grosor_pared, rectangulo_mapa.size.y),
	)


func _agregar_pared(contenedor: StaticBody2D, posicion: Vector2, tamano: Vector2) -> void:
	var forma := RectangleShape2D.new()
	forma.size = tamano

	var colision := CollisionShape2D.new()
	colision.position = posicion
	colision.shape = forma
	contenedor.add_child(colision)
