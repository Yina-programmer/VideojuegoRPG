extends Control

const MAP_SCENE = "res://scenes/map/Mapa_Chapinero.tscn"
const CUSTOMIZATION_PATH = "user://player_customization.cfg"
const FEMALE = "mujer"
const MALE = "hombre"

const OUTFIT_CATALOGS = {
	FEMALE: [
		{"id": "original", "label": "Clásico", "texture": preload("res://assets/player/body/c8c8b05b-6890-429b-8ac9-eac98615561e.png"), "region": Rect2(0, 0, 325, 403), "color": Color(0.24, 0.35, 0.25)},
		{"id": "rosa", "label": "Rosa", "texture": preload("res://assets/player/outfits/outfit_rosa.png"), "region": Rect2(0, 0, 325, 403), "color": Color(0.92, 0.48, 0.60)},
		{"id": "azul", "label": "Azul", "texture": preload("res://assets/player/outfits/outfit_azul.png"), "region": Rect2(0, 0, 325, 403), "color": Color(0.36, 0.58, 0.82)},
		{"id": "negro", "label": "Negro", "texture": preload("res://assets/player/outfits/outfit_negro.png"), "region": Rect2(0, 0, 325, 403), "color": Color(0.16, 0.15, 0.18)},
		{"id": "blanco_mono", "label": "Lazo blanco", "texture": preload("res://assets/player/outfits/outfit_blanco_mono.png"), "region": Rect2(0, 0, 325, 403), "color": Color(0.92, 0.88, 0.78)},
		{"id": "negro_mono", "label": "Lazo negro", "texture": preload("res://assets/player/outfits/outfit_negro_mono.png"), "region": Rect2(0, 0, 325, 403), "color": Color(0.32, 0.25, 0.25)}
	],
	MALE: [
		{"id": "general", "label": "Clásico", "texture": preload("res://assets/player_male/outfits/outfit_male_general.png"), "region": Rect2(0, 0, 325, 403), "color": Color(0.25, 0.38, 0.29)},
		{"id": "blue", "label": "Azul", "texture": preload("res://assets/player_male/outfits/outfit_male_blue.png"), "region": Rect2(0, 0, 325, 403), "color": Color(0.25, 0.48, 0.72)},
		{"id": "beige", "label": "Beige", "texture": preload("res://assets/player_male/outfits/outfit_male_beige.png"), "region": Rect2(0, 0, 325, 403), "color": Color(0.72, 0.61, 0.45)},
		{"id": "black", "label": "Negro", "texture": preload("res://assets/player_male/outfits/outfit_male_black.png"), "region": Rect2(0, 0, 325, 403), "color": Color(0.14, 0.14, 0.16)},
		{"id": "olive", "label": "Oliva", "texture": preload("res://assets/player_male/outfits/outfit_male_olive.png"), "region": Rect2(0, 0, 325, 403), "color": Color(0.38, 0.42, 0.24)},
		{"id": "formal", "label": "Formal", "texture": preload("res://assets/player_male/outfits/outfit_male_formal.png"), "region": Rect2(0, 0, 325, 403), "color": Color(0.18, 0.22, 0.29)},
		{"id": "shirtless", "label": "Sin camisa", "texture": preload("res://assets/player_male/outfits/outfit_male_shirtless.png"), "region": Rect2(0, 0, 325, 403), "color": Color(0.72, 0.50, 0.36)}
	]
}

const HAIR_CATALOGS = {
	FEMALE: [
		{"id": "castano", "label": "Castaño", "texture": preload("res://assets/player/hair/cabello_MATCH_975x1612.png"), "region": Rect2(0, 0, 325, 403)},
		{"id": "trenzas_rojas", "label": "Trenzas rojas", "texture": preload("res://assets/player/hair/cabello_trenzas_rojas.png"), "region": Rect2(0, 0, 325, 403)},
		{"id": "flor_verde", "label": "Flor verde", "texture": preload("res://assets/player/hair/cabello_trenza_flor_verde.png"), "region": Rect2(0, 0, 325, 403)},
		{"id": "rojo_medio", "label": "Rojo medio", "texture": preload("res://assets/hair/cabello_rojo_medio.png"), "region": Rect2(0, 0, 325, 403)},
		{"id": "negro_liso", "label": "Negro liso", "texture": preload("res://assets/hair/cabello_negro_liso.png"), "region": Rect2(0, 0, 325, 395)}
	],
	MALE: [
		{"id": "hair_male_black", "label": "Negro", "texture": preload("res://assets/player_male/hair/hair_male_black.png"), "region": Rect2(0, 0, 325, 390)},
		{"id": "hair_male_brown", "label": "Castaño", "texture": preload("res://assets/player_male/hair/hair_male_brown.png"), "region": Rect2(0, 0, 325, 390)},
		{"id": "hair_male_silver", "label": "Plateado", "texture": preload("res://assets/player_male/hair/hair_male_silver.png"), "region": Rect2(0, 0, 325, 390)},
		{"id": "hair_male_blonde", "label": "Rubio", "texture": preload("res://assets/player_male/hair/hair_male_blonde.png"), "region": Rect2(0, 0, 325, 390)}
	]
}

@onready var female_player = $ClosetPanel/CharacterPanel/player
@onready var male_player = $ClosetPanel/CharacterPanel/player_male
@onready var character_label: Label = $ClosetPanel/CharacterPanel/CharacterLabel
@onready var selection_label: Label = $ClosetPanel/CharacterPanel/SelectionLabel
@onready var section_title: Label = $ClosetPanel/InventoryPanel/InventoryHeader/SectionTitle
@onready var counter_label: Label = $ClosetPanel/InventoryPanel/InventoryHeader/CounterLabel
@onready var status_label: Label = $ClosetPanel/InventoryPanel/StatusLabel
@onready var outfits_grid: GridContainer = $ClosetPanel/InventoryPanel/OutfitsGrid
@onready var hair_grid: GridContainer = $ClosetPanel/InventoryPanel/HairGrid
@onready var palette_label: Label = $ClosetPanel/InventoryPanel/PaletteLabel
@onready var color_row: HBoxContainer = $ClosetPanel/InventoryPanel/ColorRow
@onready var outfits_tab: Button = $ClosetPanel/CategoryPanel/OutfitsTab
@onready var hair_tab: Button = $ClosetPanel/CategoryPanel/HairTab
@onready var save_button: Button = $ClosetPanel/SaveButton

@onready var outfit_buttons: Array[Button] = [
	$ClosetPanel/InventoryPanel/OutfitsGrid/OriginalButton,
	$ClosetPanel/InventoryPanel/OutfitsGrid/PinkButton,
	$ClosetPanel/InventoryPanel/OutfitsGrid/BlueButton,
	$ClosetPanel/InventoryPanel/OutfitsGrid/BlackButton,
	$ClosetPanel/InventoryPanel/OutfitsGrid/WhiteBowButton,
	$ClosetPanel/InventoryPanel/OutfitsGrid/BlackBowButton,
	$ClosetPanel/InventoryPanel/OutfitsGrid/ExtraOutfitButton
]

@onready var hair_buttons: Array[Button] = [
	$ClosetPanel/InventoryPanel/HairGrid/BrownHairButton,
	$ClosetPanel/InventoryPanel/HairGrid/RedBraidsButton,
	$ClosetPanel/InventoryPanel/HairGrid/GreenFlowerButton,
	$ClosetPanel/InventoryPanel/HairGrid/RedMediumHairButton,
	$ClosetPanel/InventoryPanel/HairGrid/BlackStraightHairButton
]

@onready var color_buttons: Array[Button] = [
	$ClosetPanel/InventoryPanel/ColorRow/ClassicColor,
	$ClosetPanel/InventoryPanel/ColorRow/PinkColor,
	$ClosetPanel/InventoryPanel/ColorRow/BlueColor,
	$ClosetPanel/InventoryPanel/ColorRow/BlackColor,
	$ClosetPanel/InventoryPanel/ColorRow/WhiteColor,
	$ClosetPanel/InventoryPanel/ColorRow/BowColor,
	$ClosetPanel/InventoryPanel/ColorRow/ExtraColor
]

var preview_player
var current_character: String = FEMALE
var character_players = {}


func _ready() -> void:
	character_players = {
		FEMALE: female_player,
		MALE: male_player
	}

	for player in character_players.values():
		player.set_physics_process(false)
		player.set_process(false)
		player.set_process_input(false)
		player.set_process_unhandled_input(false)

	_configure_button_interaction()
	for index in outfit_buttons.size():
		outfit_buttons[index].pressed.connect(_select_outfit.bind(index))
	for index in hair_buttons.size():
		hair_buttons[index].pressed.connect(_select_hair.bind(index))
	for index in color_buttons.size():
		color_buttons[index].pressed.connect(_select_outfit.bind(index))

	outfits_tab.pressed.connect(_show_outfits)
	hair_tab.pressed.connect(_show_hair)
	$ClosetPanel/CharacterPanel/PreviousCharacter.pressed.connect(_character_arrow_pressed)
	$ClosetPanel/CharacterPanel/NextCharacter.pressed.connect(_character_arrow_pressed)
	$ClosetPanel/BackButton.pressed.connect(_go_back)
	save_button.pressed.connect(_save_customization)

	_switch_character(_load_character_type(), false)
	_show_outfits()
	_refresh_preview()

	ApiService.customization_loaded.connect(_on_customization_loaded)
	ApiService.customization_load_failed.connect(_on_customization_load_failed)
	ApiService.customization_saved.connect(_on_customization_saved)
	ApiService.customization_save_failed.connect(_on_customization_save_failed)
	ApiService.iniciar_sincronizacion(
		preview_player.outfit_actual,
		preview_player.cabello_actual,
		current_character,
	)


func _configure_button_interaction() -> void:
	var buttons: Array[Button] = [
		outfits_tab,
		hair_tab,
		$ClosetPanel/CharacterPanel/PreviousCharacter,
		$ClosetPanel/CharacterPanel/NextCharacter,
		$ClosetPanel/BackButton,
		save_button
	]
	buttons.append_array(outfit_buttons)
	buttons.append_array(hair_buttons)
	buttons.append_array(color_buttons)

	for button in buttons:
		button.disabled = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _switch_character(character_type: String, show_message: bool = true) -> void:
	if not character_players.has(character_type):
		character_type = FEMALE

	current_character = character_type
	preview_player = character_players[current_character]
	for type in character_players:
		character_players[type].visible = type == current_character

	character_label.text = "PERSONAJE: %s  %d / 2" % [
		"MUJER" if current_character == FEMALE else "HOMBRE",
		1 if current_character == FEMALE else 2
	]
	_apply_catalog_to_buttons()
	_sync_selected_buttons()
	_refresh_preview()
	if show_message:
		status_label.text = "Personaje seleccionado: " + ("Mujer" if current_character == FEMALE else "Hombre")


func _character_arrow_pressed() -> void:
	_switch_character(MALE if current_character == FEMALE else FEMALE)


func _apply_catalog_to_buttons() -> void:
	var outfits: Array = OUTFIT_CATALOGS[current_character]
	var hairs: Array = HAIR_CATALOGS[current_character]
	var outfit_height := 82.0 if outfits.size() > 6 else 126.0
	var color_size := 34.0 if outfits.size() > 6 else 42.0

	for index in outfit_buttons.size():
		var button := outfit_buttons[index]
		var available := index < outfits.size()
		button.visible = available
		button.disabled = not available
		button.button_pressed = false
		button.custom_minimum_size = Vector2(120, outfit_height)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if available:
			var item: Dictionary = outfits[index]
			button.icon = _create_icon(item.texture, item.region)
			button.tooltip_text = item.label

	for index in hair_buttons.size():
		var button := hair_buttons[index]
		var available := index < hairs.size()
		button.visible = available
		button.disabled = not available
		button.button_pressed = false
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if available:
			var item: Dictionary = hairs[index]
			button.icon = _create_icon(item.texture, item.region)
			button.tooltip_text = item.label

	for index in color_buttons.size():
		var button := color_buttons[index]
		var available := index < outfits.size()
		button.visible = available
		button.disabled = not available
		button.custom_minimum_size = Vector2(color_size, 42)
		if available:
			var item: Dictionary = outfits[index]
			button.modulate = item.color
			button.tooltip_text = item.label


func _create_icon(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var icon := AtlasTexture.new()
	icon.atlas = texture
	icon.region = region
	icon.margin = Rect2(-24, -24, 48, 48)
	return icon


func _select_outfit(index: int) -> void:
	var outfits: Array = OUTFIT_CATALOGS[current_character]
	if index >= outfits.size():
		return
	var item: Dictionary = outfits[index]
	preview_player.cambiar_outfit(item.id)
	outfit_buttons[index].button_pressed = true
	status_label.text = "Conjunto seleccionado: " + item.label
	_refresh_preview()


func _select_hair(index: int) -> void:
	var hairs: Array = HAIR_CATALOGS[current_character]
	if index >= hairs.size():
		return
	var item: Dictionary = hairs[index]
	preview_player.cambiar_cabello(item.id)
	hair_buttons[index].button_pressed = true
	status_label.text = "Cabello seleccionado: " + item.label
	_refresh_preview()


func _refresh_preview() -> void:
	preview_player.lastDirection = "down"
	preview_player.body.play("walk_down")
	preview_player.body.frame = 0
	preview_player.body.stop()
	preview_player.actualizar_cabello_visual()
	selection_label.text = "%s  •  %s" % [
		_catalog_label(OUTFIT_CATALOGS[current_character], preview_player.outfit_actual),
		_catalog_label(HAIR_CATALOGS[current_character], preview_player.cabello_actual)
	]
	_update_counter()


func _catalog_label(catalog: Array, item_id: String) -> String:
	for item in catalog:
		if item.id == item_id:
			return item.label
	return item_id


func _catalog_index(catalog: Array, item_id: String) -> int:
	for index in catalog.size():
		if catalog[index].id == item_id:
			return index
	return -1


func _show_outfits() -> void:
	outfits_grid.visible = true
	hair_grid.visible = false
	palette_label.visible = true
	color_row.visible = true
	outfits_tab.button_pressed = true
	section_title.text = "OUTFITS"
	status_label.text = "Elige un outfit o selecciona su color"
	_update_counter()


func _show_hair() -> void:
	outfits_grid.visible = false
	hair_grid.visible = true
	palette_label.visible = false
	color_row.visible = false
	hair_tab.button_pressed = true
	section_title.text = "CABELLO"
	status_label.text = "Elige uno de los estilos de cabello"
	_update_counter()


func _update_counter() -> void:
	var catalog: Array
	var selected_id: String
	if hair_grid.visible:
		catalog = HAIR_CATALOGS[current_character]
		selected_id = preview_player.cabello_actual
	else:
		catalog = OUTFIT_CATALOGS[current_character]
		selected_id = preview_player.outfit_actual
	var selected_index := _catalog_index(catalog, selected_id)
	counter_label.text = "%d / %d" % [max(selected_index + 1, 1), catalog.size()]


func _sync_selected_buttons() -> void:
	for button in outfit_buttons:
		button.button_pressed = false
	for button in hair_buttons:
		button.button_pressed = false

	var outfit_index := _catalog_index(OUTFIT_CATALOGS[current_character], preview_player.outfit_actual)
	var hair_index := _catalog_index(HAIR_CATALOGS[current_character], preview_player.cabello_actual)
	if outfit_index >= 0:
		outfit_buttons[outfit_index].button_pressed = true
	if hair_index >= 0:
		hair_buttons[hair_index].button_pressed = true


func _save_customization() -> void:
	var result = preview_player.guardar_personalizacion()
	if result != OK:
		status_label.text = "No se pudo guardar. Inténtalo nuevamente."
		return

	status_label.text = "Guardando en el servidor..."
	save_button.text = "GUARDANDO..."
	save_button.disabled = true
	ApiService.guardar_personalizacion(
		preview_player.outfit_actual,
		preview_player.cabello_actual,
		current_character,
	)


func _go_back() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)


func _load_character_type() -> String:
	var config := ConfigFile.new()
	if config.load(CUSTOMIZATION_PATH) != OK:
		return FEMALE
	var saved_type := str(config.get_value("character", "type", FEMALE))
	return saved_type if saved_type in [FEMALE, MALE] else FEMALE


func _exit_tree() -> void:
	if ApiService.customization_loaded.is_connected(_on_customization_loaded):
		ApiService.customization_loaded.disconnect(_on_customization_loaded)
	if ApiService.customization_load_failed.is_connected(_on_customization_load_failed):
		ApiService.customization_load_failed.disconnect(_on_customization_load_failed)
	if ApiService.customization_saved.is_connected(_on_customization_saved):
		ApiService.customization_saved.disconnect(_on_customization_saved)
	if ApiService.customization_save_failed.is_connected(_on_customization_save_failed):
		ApiService.customization_save_failed.disconnect(_on_customization_save_failed)


func _on_customization_loaded(outfit: String, hair: String, character_type: String) -> void:
	_switch_character(character_type, false)
	if preview_player.outfit_actual != outfit or preview_player.cabello_actual != hair:
		preview_player.cambiar_outfit(outfit)
		preview_player.cambiar_cabello(hair)
		preview_player.guardar_personalizacion()
		_sync_selected_buttons()
		_refresh_preview()
	status_label.text = "Personalización cargada del servidor"


func _on_customization_load_failed(reason: String) -> void:
	print("[ClosetUI] No se cargó del servidor: ", reason)


func _on_customization_saved() -> void:
	save_button.disabled = false
	status_label.text = "¡Personalización guardada!"
	save_button.text = "GUARDADO"
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(save_button):
		save_button.text = "GUARDAR"


func _on_customization_save_failed(reason: String) -> void:
	save_button.disabled = false
	save_button.text = "GUARDAR"
	status_label.text = "Guardado local. Sin conexión al servidor."
	print("[ClosetUI] Error al sincronizar con el servidor: ", reason)
