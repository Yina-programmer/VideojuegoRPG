extends PanelContainer

signal closed

@onready var title_label: Label = $MarginContainer/VBoxContainer/Header/Title
@onready var category_label: Label = $MarginContainer/VBoxContainer/Category
@onready var narrative_label: RichTextLabel = $MarginContainer/VBoxContainer/Narrative
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton
@onready var close_icon: Button = $MarginContainer/VBoxContainer/Header/CloseIcon

var _transition: Tween
var _closing := false


func _ready() -> void:
	hide()
	set_process_input(false)
	close_button.pressed.connect(_on_close_pressed)
	close_icon.pressed.connect(_on_close_pressed)


func show_narrative(
	title: String,
	narrative: String,
	category: String = "Cultura",
	category_color: Color = Color("d99a45"),
) -> void:
	_kill_transition()
	_closing = false
	title_label.text = title
	category_label.text = category
	category_label.add_theme_color_override("font_color", category_color.lightened(0.18))
	narrative_label.text = narrative
	show()
	set_process_input(true)
	pivot_offset = size * 0.5
	modulate.a = 0.0
	scale = Vector2(0.95, 0.95)
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_transition.tween_property(self, "modulate:a", 1.0, 0.2)
	_transition.tween_property(self, "scale", Vector2.ONE, 0.25)
	close_icon.grab_focus()


func _on_close_pressed() -> void:
	if _closing:
		return
	_closing = true
	set_process_input(false)
	_kill_transition()
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition.tween_property(self, "modulate:a", 0.0, 0.16)
	_transition.tween_property(self, "scale", Vector2(0.97, 0.97), 0.16)
	_transition.chain().tween_callback(_finish_close)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("Interact"):
		get_viewport().set_input_as_handled()


func _finish_close() -> void:
	hide()
	_closing = false
	closed.emit()


func _kill_transition() -> void:
	if is_instance_valid(_transition):
		_transition.kill()
