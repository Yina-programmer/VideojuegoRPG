extends CanvasLayer

signal activity_completed(activity_id: String)
signal activity_closed

const ART_DIR := "res://assets/tilesets/tunel_ecos/antigravity/"

var _backdrop: ColorRect
var _panel: PanelContainer
var _content_box: VBoxContainer
var _title_label: Label
var _badge_label: Label
var _body_holder: VBoxContainer
var _status_label: Label
var _close_button: Button
var _is_open := false

# Estado: Puzzle cronológico de Hippies
var _hippies_order: Array[String] = []
var _hippies_buttons: Dictionary = {}

# Estado: Proyector y línea del tiempo de Pozzetto
var _pozzetto_index := 0
var _pozzetto_seen: Dictionary = {}
var _pozzetto_timeline_mode := false
var _pozzetto_timeline_order: Array[String] = []
var _pozzetto_slides := [
	{
		"img": ART_DIR + "pozzetto_slide1.png",
		"title": "1 / 4 · Chapinero, años 80",
		"caption": "Carrera 7 con Calle 61: ladrillo bogotano, faroles de tarde y vida cotidiana de barrio. (Recreación artística)",
	},
	{
		"img": ART_DIR + "pozzetto_slide2.png",
		"title": "2 / 4 · Restaurante Pozzetto",
		"caption": "Un tradicional restaurante italiano frecuentado por vecinos, estudiantes y familias del sector. (Recreación artística)",
	},
	{
		"img": ART_DIR + "pozzetto_slide3.png",
		"title": "3 / 4 · 4 de diciembre de 1986",
		"caption": "Una jornada trágica dejó 29 víctimas fatales y marcó para siempre la memoria colectiva de Bogotá. (Homenaje visual)",
	},
	{
		"img": ART_DIR + "pozzetto_slide4.png",
		"title": "4 / 4 · Memoria y literatura",
		"caption": "El archivo periodístico y novelas como 'Satanás' (2002) preservan esta memoria con respeto. (Recreación artística)",
	},
]

# Estado: Secuencia de luces KINDER
const KINDER_COLORS := [
	{"id": 0, "name": "ROSA", "color": Color(1.0, 0.2, 0.78), "dim": Color(0.36, 0.08, 0.28)},
	{"id": 1, "name": "VIOLETA", "color": Color(0.66, 0.28, 1.0), "dim": Color(0.24, 0.1, 0.38)},
	{"id": 2, "name": "AZUL", "color": Color(0.18, 0.56, 1.0), "dim": Color(0.08, 0.2, 0.38)},
	{"id": 3, "name": "CIAN", "color": Color(0.12, 0.96, 0.9), "dim": Color(0.06, 0.32, 0.32)},
]
var _kinder_round := 0
var _kinder_sequence: Array[int] = []
var _kinder_input_index := 0
var _kinder_accepting := false
var _kinder_pads: Array[Button] = []

# Estado: Visor dual (Metro Riviera <-> Theatron)
var _dual_showing_second := false
var _dual_data: Dictionary = {}
var _dual_texture_rect: TextureRect
var _dual_caption_label: Label
var _dual_toggle_button: Button


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_shell()
	hide_activity()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func is_open() -> bool:
	return _is_open


func close() -> void:
	if not _is_open:
		return
	hide_activity()
	activity_closed.emit()


func hide_activity() -> void:
	_is_open = false
	_kinder_accepting = false
	if is_instance_valid(_backdrop):
		_backdrop.hide()
	if is_instance_valid(_panel):
		_panel.hide()


func _build_shell() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.015, 0.01, 0.03, 0.78)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(780, 480)
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_panel_style(Color(0.68, 0.45, 0.98))
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 12)
	margin.add_child(_content_box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_content_box.add_child(header)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_col)

	_badge_label = Label.new()
	_badge_label.add_theme_font_size_override("font_size", 12)
	_badge_label.add_theme_color_override("font_color", Color(0.75, 0.68, 0.95))
	title_col.add_child(_badge_label)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.98, 0.94, 1.0))
	title_col.add_child(_title_label)

	_close_button = Button.new()
	_close_button.text = "Cerrar [ESC]"
	_close_button.custom_minimum_size = Vector2(120, 36)
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	_body_holder = VBoxContainer.new()
	_body_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_holder.add_theme_constant_override("separation", 12)
	_content_box.add_child(_body_holder)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.86, 1.0))
	_content_box.add_child(_status_label)


func _apply_panel_style(accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.024, 0.06, 0.97)
	style.border_color = accent
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0, 0, 0, 0.78)
	style.shadow_size = 14
	_panel.add_theme_stylebox_override("panel", style)


func _prepare_modal(badge: String, title: String, accent: Color, status_text: String) -> void:
	for child in _body_holder.get_children():
		child.queue_free()
	_apply_panel_style(accent)
	_badge_label.text = badge
	_badge_label.add_theme_color_override("font_color", accent.lightened(0.28))
	_title_label.text = title
	_status_label.text = status_text
	_is_open = true
	_backdrop.show()
	_panel.show()


# =============================================================================
# 1. ZONA HIPPIES — PUZZLE CRONOLÓGICO VISUAL (3 ÉPOCAS)
# =============================================================================

func open_hippies_timeline(already_solved: bool) -> void:
	_prepare_modal(
		"PARQUE DE LOS HIPPIES · RECREACIÓN ARTÍSTICA",
		"Tres épocas del parque — Ordena del pasado al presente",
		Color(1.0, 0.56, 0.24),
		"Haz clic en las imágenes en orden cronológico (1° → 2° → 3°)." if not already_solved else "¡Cronología resuelta! De Parque Sucre (1945) al pulso cultural actual."
	)
	_hippies_order.clear()
	_hippies_buttons.clear()

	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 16)
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_holder.add_child(cards_row)

	# Presentación mezclada a propósito (1970, actual, 1945)
	var items := [
		{
			"id": "1970",
			"img": ART_DIR + "hippies_1970.png",
			"hint": "Guitarras, flores y contracultura",
			"year": "Años 70 · Parque de los Hippies",
		},
		{
			"id": "actual",
			"img": ART_DIR + "hippies_actual.png",
			"hint": "Murales urbanos y feria cultural",
			"year": "Hoy · Encuentro cultural",
		},
		{
			"id": "1945",
			"img": ART_DIR + "hippies_1945.png",
			"hint": "Parque Sucre y busto de Julio Flórez",
			"year": "1945 · Parque Antonio J. de Sucre",
		},
	]

	for item in items:
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(226, 260)
		card.add_theme_constant_override("separation", 8)
		cards_row.add_child(card)

		var tex_rect := TextureRect.new()
		tex_rect.texture = load(item["img"]) as Texture2D
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.custom_minimum_size = Vector2(226, 168)
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		card.add_child(tex_rect)

		var caption := Label.new()
		caption.text = item["year"] if already_solved else item["hint"]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_font_size_override("font_size", 14)
		card.add_child(caption)

		var btn := Button.new()
		btn.text = "Verificada ✓" if already_solved else "Seleccionar"
		btn.disabled = already_solved
		btn.custom_minimum_size = Vector2(0, 34)
		var item_id: String = item["id"]
		btn.pressed.connect(_on_hippies_card_pressed.bind(item_id, btn))
		card.add_child(btn)
		_hippies_buttons[item_id] = btn

	var reset_btn := Button.new()
	reset_btn.text = "Reiniciar selección"
	reset_btn.custom_minimum_size = Vector2(180, 32)
	reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset_btn.visible = not already_solved
	reset_btn.pressed.connect(open_hippies_timeline.bind(false))
	_body_holder.add_child(reset_btn)


func _on_hippies_card_pressed(item_id: String, btn: Button) -> void:
	if item_id in _hippies_order:
		return
	_hippies_order.append(item_id)
	btn.text = "Paso #%d" % _hippies_order.size()
	btn.disabled = true

	if _hippies_order.size() < 3:
		_status_label.text = "Elegiste %d / 3. ¿Cuál época sigue?" % _hippies_order.size()
		return

	if _hippies_order == ["1945", "1970", "actual"]:
		_status_label.text = "¡Correcto! 1945 (Parque Sucre y Julio Flórez) → Años 70 (Contracultura) → Hoy."
		activity_completed.emit("hippies_timeline")
		await get_tree().create_timer(1.25).timeout
		if _is_open:
			close()
	else:
		_status_label.text = "Ese orden no coincide. Pista: primero el parque clásico con busto, luego los años 70."
		await get_tree().create_timer(1.1).timeout
		if _is_open:
			open_hippies_timeline(false)


# =============================================================================
# 2. ARCHIVO DE POZZETTO — PROYECTOR DE DIAPOSITIVAS + LÍNEA DEL TIEMPO
# =============================================================================

func open_pozzetto_projector(already_solved: bool) -> void:
	_pozzetto_index = 0
	_pozzetto_seen.clear()
	_pozzetto_timeline_mode = false
	_pozzetto_timeline_order.clear()
	_render_pozzetto_slide(already_solved)


func _render_pozzetto_slide(already_solved: bool) -> void:
	_pozzetto_seen[_pozzetto_index] = true
	var slide: Dictionary = _pozzetto_slides[_pozzetto_index]
	_prepare_modal(
		"ARCHIVO DE POZZETTO · MEMORIA HISTÓRICA DE 1986",
		slide["title"],
		Color(0.86, 0.72, 0.45),
		slide["caption"]
	)

	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.05, 0.04, 0.03, 1.0)
	frame_style.border_color = Color(0.76, 0.62, 0.38, 0.8)
	frame_style.set_border_width_all(3)
	frame_style.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", frame_style)
	_body_holder.add_child(frame)

	var tex_rect := TextureRect.new()
	tex_rect.texture = load(slide["img"]) as Texture2D
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.custom_minimum_size = Vector2(440, 280)
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(tex_rect)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 14)
	_body_holder.add_child(controls)

	var prev_btn := Button.new()
	prev_btn.text = "◀ Diapositiva anterior"
	prev_btn.disabled = (_pozzetto_index == 0)
	prev_btn.pressed.connect(func():
		_pozzetto_index = maxi(0, _pozzetto_index - 1)
		_render_pozzetto_slide(already_solved)
	)
	controls.add_child(prev_btn)

	var next_btn := Button.new()
	next_btn.text = "Siguiente diapositiva ▶"
	next_btn.disabled = (_pozzetto_index >= _pozzetto_slides.size() - 1)
	next_btn.pressed.connect(func():
		_pozzetto_index = mini(_pozzetto_slides.size() - 1, _pozzetto_index + 1)
		_render_pozzetto_slide(already_solved)
	)
	controls.add_child(next_btn)

	if _pozzetto_seen.size() >= _pozzetto_slides.size() or already_solved:
		var timeline_btn := Button.new()
		timeline_btn.text = "Reconstruir línea del tiempo" if not already_solved else "Archivo completado ✓"
		timeline_btn.disabled = already_solved
		timeline_btn.pressed.connect(_open_pozzetto_timeline_step)
		controls.add_child(timeline_btn)


func _open_pozzetto_timeline_step() -> void:
	_pozzetto_timeline_order.clear()
	_prepare_modal(
		"ARCHIVO DE POZZETTO · LÍNEA DEL TIEMPO",
		"Ordena los 3 hitos históricos",
		Color(0.86, 0.72, 0.45),
		"Selecciona los 3 momentos en orden cronológico para encender el farol de la memoria."
	)

	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 12)
	list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_body_holder.add_child(list_box)

	var milestones := [
		{"id": "1986", "label": "4 de diciembre de 1986 · Tragedia en Chapinero (29 víctimas)"},
		{"id": "memoria", "label": "2002 – actualidad · Archivo periodístico, literatura y memoria"},
		{"id": "antes", "label": "Inicios de los años 80 · Tradicional restaurante italiano en la 7ª con 61"},
	]

	for m in milestones:
		var btn := Button.new()
		btn.text = m["label"]
		btn.custom_minimum_size = Vector2(620, 48)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var mid: String = m["id"]
		btn.pressed.connect(_on_pozzetto_milestone_pressed.bind(mid, btn))
		list_box.add_child(btn)


func _on_pozzetto_milestone_pressed(mid: String, btn: Button) -> void:
	if mid in _pozzetto_timeline_order:
		return
	_pozzetto_timeline_order.append(mid)
	btn.text = "[%d]  %s" % [_pozzetto_timeline_order.size(), btn.text]
	btn.disabled = true

	if _pozzetto_timeline_order.size() < 3:
		return

	if _pozzetto_timeline_order == ["antes", "1986", "memoria"]:
		_status_label.text = "Línea del tiempo completada. El farol conmemorativo del archivo se ha encendido."
		activity_completed.emit("pozzetto_archive")
		await get_tree().create_timer(1.25).timeout
		if _is_open:
			close()
	else:
		_status_label.text = "Intenta de nuevo: empieza por el restaurante antes de 1986."
		await get_tree().create_timer(1.1).timeout
		if _is_open:
			_open_pozzetto_timeline_step()


# =============================================================================
# 3. KINDER — SECUENCIA DE LUCES NEÓN (3 RONDAS)
# =============================================================================

func open_kinder_lights(already_solved: bool) -> void:
	_prepare_modal(
		"KINDER · CONSOLA DE LUCES NEÓN",
		"Sincroniza la secuencia de luces",
		Color(1.0, 0.25, 0.84),
		"Observa el destello y repite la secuencia (3 rondas cortas)." if not already_solved else "¡Secuencia sincronizada! Modo Supernova KINDER desbloqueado."
	)
	_kinder_pads.clear()

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_holder.add_child(grid)

	for c in KINDER_COLORS:
		var pad := Button.new()
		pad.text = c["name"]
		pad.custom_minimum_size = Vector2(210, 96)
		pad.add_theme_font_size_override("font_size", 20)
		_style_kinder_pad(pad, c["dim"], c["color"])
		var pad_id: int = c["id"]
		pad.pressed.connect(_on_kinder_pad_pressed.bind(pad_id))
		grid.add_child(pad)
		_kinder_pads.append(pad)

	if already_solved:
		for i in range(_kinder_pads.size()):
			_style_kinder_pad(_kinder_pads[i], KINDER_COLORS[i]["color"], Color.WHITE)
			_kinder_pads[i].disabled = true
		return

	_kinder_round = 1
	_start_kinder_round()


func _style_kinder_pad(pad: Button, bg: Color, border: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(12)
	pad.add_theme_stylebox_override("normal", s)
	pad.add_theme_stylebox_override("hover", s)
	pad.add_theme_stylebox_override("pressed", s)
	pad.add_theme_stylebox_override("disabled", s)


func _start_kinder_round() -> void:
	_kinder_accepting = false
	_kinder_input_index = 0
	var presets := [
		[0, 2, 1],
		[3, 0, 2, 3],
		[1, 3, 0, 2, 1],
	]
	_kinder_sequence.clear()
	for v in presets[_kinder_round - 1]:
		_kinder_sequence.append(int(v))

	_status_label.text = "Ronda %d / 3 · Observa las luces..." % _kinder_round
	await get_tree().create_timer(0.55).timeout
	for step in _kinder_sequence:
		if not _is_open:
			return
		await _flash_kinder_pad(step, 0.36)
		await get_tree().create_timer(0.16).timeout
	if not _is_open:
		return
	_kinder_accepting = true
	_status_label.text = "Ronda %d / 3 · ¡Tu turno! Repite la secuencia." % _kinder_round


func _flash_kinder_pad(pad_id: int, duration: float) -> void:
	if pad_id < 0 or pad_id >= _kinder_pads.size():
		return
	var pad := _kinder_pads[pad_id]
	var info: Dictionary = KINDER_COLORS[pad_id]
	_style_kinder_pad(pad, info["color"], Color.WHITE)
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(pad):
		_style_kinder_pad(pad, info["dim"], info["color"])


func _on_kinder_pad_pressed(pad_id: int) -> void:
	if not _kinder_accepting:
		return
	_flash_kinder_pad(pad_id, 0.22)

	if pad_id != _kinder_sequence[_kinder_input_index]:
		_kinder_accepting = false
		_status_label.text = "¡Casi! Observa de nuevo la ronda %d..." % _kinder_round
		await get_tree().create_timer(0.85).timeout
		if _is_open:
			_start_kinder_round()
		return

	_kinder_input_index += 1
	if _kinder_input_index >= _kinder_sequence.size():
		_kinder_accepting = false
		if _kinder_round >= 3:
			_status_label.text = "¡MODO SUPERNOVA KINDER ACTIVADO! Revisa detrás de los parlantes."
			activity_completed.emit("kinder_lights")
			await get_tree().create_timer(1.25).timeout
			if _is_open:
				close()
		else:
			_kinder_round += 1
			_status_label.text = "¡Bien! Preparando ronda %d / 3..." % _kinder_round
			await get_tree().create_timer(0.7).timeout
			if _is_open:
				_start_kinder_round()


# =============================================================================
# 4. VISOR VISUAL RÁPIDO (ORIGEN CHAPINERO & METRO RIVIERA <-> THEATRON)
# =============================================================================

func open_single_card(badge: String, title: String, image_path: String, caption: String, accent: Color) -> void:
	_prepare_modal(badge, title, accent, caption)
	var tex_rect := TextureRect.new()
	tex_rect.texture = load(image_path) as Texture2D
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.custom_minimum_size = Vector2(460, 300)
	tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body_holder.add_child(tex_rect)


func open_dual_comparison(
	badge: String,
	title: String,
	img_a: String,
	caption_a: String,
	img_b: String,
	caption_b: String,
	accent: Color
) -> void:
	_dual_showing_second = false
	_dual_data = {
		"img_a": img_a,
		"caption_a": caption_a,
		"img_b": img_b,
		"caption_b": caption_b,
	}
	_prepare_modal(badge, title, accent, caption_a)

	_dual_texture_rect = TextureRect.new()
	_dual_texture_rect.texture = load(img_a) as Texture2D
	_dual_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dual_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_dual_texture_rect.custom_minimum_size = Vector2(450, 280)
	_dual_texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_dual_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body_holder.add_child(_dual_texture_rect)

	_dual_toggle_button = Button.new()
	_dual_toggle_button.text = "Transformar a 2002 (Theatron) ⇄"
	_dual_toggle_button.custom_minimum_size = Vector2(300, 38)
	_dual_toggle_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_dual_toggle_button.pressed.connect(_toggle_dual_comparison)
	_body_holder.add_child(_dual_toggle_button)


func _toggle_dual_comparison() -> void:
	_dual_showing_second = not _dual_showing_second
	if _dual_showing_second:
		_dual_texture_rect.texture = load(_dual_data["img_b"]) as Texture2D
		_status_label.text = _dual_data["caption_b"]
		_dual_toggle_button.text = "Volver a los años 70 (Metro Riviera) ⇄"
	else:
		_dual_texture_rect.texture = load(_dual_data["img_a"]) as Texture2D
		_status_label.text = _dual_data["caption_a"]
		_dual_toggle_button.text = "Transformar a 2002 (Theatron) ⇄"
