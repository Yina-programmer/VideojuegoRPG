extends Control

const PLAYER_SCENE = "res://scenes/player/player.tscn"

@onready var preview_player = $ClosetPanel/CharacterPanel/player
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

@onready var outfit_buttons = {
	"original": $ClosetPanel/InventoryPanel/OutfitsGrid/OriginalButton,
	"rosa": $ClosetPanel/InventoryPanel/OutfitsGrid/PinkButton,
	"azul": $ClosetPanel/InventoryPanel/OutfitsGrid/BlueButton,
	"negro": $ClosetPanel/InventoryPanel/OutfitsGrid/BlackButton,
	"blanco_mono": $ClosetPanel/InventoryPanel/OutfitsGrid/WhiteBowButton,
	"negro_mono": $ClosetPanel/InventoryPanel/OutfitsGrid/BlackBowButton
}

@onready var hair_buttons = {
	"castano": $ClosetPanel/InventoryPanel/HairGrid/BrownHairButton,
	"trenzas_rojas": $ClosetPanel/InventoryPanel/HairGrid/RedBraidsButton,
	"flor_verde": $ClosetPanel/InventoryPanel/HairGrid/GreenFlowerButton
}

var outfit_names = {
	"original": "Clásico",
	"rosa": "Rosa",
	"azul": "Azul",
	"negro": "Negro",
	"blanco_mono": "Lazo blanco",
	"negro_mono": "Lazo negro"
}

var hair_names = {
	"castano": "Castaño",
	"trenzas_rojas": "Trenzas rojas",
	"flor_verde": "Flor verde"
}


func _ready() -> void:
	preview_player.set_physics_process(false)
	preview_player.set_process_input(false)
	preview_player.set_process_unhandled_input(false)
	_configure_button_interaction()

	for outfit_name in outfit_buttons:
		outfit_buttons[outfit_name].pressed.connect(_select_outfit.bind(outfit_name))
	for hair_name in hair_buttons:
		hair_buttons[hair_name].pressed.connect(_select_hair.bind(hair_name))

	outfits_tab.pressed.connect(_show_outfits)
	hair_tab.pressed.connect(_show_hair)
	$ClosetPanel/CharacterPanel/PreviousCharacter.pressed.connect(_character_arrow_pressed)
	$ClosetPanel/CharacterPanel/NextCharacter.pressed.connect(_character_arrow_pressed)
	$ClosetPanel/BackButton.pressed.connect(_go_back)
	save_button.pressed.connect(_save_customization)

	var swatches = $ClosetPanel/InventoryPanel/ColorRow.get_children()
	var swatch_outfits = ["original", "rosa", "azul", "negro", "blanco_mono", "negro_mono"]
	for index in swatches.size():
		swatches[index].pressed.connect(_select_outfit.bind(swatch_outfits[index]))

	preview_player.lastDirection = "down"
	_sync_selected_buttons()
	_show_outfits()
	_refresh_preview()

	# Conectar señales de ApiService (se desconectan en _exit_tree)
	ApiService.customization_loaded.connect(_on_customization_loaded)
	ApiService.customization_load_failed.connect(_on_customization_load_failed)
	ApiService.customization_saved.connect(_on_customization_saved)
	ApiService.customization_save_failed.connect(_on_customization_save_failed)

	# Iniciar sincronización con el servidor.
	# Si pending_sync = true → PUT con datos locales primero.
	# Si pending_sync = false → GET para cargar del servidor.
	ApiService.iniciar_sincronizacion(
		preview_player.outfit_actual,
		preview_player.cabello_actual,
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
	for button in outfit_buttons.values():
		buttons.append(button)
	for button in hair_buttons.values():
		buttons.append(button)
	for button in color_row.get_children():
		buttons.append(button)

	for button in buttons:
		button.disabled = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _select_outfit(outfit_name: String) -> void:
	preview_player.cambiar_outfit(outfit_name)
	outfit_buttons[outfit_name].button_pressed = true
	status_label.text = "Conjunto seleccionado: " + outfit_names[outfit_name]
	_refresh_preview()


func _select_hair(hair_name: String) -> void:
	preview_player.cambiar_cabello(hair_name)
	hair_buttons[hair_name].button_pressed = true
	status_label.text = "Cabello seleccionado: " + hair_names[hair_name]
	_refresh_preview()


func _refresh_preview() -> void:
	preview_player.lastDirection = "down"
	preview_player.body.animation = "walk_down"
	preview_player.body.frame = 0
	preview_player.body.stop()
	preview_player.actualizar_cabello_visual()
	selection_label.text = "%s  •  %s" % [
		outfit_names.get(preview_player.outfit_actual, preview_player.outfit_actual),
		hair_names.get(preview_player.cabello_actual, preview_player.cabello_actual)
	]
	_update_counter()


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
	status_label.text = "Elige uno de los tres estilos de cabello"
	_update_counter()


func _update_counter() -> void:
	if hair_grid.visible:
		var hair_keys = hair_buttons.keys()
		counter_label.text = "%d / %d" % [hair_keys.find(preview_player.cabello_actual) + 1, hair_keys.size()]
	else:
		var outfit_keys = outfit_buttons.keys()
		counter_label.text = "%d / %d" % [outfit_keys.find(preview_player.outfit_actual) + 1, outfit_keys.size()]


func _sync_selected_buttons() -> void:
	if outfit_buttons.has(preview_player.outfit_actual):
		outfit_buttons[preview_player.outfit_actual].button_pressed = true
	if hair_buttons.has(preview_player.cabello_actual):
		hair_buttons[preview_player.cabello_actual].button_pressed = true


func _character_arrow_pressed() -> void:
	status_label.text = "Por ahora solo está disponible el personaje mujer"


func _save_customization() -> void:
	# 1. Guardar localmente de inmediato (comportamiento original preservado)
	var result = preview_player.guardar_personalizacion()
	if result != OK:
		status_label.text = "No se pudo guardar. Inténtalo nuevamente."
		return

	# 2. Actualizar UI de forma inmediata y bloquear el botón
	status_label.text = "Guardando en el servidor..."
	save_button.text = "GUARDANDO..."
	save_button.disabled = true

	# 3. Enviar al servidor de forma asíncrona.
	# La respuesta llega por señal (_on_customization_saved / _on_customization_save_failed).
	# ApiService ignora la llamada si ya hay una solicitud en curso.
	ApiService.guardar_personalizacion(
		preview_player.outfit_actual,
		preview_player.cabello_actual,
		"mujer",
	)


func _go_back() -> void:
	get_tree().change_scene_to_file(PLAYER_SCENE)


## Se llama automáticamente cuando este nodo sale del árbol de escena.
## Desconecta las señales de ApiService para evitar llamadas sobre nodos liberados.
func _exit_tree() -> void:
	if ApiService.customization_loaded.is_connected(_on_customization_loaded):
		ApiService.customization_loaded.disconnect(_on_customization_loaded)
	if ApiService.customization_load_failed.is_connected(_on_customization_load_failed):
		ApiService.customization_load_failed.disconnect(_on_customization_load_failed)
	if ApiService.customization_saved.is_connected(_on_customization_saved):
		ApiService.customization_saved.disconnect(_on_customization_saved)
	if ApiService.customization_save_failed.is_connected(_on_customization_save_failed):
		ApiService.customization_save_failed.disconnect(_on_customization_save_failed)


## Callback: el servidor devolvió la personalización guardada.
## Solo aplica si difiere de los valores locales actuales para no interrumpir
## una edición que el jugador ya comenzó.
func _on_customization_loaded(outfit: String, hair: String) -> void:
	if preview_player.outfit_actual != outfit or preview_player.cabello_actual != hair:
		preview_player.cambiar_outfit(outfit)
		preview_player.cambiar_cabello(hair)
		# Actualizar el archivo local para que el personaje del mapa cargue esto
		preview_player.guardar_personalizacion()
		_sync_selected_buttons()
		_refresh_preview()
		status_label.text = "Personalización cargada del servidor"


## Callback: el servidor no tiene registro (primera vez) o hubo error de red.
## Se usan los valores locales existentes — no se altera nada.
func _on_customization_load_failed(reason: String) -> void:
	print("[ClosetUI] No se cargó del servidor: ", reason)


## Callback: el servidor confirmó el guardado con éxito.
func _on_customization_saved() -> void:
	save_button.disabled = false
	status_label.text = "¡Personalización guardada!"
	save_button.text = "GUARDADO"
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(save_button):
		save_button.text = "GUARDAR"


## Callback: el servidor no respondió o devolvió error.
## El archivo local ya fue guardado; pending_sync queda en true para reintentar.
func _on_customization_save_failed(reason: String) -> void:
	save_button.disabled = false
	save_button.text = "GUARDAR"
	status_label.text = "Guardado local. Sin conexión al servidor."
	print("[ClosetUI] Error al sincronizar con el servidor: ", reason)
