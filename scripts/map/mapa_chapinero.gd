extends Node2D

const CUSTOMIZATION_PATH = "user://player_customization.cfg"
const CLOSET_SCENE = "res://scenes/player/wardrobe_ui.tscn"
const FEMALE_PLAYER_SCENE = "res://scenes/player/player.tscn"
const MALE_PLAYER_SCENE = "res://scenes/player/player_male.tscn"

@onready var calles: TileMapLayer = $Calles
@onready var closet_button: Button = $MapUI/ClosetButton
@onready var player_spawn: Marker2D = $PlayerSpawn

var active_player: CharacterBody2D


func _ready() -> void:
	_spawn_selected_player()
	closet_button.pressed.connect(_open_closet)
	crear_limites_del_mapa()


func _spawn_selected_player() -> void:
	var character_type := _load_character_type()
	var scene_path := MALE_PLAYER_SCENE if character_type == "hombre" else FEMALE_PLAYER_SCENE
	var player_scene: PackedScene = load(scene_path)
	var selected_player: CharacterBody2D = player_scene.instantiate()
	var player_camera: Camera2D = player_spawn.get_node("Camera2D")

	selected_player.name = "player"
	selected_player.position = player_spawn.position
	add_child(selected_player)
	player_camera.reparent(selected_player, true)
	player_spawn.free()
	active_player = selected_player


func _load_character_type() -> String:
	var config := ConfigFile.new()
	if config.load(CUSTOMIZATION_PATH) != OK:
		return "mujer"
	return str(config.get_value("character", "type", "mujer"))


func _open_closet() -> void:
	get_tree().change_scene_to_file(CLOSET_SCENE)


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
