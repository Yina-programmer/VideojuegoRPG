@tool
extends Node2D

signal exit_requested

const TILE := 78
const CUSTOMIZATION_PATH := "user://player_customization.cfg"
const FEMALE_PLAYER_SCENE := "res://scenes/player/player.tscn"
const MALE_PLAYER_SCENE := "res://scenes/player/player_male.tscn"
const MAP_SCENE := "res://scenes/map/Mapa_Chapinero.tscn"
const RETURN_FROM_TUNNEL_META := "returning_from_tunnel"
const CARDINALS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const ART_DIR := "res://assets/tilesets/tunel_ecos/antigravity/"
const ACTIVITIES_SCRIPT := preload("res://scripts/map/tunel_ecos_actividades.gd")

@onready var floor_layer: TileMapLayer = $Piso
@onready var floor_inlays: Node2D = $AmbientacionSuelo
@onready var walls_collision: StaticBody2D = $Colisiones/Paredes
@onready var obstacles_collision: StaticBody2D = $Colisiones/Obstaculos
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var section_title: Label = $UI/SectionPanel/Margin/Content/Title
@onready var section_subtitle: Label = $UI/SectionPanel/Margin/Content/Subtitle
@onready var notice_panel: PanelContainer = $UI/NoticePanel
@onready var notice_title: Label = $UI/NoticePanel/Margin/Content/Title
@onready var notice_text: Label = $UI/NoticePanel/Margin/Content/Text
@onready var notice_timer: Timer = $UI/NoticeTimer
@onready var ghost: Sprite2D = $Efectos/FantasmaFiccional
@onready var ghost_trigger: Area2D = $Efectos/ActivadorFantasma
@onready var terror_light: PointLight2D = $Iluminacion/LuzTerrorParpadeante
@onready var darkness_modulate: CanvasModulate = $OscuridadSubterranea
@onready var ambient_player: AudioStreamPlayer = $AmbienteSubterraneo

var active_player: CharacterBody2D
var _activities: CanvasLayer
var _progress_label: Label
var _changing_scene := false
var _last_section := ""

# Audio multizona sintetizado (original)
var _ambient_playback: AudioStreamGeneratorPlayback
var _ambient_phase := 0.0
var _music_time := 0.0
var _ambient_rng := RandomNumberGenerator.new()
var _hippies_music_on := false
var _kinder_party_on := false
var _kinder_supernova := false
var _kinder_palette_index := 0

# Estado visual y puzzles
var _mural_index := 0
var _solved_secrets: Dictionary = {
	"hippies_timeline": false,
	"pozzetto_archive": false,
	"kinder_lights": false,
	"terror_secret": false,
}

# Referencias de pista de baile y efectos dinámicos
var _dance_tiles: Dictionary = {} # Vector2i -> Polygon2D
var _shadow_seen := false
var _ghost_seen := false
var _mirror_altered := false
var _ghost_tween: Tween
var _fx_timer := 0.0

# Regiones de mural cambiante en 04_elementos_completos.png
const MURAL_REGIONS := [
	Rect2(246, 899, 82, 118), # Rostro floral psicodélico
	Rect2(333, 899, 96, 118), # Mariposa psicodélica
	Rect2(528, 899, 76, 118), # Collage retro colorido
]
const MURAL_TITLES := [
	"Mural: Flores de la Séptima (1970)",
	"Mural: Mariposa Psicodélica",
	"Mural: Colores de Chapinero",
]

const KINDER_PALETTES := [
	[Color(0.95, 0.18, 0.85, 0.34), Color(0.16, 0.58, 1.0, 0.32)],
	[Color(0.62, 0.24, 1.0, 0.36), Color(0.1, 0.95, 0.86, 0.32)],
	[Color(1.0, 0.42, 0.16, 0.34), Color(0.92, 0.16, 0.72, 0.34)],
]


func _ready() -> void:
	# IMPORTANTE: Nunca limpiamos ni sobrescribimos Piso, Arquitectura, Detalles ni Brillos.
	# Todas las capas TileMapLayer guardadas en la escena se conservan al 100%.
	_configure_kinder_threshold()
	_build_floor_inlays()

	if Engine.is_editor_hint():
		return

	_build_wall_collisions_from_existing_floor()
	_build_obstacle_collisions()
	_setup_activities_ui()
	_setup_progress_hud()
	_spawn_selected_player()
	_connect_interactables()

	if is_instance_valid(ghost_trigger):
		ghost_trigger.body_entered.connect(_on_ghost_trigger_body_entered)
	notice_timer.timeout.connect(notice_panel.hide)
	notice_panel.hide()

	_setup_ambient_audio()
	_update_section(true)
	_refresh_altar_crystals()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_fx_timer += delta
	_fill_ambient_buffer()
	_update_section(false)
	_animate_lights_and_props(delta)
	_animate_kinder_floor()
	_check_terror_proximity_events()


func _exit_tree() -> void:
	if is_instance_valid(_ghost_tween):
		_ghost_tween.kill()
	_shutdown_ambient_audio()


func _shutdown_ambient_audio() -> void:
	_ambient_playback = null
	if is_instance_valid(ambient_player):
		ambient_player.stop()
		ambient_player.stream = null


# =============================================================================
# CONSTRUCCIÓN NO DESTRUCTIVA (CONSERVA TODOS LOS TILEMAPLAYERS DEL EDITOR)
# =============================================================================

func _configure_kinder_threshold() -> void:
	var door := get_node_or_null("ElementosDestacados/PuertaKinder") as Sprite2D
	if door == null or door.texture == null:
		return
	var foreground := get_node_or_null("ElementosDestacados/UmbralKinderFrontal") as Sprite2D
	if foreground == null:
		foreground = Sprite2D.new()
		foreground.name = "UmbralKinderFrontal"
		$ElementosDestacados.add_child(foreground)
	foreground.texture = door.texture
	foreground.material = door.material
	foreground.region_enabled = true
	var texture_size := door.texture.get_size()
	var threshold_height := minf(40.0, texture_size.y * 0.22)
	foreground.region_rect = Rect2(0, texture_size.y - threshold_height, texture_size.x, threshold_height)
	foreground.scale = door.scale
	foreground.position = door.position + Vector2(0, (texture_size.y - threshold_height) * 0.5 * door.scale.y)
	foreground.z_index = 15


func _build_floor_inlays() -> void:
	if not is_instance_valid(floor_inlays):
		return
	for child in floor_inlays.get_children():
		child.free()
	_dance_tiles.clear()

	# Zona Hippies: alfombra cálida psicodélica sutil
	_add_inlay_rect(
		Rect2(Vector2(21.6 * TILE, 2.75 * TILE), Vector2(17.8 * TILE, 4.4 * TILE)),
		Color(0.92, 0.42, 0.24, 0.08), "CaminoHippies"
	)
	_add_inlay_outline(
		Rect2(Vector2(21.4 * TILE, 1.4 * TILE), Vector2(18.2 * TILE, 7.0 * TILE)),
		Color(1.0, 0.58, 0.26, 0.34), "MarcoHippies"
	)

	# Archivo de Pozzetto (1986): marco sobrio sepia
	_add_inlay_rect(
		Rect2(Vector2(29.4 * TILE, 8.35 * TILE), Vector2(6.2 * TILE, 7.15 * TILE)),
		Color(0.55, 0.42, 0.22, 0.09), "SueloArchivoPozzetto"
	)
	_add_inlay_outline(
		Rect2(Vector2(29.4 * TILE, 8.35 * TILE), Vector2(6.2 * TILE, 7.15 * TILE)),
		Color(0.84, 0.68, 0.42, 0.42), "MarcoArchivoPozzetto"
	)

	# Puertas culturales
	_add_inlay_rect(
		Rect2(Vector2(41.0 * TILE, 3.2 * TILE), Vector2(16.0 * TILE, 3.7 * TILE)),
		Color(0.28, 0.14, 0.42, 0.12), "AlfombraCultural"
	)
	_add_inlay_outline(
		Rect2(Vector2(40.25 * TILE, 1.3 * TILE), Vector2(17.5 * TILE, 7.2 * TILE)),
		Color(0.65, 0.43, 0.92, 0.52), "MarcoCultural"
	)

	# Pista de baile reactiva KINDER
	for y in range(12, 17):
		for x in range(57, 64):
			var color := Color(0.84, 0.17, 0.9, 0.28) if (x + y) % 2 == 0 else Color(0.15, 0.55, 1.0, 0.26)
			var poly := _add_inlay_rect(
				Rect2(Vector2(x * TILE + 4, y * TILE + 4), Vector2(TILE - 8, TILE - 8)),
				color, "Neon_%d_%d" % [x, y]
			)
			_dance_tiles[Vector2i(x, y)] = poly
	_add_inlay_outline(
		Rect2(Vector2(56.85 * TILE, 11.85 * TILE), Vector2(7.3 * TILE, 5.3 * TILE)),
		Color(1.0, 0.32, 0.88, 0.85), "MarcoPista"
	)

	# Cámara final
	_add_inlay_rect(
		Rect2(Vector2(88.7 * TILE, 3.0 * TILE), Vector2(4.6 * TILE, 4.5 * TILE)),
		Color(0.7, 0.42, 0.08, 0.12), "CaminoFinal"
	)
	_add_inlay_outline(
		Rect2(Vector2(84.25 * TILE, 1.3 * TILE), Vector2(11.5 * TILE, 7.2 * TILE)),
		Color(0.92, 0.62, 0.22, 0.58), "MarcoFinal"
	)


func _add_inlay_rect(rect: Rect2, color: Color, node_name: String) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	polygon.color = color
	floor_inlays.add_child(polygon)
	return polygon


func _add_inlay_outline(rect: Rect2, color: Color, node_name: String) -> void:
	var line := Line2D.new()
	line.name = node_name
	line.width = 3.0
	line.default_color = color
	line.antialiased = false
	line.points = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
		rect.position,
	])
	floor_inlays.add_child(line)


func _build_wall_collisions_from_existing_floor() -> void:
	if not is_instance_valid(floor_layer) or not is_instance_valid(walls_collision):
		return
	for child in walls_collision.get_children():
		child.free()

	var walkable: Dictionary = {}
	for cell in floor_layer.get_used_cells():
		walkable[cell] = true

	var boundary: Dictionary = {}
	for value in walkable.keys():
		var cell := value as Vector2i
		for direction in CARDINALS:
			var neighbor: Vector2i = cell + (direction as Vector2i)
			if not walkable.has(neighbor):
				boundary[neighbor] = true

	var rows: Dictionary = {}
	for value in boundary.keys():
		var cell := value as Vector2i
		if not rows.has(cell.y):
			rows[cell.y] = []
		(rows[cell.y] as Array).append(cell.x)

	for y_value in rows.keys():
		var y := int(y_value)
		var xs: Array = rows[y]
		xs.sort()
		var start := int(xs[0])
		var previous := start
		for index in range(1, xs.size()):
			var current := int(xs[index])
			if current != previous + 1:
				_add_collision_run(walls_collision, y, start, previous)
				start = current
			previous = current
		_add_collision_run(walls_collision, y, start, previous)


func _add_collision_run(parent: StaticBody2D, y: int, start_x: int, end_x: int) -> void:
	var width := (end_x - start_x + 1) * TILE
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, TILE)
	var collision := CollisionShape2D.new()
	collision.name = "Muro_%d_%d_%d" % [y, start_x, end_x]
	collision.position = Vector2((start_x + end_x + 1) * TILE * 0.5, (y + 0.5) * TILE)
	collision.shape = shape
	parent.add_child(collision)


func _build_obstacle_collisions() -> void:
	if not is_instance_valid(obstacles_collision):
		return
	for child in obstacles_collision.get_children():
		child.free()
	_add_obstacle(Vector2(663, 585), Vector2(42, 42), "BarrilEntrada")
	_add_obstacle(Vector2(2652, 1108), Vector2(44, 46), "BustoArchivo")
	_add_obstacle(Vector2(2510, 975), Vector2(72, 48), "MesaProyector")
	_add_obstacle(Vector2(4719, 1310), Vector2(170, 44), "CabinaKinder")
	_add_obstacle(Vector2(5070, 1201), Vector2(86, 44), "BarraKinder")
	_add_obstacle(Vector2(4368, 835), Vector2(42, 42), "GargolaKinderA")
	_add_obstacle(Vector2(5070, 835), Vector2(42, 42), "GargolaKinderB")
	_add_obstacle(Vector2(5694, 550), Vector2(52, 46), "AngelTerror")


func _add_obstacle(pos: Vector2, size: Vector2, node_name: String) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.name = node_name
	collision.position = pos
	collision.shape = shape
	obstacles_collision.add_child(collision)


# =============================================================================
# JUGADOR, UI Y ACTIVIDADES
# =============================================================================

func _setup_activities_ui() -> void:
	_activities = ACTIVITIES_SCRIPT.new()
	_activities.name = "ActividadesUI"
	add_child(_activities)
	_activities.activity_completed.connect(_on_activity_completed)
	_activities.activity_closed.connect(_on_activity_closed)


func _setup_progress_hud() -> void:
	var content := get_node_or_null("UI/SectionPanel/Margin/Content") as VBoxContainer
	if content == null:
		return
	_progress_label = Label.new()
	_progress_label.name = "ProgressLabel"
	_progress_label.add_theme_font_size_override("font_size", 13)
	_progress_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	_progress_label.text = "Ecos descubiertos: 0 / 4"
	content.add_child(_progress_label)


func _spawn_selected_player() -> void:
	var character_type := _load_character_type()
	var scene_path := MALE_PLAYER_SCENE if character_type == "hombre" else FEMALE_PLAYER_SCENE
	var player_scene := load(scene_path) as PackedScene
	active_player = player_scene.instantiate() as CharacterBody2D
	active_player.name = "player"
	active_player.position = player_spawn.position
	active_player.z_index = 20
	add_child(active_player)
	if not active_player.is_in_group("player"):
		active_player.add_to_group("player")
	var camera := player_spawn.get_node("Camera2D") as Camera2D
	camera.reparent(active_player, true)
	camera.position = Vector2(0, -38)
	camera.make_current()


func _load_character_type() -> String:
	var config := ConfigFile.new()
	var isolated_path := OS.get_environment("VIDEOJUEGO_CUSTOMIZATION_CACHE")
	if config.load(isolated_path if not isolated_path.is_empty() else CUSTOMIZATION_PATH) != OK:
		return "mujer"
	return str(config.get_value("character", "type", "mujer"))


func _connect_interactables() -> void:
	for candidate in get_tree().get_nodes_in_group("tunnel_interactable"):
		if candidate.has_signal("activated") and not candidate.activated.is_connected(_on_tunnel_interaction):
			candidate.activated.connect(_on_tunnel_interaction)


func _set_player_locked(locked: bool) -> void:
	if is_instance_valid(active_player) and active_player.has_method("set_movement_enabled"):
		active_player.set_movement_enabled(not locked)


# =============================================================================
# DESPACHO DE INTERACCIONES (E)
# =============================================================================

func _on_tunnel_interaction(interaction_id: String, title: String, message: String) -> void:
	if is_instance_valid(_activities) and _activities.is_open():
		return

	match interaction_id:
		"return_exit":
			exit_requested.emit()
			if get_tree().current_scene == self:
				_return_to_surface()
		"chapinero_origin":
			_set_player_locked(true)
			_activities.open_single_card(
				"MEMORIA DE CHAPINERO · ORIGEN DEL NOMBRE",
				"Antón Hero Cepeda y los chapines (1885)",
				ART_DIR + "chapines_origen.png",
				"En la Santafé colonial, el zapatero Antón Hero fabricaba 'chapines' de suela alta de madera para el barro. El nombre se oficializó el 17 de diciembre de 1885. (Recreación artística)",
				Color(0.95, 0.72, 0.34)
			)
		"hippies_turntable":
			_toggle_hippies_turntable()
		"hippies_mural":
			_cycle_hippies_mural()
		"hippies_timeline":
			_set_player_locked(true)
			_activities.open_hippies_timeline(bool(_solved_secrets["hippies_timeline"]))
		"pozzetto_projector":
			_set_player_locked(true)
			_activities.open_pozzetto_projector(bool(_solved_secrets["pozzetto_archive"]))
		"pozzetto_calendar":
			_show_notice("Calendario · 4 de diciembre de 1986", "Fecha marcada en el archivo histórico de Chapinero. Activa el proyector de la mesa para recorrer los registros.")
		"pozzetto_tv":
			_pulse_pozzetto_tv()
			_show_notice("Televisor de archivo (años 80)", "Entre la estática se distinguen titulares de época sobre el restaurante italiano de la Carrera 7 con Calle 61.")
		"metro_theatron":
			_set_player_locked(true)
			_activities.open_dual_comparison(
				"TRANSFORMACIÓN CULTURAL DE CHAPINERO",
				"Del Cine Metro Riviera (1960s–1995) a Theatron (2002)",
				ART_DIR + "metro_riviera_cine.png",
				"Años 60–1995: El Metro Riviera fue una de las salas de cine más grandes de Chapinero (~1.000 sillas). Cerró en 1995. (Recreación artística)",
				ART_DIR + "theatron_actual.png",
				"Desde 2002: El antiguo cine renació como Theatron, ícono cultural y de diversidad en Bogotá con más de diez ambientes. (Recreación artística)",
				Color(0.84, 0.32, 1.0)
			)
		"kinder_booth":
			_toggle_kinder_party()
		"kinder_lights":
			_set_player_locked(true)
			_activities.open_kinder_lights(bool(_solved_secrets["kinder_lights"]))
		"kinder_secret":
			if _kinder_supernova:
				_show_notice("Compartimento secreto KINDER", "¡Encontraste el Vinilo Neón de Chapinero escondido tras los parlantes!")
				_spawn_celebration_burst(Vector2(4420, 1290), Color(1.0, 0.28, 0.9))
			else:
				_show_notice("Compartimento sellado", "Un panel brilla suavemente detrás de los parlantes. Sincroniza la consola de luces para abrirlo.")
		"terror_mirror":
			_trigger_mirror_shift(true)
			_show_notice("Espejo del corredor", "Por un segundo tu reflejo llegó tarde... y grietas violetas recorrieron el vidrio.")
		"terror_secret_crack":
			_unlock_terror_secret()
		"final_gate":
			var count := _count_solved_secrets()
			if count >= 4:
				_show_notice("La puerta del último eco · 4 / 4", "Los cuatro cristales del túnel brillan al unísono. Has despertado todos los ecos subterráneos de Chapinero.")
				_spawn_celebration_burst(Vector2(7098, 220), Color(1.0, 0.82, 0.32))
			else:
				_show_notice("La puerta del último eco · %d / 4" % count, "Cuatro cristales esperan junto a la puerta: Hippies, Archivo 1986, KINDER y el Ramal Secreto.")
		_:
			_show_notice(title, message)


func _on_activity_closed() -> void:
	_set_player_locked(false)


func _on_activity_completed(activity_id: String) -> void:
	if _solved_secrets.has(activity_id):
		_solved_secrets[activity_id] = true
	_refresh_altar_crystals()

	match activity_id:
		"hippies_timeline":
			_spawn_celebration_burst(Vector2(2420, 260), Color(1.0, 0.64, 0.22))
			var light := get_node_or_null("Iluminacion/LuzHippiesMusica") as PointLight2D
			if light != null:
				light.energy = 1.2
			_show_notice("¡Eco de los años 70 revelado!", "Ordenaste la historia del Parque de los Hippies. El túnel florece en colores cálidos.")
		"pozzetto_archive":
			var lantern := get_node_or_null("ElementosAntigravity/ArchivoPozzetto/FarolMemoria") as Sprite2D
			if lantern != null:
				lantern.visible = true
			var lantern_light := get_node_or_null("Iluminacion/LuzFarolMemoria") as PointLight2D
			if lantern_light != null:
				lantern_light.visible = true
				lantern_light.energy = 1.05
			_show_notice("Farol de la memoria encendido", "Has completado el archivo histórico de 1986 con respeto. Una luz cálida honra el recuerdo.")
		"kinder_lights":
			_kinder_supernova = true
			_kinder_party_on = true
			_spawn_celebration_burst(Vector2(4719, 1080), Color(0.18, 0.96, 1.0))
			var secret_glow := get_node_or_null("ElementosAntigravity/KinderExtras/BrilloSecretoKinder") as PointLight2D
			if secret_glow != null:
				secret_glow.visible = true
			_show_notice("¡SUPERNOVA KINDER!", "La pista entra en modo fiesta total y se ilumina un compartimento secreto junto a los parlantes.")


# =============================================================================
# INTERACCIONES DIRECTAS EN EL MUNDO (IN-WORLD)
# =============================================================================

func _toggle_hippies_turntable() -> void:
	_hippies_music_on = not _hippies_music_on
	if _hippies_music_on:
		_kinder_party_on = false
		_show_notice("Tocadiscos de los 70 · Encendido", "Suena una melodía acústica retro mientras el vinilo gira en el rincón musical.")
		_spawn_celebration_burst(Vector2(1980, 480), Color(1.0, 0.52, 0.82))
	else:
		_show_notice("Tocadiscos de los 70 · En pausa", "El vinilo se detiene suavemente y vuelve el eco del túnel.")


func _cycle_hippies_mural() -> void:
	_mural_index = (_mural_index + 1) % MURAL_REGIONS.size()
	var mural := get_node_or_null("ElementosAntigravity/Hippies/MuralInteractivo") as Sprite2D
	if mural != null and mural.texture is AtlasTexture:
		var atlas := (mural.texture as AtlasTexture).duplicate() as AtlasTexture
		atlas.region = MURAL_REGIONS[_mural_index]
		mural.texture = atlas
		var tw := create_tween()
		mural.modulate = Color(1.6, 1.4, 1.8, 1.0)
		tw.tween_property(mural, "modulate", Color.WHITE, 0.45)
	_spawn_celebration_burst(Vector2(2125, 165), Color(0.95, 0.45, 1.0))
	_show_notice(MURAL_TITLES[_mural_index], "Los colores del mural cambian bajo la luz subterránea (presiona E otra vez para ver otra obra).")


func _pulse_pozzetto_tv() -> void:
	var tv := get_node_or_null("ElementosAntigravity/ArchivoPozzetto/TelevisorArchivo") as Sprite2D
	if tv == null:
		return
	var tw := create_tween()
	tw.tween_property(tv, "modulate", Color(1.4, 1.35, 1.6, 1.0), 0.1)
	tw.tween_property(tv, "modulate", Color(0.85, 0.85, 0.95, 1.0), 0.15)
	tw.tween_property(tv, "modulate", Color.WHITE, 0.2)


func _toggle_kinder_party() -> void:
	if not _kinder_party_on:
		_kinder_party_on = true
		_hippies_music_on = false
		_show_notice("Cabina DJ KINDER · Fiesta activa", "La pista LED responde a tus pasos y la consola mezcla el ritmo subterráneo. Vuelve a pulsar E para cambiar las luces.")
	else:
		_kinder_palette_index = (_kinder_palette_index + 1) % KINDER_PALETTES.size()
		_show_notice("Cabina DJ KINDER · Luces #%d" % (_kinder_palette_index + 1), "La paleta de neón cambia en toda la cámara.")
	_spawn_celebration_burst(Vector2(4719, 1240), KINDER_PALETTES[_kinder_palette_index][0])


func _unlock_terror_secret() -> void:
	if _solved_secrets["terror_secret"]:
		_show_notice("Pasaje oculto del eco", "El cristal del ramal secreto ya fue despertado.")
		return
	_solved_secrets["terror_secret"] = true
	var crystal := get_node_or_null("ElementosAntigravity/TerrorExtras/CristalOcultoRamal") as Sprite2D
	if crystal != null:
		crystal.visible = true
	_spawn_celebration_burst(Vector2(6160, -140), Color(0.32, 0.96, 1.0))
	_refresh_altar_crystals()
	_show_notice("¡Compartimento oculto descubierto!", "Detrás de una piedra floja en el ramal secreto brillaba un eco cristalino.")


# =============================================================================
# EFECTOS VISUALES, LUCES, PISTA REACTIVA Y EVENTOS DE MISTERIO
# =============================================================================

func _animate_lights_and_props(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001

	# Luz de terror parpadeante
	if is_instance_valid(terror_light):
		var flicker := 0.56 + sin(t * 17.0) * 0.16
		if fmod(t, 4.3) < 0.09:
			flicker = 0.14
		terror_light.energy = flicker

	# Bola de discoteca KINDER girando/brillando
	var disco := get_node_or_null("DecoracionRetro/Kinder/BolaDisco") as Sprite2D
	if disco != null:
		var speed := 1.6 if _kinder_supernova else (0.9 if _kinder_party_on else 0.25)
		disco.rotation = sin(t * speed) * 0.14
		var pulse := 1.0 + sin(t * (5.0 if _kinder_party_on else 1.5)) * 0.04
		disco.scale = Vector2(0.42 * pulse, 0.42 * pulse)

	# Luces KINDER dinámicas
	var luz_m := get_node_or_null("Iluminacion/LuzKinderMagenta") as PointLight2D
	var luz_a := get_node_or_null("Iluminacion/LuzKinderAzul") as PointLight2D
	if luz_m != null and luz_a != null:
		var mult := 1.25 if _kinder_supernova else (1.05 if _kinder_party_on else 0.85)
		luz_m.energy = (0.85 + sin(t * 4.2) * 0.25) * mult
		luz_a.energy = (0.85 + cos(t * 4.2) * 0.25) * mult

	# Tocadiscos girando sutilmente si la música está activa
	var turntable := get_node_or_null("ElementosAntigravity/Hippies/Tocadiscos") as Sprite2D
	if turntable != null and _hippies_music_on:
		turntable.scale = Vector2(0.48 + sin(t * 6.0) * 0.015, 0.48 - sin(t * 6.0) * 0.015)

	# Estática suave en TV de Archivo Pozzetto
	var tv_light := get_node_or_null("Iluminacion/LuzArchivoTV") as PointLight2D
	if tv_light != null:
		tv_light.energy = 0.42 + sin(t * 23.0) * 0.07

	# Fantasma ficticio flotando
	if _ghost_seen and is_instance_valid(ghost) and ghost.modulate.a > 0.0:
		ghost.rotation = sin(t * 4.0) * 0.03

	_ambient_phase = fmod(_ambient_phase + delta * 0.05, TAU)


func _animate_kinder_floor() -> void:
	if _dance_tiles.is_empty():
		return
	var t := Time.get_ticks_msec() * 0.001
	var palette: Array = KINDER_PALETTES[_kinder_palette_index]
	var player_cell := Vector2i(-999, -999)
	if is_instance_valid(active_player):
		player_cell = Vector2i(floori(active_player.position.x / TILE), floori(active_player.position.y / TILE))

	for cell_val in _dance_tiles.keys():
		var cell := cell_val as Vector2i
		var poly := _dance_tiles[cell] as Polygon2D
		var base_col: Color = palette[0] if (cell.x + cell.y) % 2 == 0 else palette[1]
		var wave := 0.0
		if _kinder_supernova:
			wave = 0.22 + 0.22 * sin(t * 6.5 + float(cell.x) * 0.7 + float(cell.y) * 0.7)
		elif _kinder_party_on:
			wave = 0.14 + 0.14 * sin(t * 3.8 + float(cell.x + cell.y) * 0.6)
		var col := Color(base_col.r, base_col.g, base_col.b, clampf(base_col.a + wave, 0.14, 0.78))
		if cell == player_cell:
			col = Color(1.0, 0.96, 1.0, 0.72)
		poly.color = col


func _check_terror_proximity_events() -> void:
	if not is_instance_valid(active_player):
		return
	var p := active_player.position

	# 1. Sombra fugaz que cruza el corredor al entrar a la zona de terror (una sola vez)
	if not _shadow_seen and p.x > 5320.0 and p.x < 5750.0 and p.y < 680.0:
		_shadow_seen = true
		_run_passing_shadow()

	# 2. Ojos luminosos detrás de la pared oscura cuando el jugador se acerca
	var eyes := get_node_or_null("ElementosAntigravity/TerrorExtras/OjosOscuridad") as Node2D
	if eyes != null:
		var dist := p.distance_to(eyes.position)
		var target_alpha := 0.92 if dist < 340.0 else 0.08
		if dist < 340.0 and fmod(Time.get_ticks_msec() * 0.001, 3.4) < 0.14:
			target_alpha = 0.05 # Parpadeo realista
		eyes.modulate.a = lerpf(eyes.modulate.a, target_alpha, 0.12)

	# 3. Espejo inquietante que cambia cuando el jugador se acerca
	var mirror := get_node_or_null("ElementosAntigravity/TerrorExtras/EspejoInquietante") as Sprite2D
	if mirror != null and not _mirror_altered and p.distance_to(mirror.position) < 165.0:
		_trigger_mirror_shift(false)


func _run_passing_shadow() -> void:
	var shadow := get_node_or_null("Efectos/SombraFugaz") as Polygon2D
	if shadow == null:
		return
	shadow.visible = true
	shadow.position = Vector2(5620, 210)
	shadow.modulate = Color(0.03, 0.01, 0.06, 0.0)
	var tw := create_tween()
	tw.tween_property(shadow, "modulate:a", 0.78, 0.12)
	tw.parallel().tween_property(shadow, "position", Vector2(5620, 560), 0.55)
	tw.tween_property(shadow, "modulate:a", 0.0, 0.18)
	tw.tween_callback(shadow.hide)


func _trigger_mirror_shift(forced: bool) -> void:
	if _mirror_altered and not forced:
		return
	_mirror_altered = true
	var mirror := get_node_or_null("ElementosAntigravity/TerrorExtras/EspejoInquietante") as Sprite2D
	if mirror != null:
		mirror.texture = load(ART_DIR + "prop_espejo_alterado.png") as Texture2D
		var tw := create_tween()
		mirror.modulate = Color(1.5, 0.85, 1.8, 1.0)
		tw.tween_property(mirror, "modulate", Color.WHITE, 0.5)


func _on_ghost_trigger_body_entered(candidate: Node2D) -> void:
	if _ghost_seen or not candidate.is_in_group("player"):
		return
	_ghost_seen = true

	# Breve susto controlado: parpadeo fugaz de oscuridad + fantasma ficticio
	if is_instance_valid(darkness_modulate):
		var original_color := darkness_modulate.color
		var blink := create_tween()
		blink.tween_property(darkness_modulate, "color", Color(0.18, 0.14, 0.26, 1.0), 0.08)
		blink.tween_interval(0.22)
		blink.tween_property(darkness_modulate, "color", original_color, 0.25)

	ghost.show()
	ghost.modulate.a = 0.0
	ghost.position = Vector2(76.0 * TILE, 4.25 * TILE)
	_ghost_tween = create_tween()
	_ghost_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ghost_tween.tween_property(ghost, "modulate:a", 0.88, 0.18)
	_ghost_tween.parallel().tween_property(ghost, "position:x", ghost.position.x + 135.0, 0.9)
	_ghost_tween.tween_interval(0.42)
	_ghost_tween.tween_property(ghost, "modulate:a", 0.0, 0.42)
	_ghost_tween.tween_callback(ghost.hide)
	_show_notice("Un eco ficticio del túnel", "Una silueta traviesa cruzó el corredor y se desvaneció en la penumbra.")


func _spawn_celebration_burst(world_pos: Vector2, tint: Color) -> void:
	var burst := CPUParticles2D.new()
	burst.position = world_pos
	burst.z_index = 40
	burst.emitting = true
	burst.one_shot = true
	burst.amount = 28
	burst.lifetime = 1.15
	burst.explosiveness = 0.88
	burst.spread = 180.0
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 175.0
	burst.gravity = Vector2(0, 85)
	burst.scale_amount_min = 4.0
	burst.scale_amount_max = 8.0
	burst.color = tint
	add_child(burst)
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(burst):
			burst.queue_free()
	)


func _count_solved_secrets() -> int:
	var total := 0
	for k in _solved_secrets.keys():
		if bool(_solved_secrets[k]):
			total += 1
	return total


func _refresh_altar_crystals() -> void:
	var count := _count_solved_secrets()
	if is_instance_valid(_progress_label):
		_progress_label.text = "Ecos descubiertos: %d / 4" % count
	var map_nodes := {
		"hippies_timeline": "ElementosAntigravity/CamaraFinalExtras/CristalHippies",
		"pozzetto_archive": "ElementosAntigravity/CamaraFinalExtras/CristalPozzetto",
		"kinder_lights": "ElementosAntigravity/CamaraFinalExtras/CristalKinder",
		"terror_secret": "ElementosAntigravity/CamaraFinalExtras/CristalTerror",
	}
	for secret_key in map_nodes.keys():
		var node := get_node_or_null(map_nodes[secret_key]) as CanvasItem
		if node != null:
			var unlocked := bool(_solved_secrets[secret_key])
			node.modulate = Color(1.3, 1.3, 1.3, 1.0) if unlocked else Color(0.32, 0.28, 0.42, 0.55)


# =============================================================================
# REGRESO A SUPERFICIE, AVISOS Y SECCIONES
# =============================================================================

func _return_to_surface() -> void:
	if _changing_scene:
		return
	_changing_scene = true
	_set_player_locked(true)
	get_tree().root.set_meta(RETURN_FROM_TUNNEL_META, true)
	var error := get_tree().change_scene_to_file(MAP_SCENE)
	if error != OK:
		get_tree().root.remove_meta(RETURN_FROM_TUNNEL_META)
		_changing_scene = false
		_set_player_locked(true)
		_set_player_locked(false)
		_show_notice("Escalera de regreso", "No fue posible volver al mapa. Inténtalo de nuevo.")


func _show_notice(title: String, message: String) -> void:
	notice_title.text = title
	notice_text.text = message
	notice_panel.show()
	notice_timer.start()


func _update_section(force: bool) -> void:
	if not is_instance_valid(active_player):
		return
	var section := _section_for_position(active_player.position)
	if not force and section[0] == _last_section:
		return
	_last_section = section[0]
	section_title.text = section[0]
	section_subtitle.text = section[1]


func _section_for_position(position_value: Vector2) -> PackedStringArray:
	if position_value.y > 650.0 and position_value.x < 3400.0:
		return PackedStringArray(["ARCHIVO DE POZZETTO · 1986", "Memoria histórica de Chapinero. Examina el proyector y los documentos."])
	if position_value.y > 650.0:
		return PackedStringArray(["KINDER · FIESTA SUBTERRÁNEA", "Pista LED reactiva, cabina DJ y consola de luces neón."])
	if position_value.y < 0.0:
		return PackedStringArray(["RAMAL SECRETO", "Un pasaje oculto guarda una grieta luminosa y una puerta encadenada."])
	if position_value.x < 850.0:
		return PackedStringArray(["EL UMBRAL", "Piedra húmeda, tuberías antiguas y la escalera de regreso."])
	if position_value.x < 1650.0:
		return PackedStringArray(["CORREDOR DE LOS CHAPINES", "Un pasaje industrial evoca los orígenes coloniales de Chapinero."])
	if position_value.x < 3150.0:
		return PackedStringArray(["ZONA DE LOS HIPPIES · AÑOS 70", "Murales cambiantes, vinilo y memoria viva del Parque de los Hippies."])
	if position_value.x < 4550.0:
		return PackedStringArray(["PUERTAS CULTURALES", "Arte, conocimiento, diversidad y la metamorfosis de Metro Riviera a Theatron."])
	if position_value.x < 5300.0:
		return PackedStringArray(["UMBRAL DE NEÓN", "El corredor vibra sobre la entrada de la cámara KINDER."])
	if position_value.x < 6700.0:
		return PackedStringArray(["TRAMO DE TERROR Y MISTERIO", "Sombras fugaces, ojos en la penumbra y un espejo inquietante."])
	return PackedStringArray(["CÁMARA DEL ÚLTIMO ECO", "Cuatro cristales registran los secretos despertados en el túnel."])


# =============================================================================
# AUDIO AMBIENTAL Y MELODÍAS ORIGINALES SINTETIZADAS
# =============================================================================

func _setup_ambient_audio() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.55
	ambient_player.stream = generator
	ambient_player.play()
	_ambient_playback = ambient_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_ambient_rng.seed = 90517


func _fill_ambient_buffer() -> void:
	if _ambient_playback == null:
		return
	var frames := _ambient_playback.get_frames_available()
	if frames <= 0:
		return
	const SR := 22050.0
	const HIPPIES_NOTES := [261.63, 293.66, 329.63, 392.00, 440.00, 392.00, 329.63, 293.66]
	const KINDER_BASS := [110.0, 110.0, 130.81, 146.83, 164.81, 146.83, 130.81, 98.0]

	var in_kinder := is_instance_valid(active_player) and active_player.position.y > 650.0 and active_player.position.x > 3800.0
	var in_hippies := is_instance_valid(active_player) and active_player.position.x >= 1600.0 and active_player.position.x <= 3200.0 and active_player.position.y < 650.0

	for _i in range(frames):
		_music_time += 1.0 / SR
		_ambient_phase = fmod(_ambient_phase + TAU * 48.0 / SR, TAU)
		var sample := sin(_ambient_phase) * 0.015 + sin(_ambient_phase * 0.47) * 0.007
		sample += _ambient_rng.randf_range(-0.003, 0.003)

		if _hippies_music_on and in_hippies:
			var step := int(floor(_music_time * 2.2)) % HIPPIES_NOTES.size()
			var freq: float = HIPPIES_NOTES[step]
			var env := exp(-fmod(_music_time * 2.2, 1.0) * 3.5)
			sample += (sin(_music_time * TAU * freq) * 0.055 + sin(_music_time * TAU * freq * 0.5) * 0.025) * env
		elif _kinder_party_on and in_kinder:
			var beat_rate := 4.4 if _kinder_supernova else 3.6
			var step_k := int(floor(_music_time * beat_rate)) % KINDER_BASS.size()
			var bfreq: float = KINDER_BASS[step_k]
			var env_k := exp(-fmod(_music_time * beat_rate, 1.0) * 5.2)
			var synth := sin(_music_time * TAU * bfreq) * 0.055 + sin(_music_time * TAU * bfreq * 2.0) * 0.025
			sample += synth * env_k

		_ambient_playback.push_frame(Vector2(sample, sample))
