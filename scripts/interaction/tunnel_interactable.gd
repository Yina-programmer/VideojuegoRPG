extends Area2D

signal activated(interaction_id: String, title: String, message: String)

@export var interaction_id := ""
@export var title := "Secreto del túnel"
@export_multiline var message := "Los ecos todavía no revelan este secreto."
@export var prompt_text := "Examinar"
@export_range(0, 20, 1) var interaction_priority := 4

@onready var prompt: PanelContainer = $Prompt
@onready var prompt_label: Label = $Prompt/Margin/Label


func _ready() -> void:
	add_to_group("tunnel_interactable")
	prompt.hide()
	prompt_label.text = "[E]  %s" % prompt_text
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	if InteractionManager != null:
		InteractionManager.unregister_interactable(self)


func _on_body_entered(candidate: Node2D) -> void:
	if candidate is CharacterBody2D and candidate.is_in_group("player"):
		InteractionManager.register_interactable(self, candidate)


func _on_body_exited(candidate: Node2D) -> void:
	if candidate.is_in_group("player"):
		InteractionManager.unregister_interactable(self)


func set_interaction_focus(focused: bool, _player: Node2D) -> void:
	prompt.visible = focused


func get_interaction_priority() -> int:
	return interaction_priority


func interact(_player: CharacterBody2D) -> void:
	activated.emit(interaction_id, title, message)