extends CanvasLayer

signal closed

@onready var root: Control = $Root
@onready var status_label: Label = $Root/Window/Margin/Content/StatusPanel/Status
@onready var cards: VBoxContainer = $Root/Window/Margin/Content/Scroll/Cards
@onready var close_button: Button = $Root/Window/Margin/Content/Header/Close

var _active_puzzle := ""
var _selected: Array[String] = []
var _waiting := false


func _ready() -> void:
	close_button.pressed.connect(close_notebook)
	QuestManager.quest_changed.connect(_on_quest_changed)
	QuestManager.loading_changed.connect(_on_loading_changed)
	QuestManager.notice.connect(_on_notice)
	root.hide()


func is_open() -> bool:
	return root.visible


func open_notebook() -> void:
	if root.visible:
		return
	root.show()
	_rebuild()
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.18)
	close_button.grab_focus()


func show_puzzle(quest_id: String) -> void:
	if not root.visible:
		open_notebook()
	_open_puzzle(quest_id)


func close_notebook() -> void:
	if not root.visible:
		return
	root.hide()
	_active_puzzle = ""
	_selected.clear()
	_waiting = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not root.visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("OpenQuests"):
		get_viewport().set_input_as_handled()
		close_notebook()
	elif event.is_action_pressed("Interact"):
		get_viewport().set_input_as_handled()


func _on_quest_changed(quest_id: String) -> void:
	if _active_puzzle == quest_id:
		var solved := QuestManager.has_step(quest_id, "question" if quest_id == "theatron" else "order")
		if solved:
			_active_puzzle = ""
			_selected.clear()
			_waiting = false
		elif _waiting and not _is_pending_answer(quest_id):
			_waiting = false
			_selected.clear()
	if root.visible:
		_rebuild()


func _is_pending_answer(quest_id: String) -> bool:
	return QuestManager.has_pending_puzzle(quest_id)


func _on_loading_changed(_loading: bool) -> void:
	if root.visible:
		_rebuild()


func _on_notice(message: String) -> void:
	if root.visible:
		status_label.text = message
		if message.contains("Ruta falsa"):
			status_label.add_theme_color_override("font_color", Color(1, 0.45, 0.45, 1))
			var surprise := create_tween()
			surprise.tween_property(status_label, "modulate:a", 0.3, 0.12)
			surprise.tween_property(status_label, "modulate:a", 1.0, 0.16)
		else:
			status_label.add_theme_color_override("font_color", Color(0.98, 0.8, 0.52, 1))


func _rebuild() -> void:
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	if QuestManager.is_loading():
		status_label.text = "Cargando aventuras..."
		return
	if status_label.text == "Cargando aventuras...":
		status_label.text = "Encuentra NPC, pistas y secretos en el mapa."
	if not _active_puzzle.is_empty():
		_build_puzzle(_active_puzzle)
		return
	for quest_id in ["hippies", "politecnico", "theatron", "final"]:
		_build_quest_card(quest_id)


func _build_quest_card(quest_id: String) -> void:
	var definition: Dictionary = QuestManager.QUESTS[quest_id]
	var state := QuestManager.get_quest(quest_id)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.19, 0.13, 0.11, 0.78)
	style.border_color = Color(0.83, 0.57, 0.27, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", style)
	cards.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	column.add_child(_label("%s  ·  %s" % [definition["title"], definition["npc"]], 23, Color(1, 0.86, 0.62, 1)))
	var state_text := "SIN INICIAR" if state.is_empty() else ("COMPLETADA" if str(state.get("status", "")) == "completed" else "EN CURSO")
	column.add_child(_label(state_text, 13, Color(0.47, 0.81, 0.64, 1) if state_text == "COMPLETADA" else Color(0.90, 0.68, 0.37, 1)))
	column.add_child(_label(QuestManager.instruction(quest_id), 22, Color(1, 0.93, 0.83, 1)))
	if state_text == "COMPLETADA" and quest_id != "final":
		column.add_child(_label("Símbolo obtenido: %s · Narrativa desbloqueada" % definition["symbol"], 20, Color(0.72, 0.95, 0.76, 1)))
	if not state.is_empty() and quest_id != "final":
		var found: Array = state.get("collected_items", [])
		column.add_child(_label("Pistas encontradas: %d" % found.size(), 21, Color(0.85, 0.79, 0.7, 1)))
		for item in found:
			column.add_child(_label("• %s" % str(QuestManager.ITEM_CLUES.get(str(item), str(item))), 20, Color(0.90, 0.84, 0.75, 1)))
	if quest_id == "final" and state.is_empty() and QuestManager.can_start_final():
		column.add_child(_button("Comenzar el misterio final", func() -> void: QuestManager.send_event("final", "start")))
	elif not state.is_empty() and str(state.get("status", "")) != "completed" and QuestManager.can_open_puzzle(quest_id):
		column.add_child(_button("Resolver desafío", func() -> void: _open_puzzle(quest_id)))
	elif quest_id == "final" and str(state.get("status", "")) == "completed":
		column.add_child(_label("Insignia: EXPLORADOR DE CHAPINERO\nEn sus calles, el arte guarda memoria; el conocimiento abre caminos y la diversidad crea espacios de encuentro. Chapinero vive en las historias que construimos juntos.", 21, Color(1, 0.9, 0.67, 1)))


func _open_puzzle(quest_id: String) -> void:
	_active_puzzle = quest_id
	_selected.clear()
	_waiting = false
	status_label.text = "Selecciona las tarjetas en el orden correcto."
	_rebuild()


func _build_puzzle(quest_id: String) -> void:
	cards.add_child(_button("← Volver a misiones", func() -> void:
		_active_puzzle = ""
		_selected.clear()
		_rebuild()
	))
	cards.add_child(_label(QuestManager.QUESTS[quest_id]["title"], 25, Color(1, 0.86, 0.62, 1)))
	if quest_id == "theatron":
		var pass_panel := PanelContainer.new()
		var pass_style := StyleBoxFlat.new()
		pass_style.bg_color = Color(0.28, 0.17, 0.34, 0.72)
		pass_style.border_color = Color(0.73, 0.43, 0.92, 1)
		pass_style.set_border_width_all(2)
		pass_style.set_corner_radius_all(9)
		pass_panel.add_theme_stylebox_override("panel", pass_style)
		var pass_text := _label("◈  PASE RECONSTRUIDO  ◈\nSala • pantalla • proyector\nUna función del antiguo cine Metro Riviera", 21, Color(0.94, 0.85, 1, 1))
		pass_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pass_panel.add_child(pass_text)
		cards.add_child(pass_panel)
		if not QuestManager.has_step(quest_id, "gate"):
			cards.add_child(_label("El boleto habla de una pantalla, una sala y un proyector. ¿Qué entrada eliges?", 22, Color(1, 0.94, 0.85, 1)))
			cards.add_child(_button("🎞  Símbolo de la pantalla", func() -> void: _submit_answer("theatron", "choose_gate", "cine")))
			cards.add_child(_button("✦  Símbolo del aula", func() -> void: _submit_answer("theatron", "choose_gate", "aula")))
		else:
			cards.add_child(_label("¿Qué funcionaba antiguamente en el edificio donde hoy está Theatron?", 22, Color(1, 0.94, 0.85, 1)))
			for option in [{"label": "A. Una universidad", "id": "universidad"}, {"label": "B. Un cine", "id": "cine"}, {"label": "C. Una estación de tren", "id": "estacion"}, {"label": "D. Un museo", "id": "museo"}]:
				cards.add_child(_button(option["label"], _submit_answer.bind("theatron", "answer", option["id"])))
		return
	var options: Array = []
	match quest_id:
		"hippies": options = [{"id": "memoria", "label": "MEMORIA"}, {"id": "arte", "label": "ARTE"}, {"id": "calle", "label": "CALLE"}]
		"politecnico": options = [{"id": "1991", "label": "1991 · Institución universitaria"}, {"id": "1980", "label": "1980 · Fundación"}, {"id": "1981", "label": "1981 · Inicio de clases"}]
		"final": options = [{"id": "diversidad", "label": "Diversidad"}, {"id": "arte", "label": "Arte"}, {"id": "conocimiento", "label": "Conocimiento"}]
	cards.add_child(_label("Orden elegido: %s" % (" → ".join(_selected) if not _selected.is_empty() else "toca las tarjetas"), 22, Color(1, 0.92, 0.8, 1)))
	for option in options:
		var button := _button(option["label"], _select_card.bind(quest_id, option["id"]))
		button.disabled = _selected.has(option["id"]) or _waiting
		cards.add_child(button)
	cards.add_child(_button("Reiniciar orden", func() -> void:
		_selected.clear()
		_rebuild()
	))


func _select_card(quest_id: String, card_id: String) -> void:
	if _selected.has(card_id) or _waiting:
		return
	_selected.append(card_id)
	if _selected.size() == 3:
		_waiting = true
		QuestManager.send_event(quest_id, "solve_order", {"answer": _selected.duplicate()})
		status_label.text = "Comprobando el orden..."
	_rebuild()


func _submit_answer(quest_id: String, event_type: String, answer: String) -> void:
	if _waiting:
		return
	_waiting = true
	QuestManager.send_event(quest_id, event_type, {"answer": answer})
	status_label.text = "Comprobando la pista..."
	_rebuild()


func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("line_spacing", 4)
	label.add_theme_color_override("font_color", color)
	return label


func _button(value: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(handler)
	return button
