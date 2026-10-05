extends CanvasLayer

signal closed

@onready var root: Control = $Root
@onready var shade: ColorRect = $Root/Shade
@onready var dialogue_panel: PanelContainer = $Root/DialoguePanel
@onready var location_label: Label = $Root/DialoguePanel/Margin/Content/Header/LocationPanel/Location
@onready var name_label: Label = $Root/DialoguePanel/Margin/Content/Name
@onready var role_label: Label = $Root/DialoguePanel/Margin/Content/Role
@onready var dialogue_text: RichTextLabel = $Root/DialoguePanel/Margin/Content/DialogueText
@onready var progress_label: Label = $Root/DialoguePanel/Margin/Content/Footer/Progress
@onready var continue_label: Label = $Root/DialoguePanel/Margin/Content/Footer/ContinuePanel/Continue

var _transition_tween: Tween
var _text_tween: Tween
var _hint_tween: Tween


func _ready() -> void:
	root.visible = false
	root.modulate.a = 0.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP


func open_dialogue(data: Dictionary) -> void:
	_kill_tweens()
	name_label.text = str(data.get("name", "PERSONAJE")).to_upper()
	role_label.text = str(data.get("role", ""))
	location_label.text = "%s  •  %s" % [
		str(data.get("category", "Chapinero")),
		str(data.get("location", "Bogota")),
	]

	var accent: Color = data.get("accent", Color("e9b45c"))
	name_label.add_theme_color_override("font_color", accent)
	location_label.add_theme_color_override("font_color", accent.lightened(0.22))
	progress_label.add_theme_color_override("font_color", accent.lightened(0.32))

	root.visible = true
	root.modulate.a = 0.0
	dialogue_panel.scale = Vector2(0.97, 0.97)
	dialogue_panel.pivot_offset = dialogue_panel.size * 0.5
	shade.color.a = 0.0
	_transition_tween = create_tween().set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(root, "modulate:a", 1.0, 0.22)
	_transition_tween.tween_property(shade, "color:a", 0.2, 0.25)
	_transition_tween.tween_property(dialogue_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK)


func show_line(text: String, index: int, total: int) -> void:
	if is_instance_valid(_text_tween):
		_text_tween.kill()
	dialogue_text.text = text
	dialogue_text.visible_ratio = 0.0
	progress_label.text = "%02d / %02d" % [index + 1, total]
	continue_label.text = "E   CERRAR" if index + 1 >= total else "E   CONTINUAR"

	var reveal_duration := clampf(text.length() * 0.012, 0.28, 0.9)
	_text_tween = create_tween()
	_text_tween.tween_property(dialogue_text, "visible_ratio", 1.0, reveal_duration)
	_start_hint_pulse()


func is_revealing_text() -> bool:
	return dialogue_text.visible_ratio < 0.999


func finish_text_reveal() -> void:
	if is_instance_valid(_text_tween):
		_text_tween.kill()
	dialogue_text.visible_ratio = 1.0


func close_dialogue() -> void:
	if is_instance_valid(_text_tween):
		_text_tween.kill()
	if is_instance_valid(_hint_tween):
		_hint_tween.kill()
	if is_instance_valid(_transition_tween):
		_transition_tween.kill()

	_transition_tween = create_tween().set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition_tween.tween_property(root, "modulate:a", 0.0, 0.18)
	_transition_tween.tween_property(shade, "color:a", 0.0, 0.18)
	_transition_tween.tween_property(dialogue_panel, "scale", Vector2(0.98, 0.98), 0.18)
	await _transition_tween.finished
	root.visible = false
	closed.emit()


func _start_hint_pulse() -> void:
	if is_instance_valid(_hint_tween):
		_hint_tween.kill()
	continue_label.modulate.a = 0.72
	_hint_tween = create_tween().set_loops()
	_hint_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hint_tween.tween_property(continue_label, "modulate:a", 1.0, 0.55)
	_hint_tween.tween_property(continue_label, "modulate:a", 0.72, 0.55)


func _kill_tweens() -> void:
	for tween in [_transition_tween, _text_tween, _hint_tween]:
		if is_instance_valid(tween):
			tween.kill()
