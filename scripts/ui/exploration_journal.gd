extends CanvasLayer

signal closed

@onready var root: Control = $Root
@onready var window: PanelContainer = $Root/Window
@onready var close_button: Button = $Root/Window/Margin/Content/Header/CloseButton
@onready var count_label: Label = $Root/Window/Margin/Content/Stats/Count
@onready var percent_label: Label = $Root/Window/Margin/Content/Stats/Percent
@onready var progress_bar: ProgressBar = $Root/Window/Margin/Content/Progress
@onready var status_label: Label = $Root/Window/Margin/Content/Status
@onready var completion_label: Label = $Root/Window/Margin/Content/Completion
@onready var cards_scroll: ScrollContainer = $Root/Window/Margin/Content/CardsScroll
@onready var cards_flow: HFlowContainer = $Root/Window/Margin/Content/CardsScroll/CardsFlow
@onready var detail_scroll: ScrollContainer = $Root/Window/Margin/Content/DetailScroll
@onready var back_button: Button = $Root/Window/Margin/Content/DetailScroll/Detail/BackButton
@onready var detail_icon: Label = $Root/Window/Margin/Content/DetailScroll/Detail/DetailIcon
@onready var detail_name: Label = $Root/Window/Margin/Content/DetailScroll/Detail/DetailName
@onready var detail_meta: Label = $Root/Window/Margin/Content/DetailScroll/Detail/DetailMeta
@onready var detail_story: RichTextLabel = $Root/Window/Margin/Content/DetailScroll/Detail/DetailStory

var _transition: Tween
var _progress_tween: Tween
var _closing := false


func _ready() -> void:
	root.hide()
	set_process_input(false)
	close_button.pressed.connect(close_journal)
	back_button.pressed.connect(_show_collection)
	ProgressManager.place_state_changed.connect(_on_progress_changed)
	ProgressManager.exploration_progress_changed.connect(_on_progress_counts_changed)
	ProgressManager.loading_changed.connect(_on_loading_changed)
	ProgressManager.synchronization_changed.connect(_on_sync_changed)
	_refresh()


func is_open() -> bool:
	return root.visible and not _closing


func open_journal() -> void:
	if root.visible:
		return
	_closing = false
	cards_scroll.show()
	detail_scroll.hide()
	root.show()
	set_process_input(true)
	progress_bar.value = 0.0
	_refresh()
	_kill_transition()
	root.modulate.a = 0.0
	window.pivot_offset = window.size * 0.5
	window.scale = Vector2(0.97, 0.97)
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition.tween_property(root, "modulate:a", 1.0, 0.22)
	_transition.tween_property(window, "scale", Vector2.ONE, 0.25)
	close_button.grab_focus()


func close_journal() -> void:
	if not root.visible or _closing:
		return
	_closing = true
	set_process_input(false)
	_kill_transition()
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition.tween_property(root, "modulate:a", 0.0, 0.16)
	_transition.tween_property(window, "scale", Vector2(0.98, 0.98), 0.16)
	_transition.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	root.hide()
	_closing = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not root.visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("OpenJournal"):
		get_viewport().set_input_as_handled()
		close_journal()
	elif event.is_action_pressed("Interact"):
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_update_stats()
	_rebuild_cards()


func _update_stats() -> void:
	var discovered := ProgressManager.get_discovered_count()
	var total := ProgressManager.get_total_count()
	var percent := roundi(100.0 * discovered / total) if total > 0 else 0
	count_label.text = "Lugares descubiertos: %d de %d" % [discovered, total]
	percent_label.text = "Exploración completada: %d%%" % percent
	if is_instance_valid(_progress_tween):
		_progress_tween.kill()
	if root.visible:
		_progress_tween = create_tween()
		_progress_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_progress_tween.tween_property(progress_bar, "value", float(percent), 0.55)
	else:
		progress_bar.value = percent
	completion_label.visible = total > 0 and discovered == total
	_update_status()


func _update_status() -> void:
	if ProgressManager.is_loading():
		status_label.text = "Cargando recorrido desde Chapinero..."
	elif ProgressManager.get_pending_count() > 0:
		status_label.text = "%d cambio(s) pendiente(s) de sincronizar con el servidor" % ProgressManager.get_pending_count()
	elif not ProgressManager.is_online():
		status_label.text = "Sin conexión · mostrando el último progreso disponible"
	else:
		status_label.text = "✓ Recorrido sincronizado"


func _rebuild_cards() -> void:
	for child in cards_flow.get_children():
		cards_flow.remove_child(child)
		child.queue_free()
	for place in ProgressManager.get_places():
		cards_flow.add_child(_make_card(place))
	if root.visible and detail_scroll.visible:
		# La vista de detalle también debe reflejar la confirmación de la fecha.
		var place_id := str(detail_scroll.get_meta("place_id", ""))
		if not place_id.is_empty():
			_fill_detail(place_id)


func _make_card(place: Dictionary) -> PanelContainer:
	var place_id := str(place.get("place_id", ""))
	var state := ProgressManager.get_state(place_id)
	var accent: Color = place.get("category_color", Color(0.85, 0.55, 0.24, 1))
	var state_color := Color(0.65, 0.64, 0.65, 1) if state == ProgressManager.PENDING else accent
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(270, 250)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_style(state, state_color))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 17)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 17)
	margin.add_theme_constant_override("margin_bottom", 15)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var top := HBoxContainer.new()
	column.add_child(top)
	var icon := _label("🔒" if state == ProgressManager.PENDING else ("◇" if state == ProgressManager.VISITED else "✦"), 29, state_color)
	icon.custom_minimum_size.x = 36
	top.add_child(icon)
	var state_text := "POR DESCUBRIR" if state == ProgressManager.PENDING else ("HISTORIA PENDIENTE" if state == ProgressManager.VISITED else "DESCUBIERTO")
	if state == ProgressManager.DISCOVERED and ProgressManager.is_pending_sync(place_id):
		state_text = "DESCUBIERTO · PENDIENTE"
	var state_label := _label(state_text, 12, state_color)
	state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(state_label)

	var title := _label("Lugar por descubrir" if state == ProgressManager.PENDING else str(place.get("name", "Lugar cultural")), 20, Color(1, 0.94, 0.82, 1))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var category := _label("Categoría desconocida" if state == ProgressManager.PENDING else str(place.get("category", "Cultura")), 13, state_color.lightened(0.15))
	category.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(category)

	var body_text := str(place.get("hint", "Una historia espera ser descubierta."))
	if state == ProgressManager.VISITED:
		body_text = "Ya llegaste aquí. Abre ‘Conocer este lugar’ en el mapa para revelar su historia."
	elif state == ProgressManager.DISCOVERED:
		body_text = "Historia consultada · pendiente de sincronización" if ProgressManager.is_pending_sync(place_id) else "Historia cultural registrada · %s" % str(place.get("npc_name", "Chapinero"))
	var body := _label(body_text, 15, Color(0.92, 0.84, 0.74, 1))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var action := Button.new()
	action.text = "VER HISTORIA  ›" if state == ProgressManager.DISCOVERED else ("HISTORIA PENDIENTE" if state == ProgressManager.VISITED else "SIGUE EXPLORANDO")
	action.disabled = state != ProgressManager.DISCOVERED
	action.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not action.disabled else Control.CURSOR_ARROW
	action.add_theme_color_override("font_color", Color(0.12, 0.08, 0.06, 1))
	action.add_theme_font_size_override("font_size", 15)
	action.add_theme_stylebox_override("normal", _button_style(accent.darkened(0.08)))
	action.add_theme_stylebox_override("hover", _button_style(accent.lightened(0.12)))
	action.add_theme_stylebox_override("disabled", _button_style(Color(0.4, 0.36, 0.34, 1)))
	action.pressed.connect(_show_detail.bind(place_id))
	column.add_child(action)
	card.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 0.22)
	return card


func _card_style(state: int, accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.12, 0.12, 0.88) if state == ProgressManager.PENDING else Color(0.19, 0.13, 0.1, 0.88)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(15)
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 6
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(9)
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _show_detail(place_id: String) -> void:
	if ProgressManager.get_state(place_id) != ProgressManager.DISCOVERED:
		return
	detail_scroll.set_meta("place_id", place_id)
	_fill_detail(place_id)
	cards_scroll.hide()
	detail_scroll.show()
	detail_scroll.scroll_vertical = 0
	back_button.grab_focus()


func _fill_detail(place_id: String) -> void:
	var place := ProgressManager.get_place_data(place_id)
	var record := ProgressManager.get_record(place_id)
	var accent: Color = place.get("category_color", Color(0.85, 0.55, 0.24, 1))
	detail_icon.add_theme_color_override("font_color", accent)
	detail_name.text = str(place.get("name", "Lugar cultural"))
	var date_text := "Pendiente de sincronización"
	if record.get("discovered_at") != null:
		date_text = "Descubierto el %s" % str(record["discovered_at"]).substr(0, 10)
	detail_meta.text = "%s  ·  NPC: %s  ·  %s" % [
		str(place.get("category", "Cultura")),
		str(place.get("npc_name", "Chapinero")),
		date_text,
	]
	detail_meta.add_theme_color_override("font_color", accent.lightened(0.2))
	detail_story.text = str(place.get("description", ""))


func _show_collection() -> void:
	detail_scroll.hide()
	cards_scroll.show()
	close_button.grab_focus()


func _on_progress_changed(_place_id: String) -> void:
	_refresh()


func _on_progress_counts_changed(_discovered: int, _total: int) -> void:
	_update_stats()


func _on_loading_changed(_loading_now: bool) -> void:
	_update_status()


func _on_sync_changed(_pending_count: int, _online_now: bool) -> void:
	_update_status()


func _kill_transition() -> void:
	if is_instance_valid(_transition):
		_transition.kill()
