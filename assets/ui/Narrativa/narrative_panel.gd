extends PanelContainer

@onready var title_label: Label = $MarginContainer/VBoxContainer/Title
@onready var narrative_label: RichTextLabel = $MarginContainer/VBoxContainer/Narrative
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton


func _ready() -> void:
	hide()
	close_button.pressed.connect(_on_close_pressed)


func show_narrative(title: String, narrative: String) -> void:
	title_label.text = title
	narrative_label.text = narrative
	show()


func _on_close_pressed() -> void:
	hide()
