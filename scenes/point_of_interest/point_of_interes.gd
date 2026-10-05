extends Area2D

signal narrative_requested(title: String, narrative: String)

@export var title: String = "Punto de interés"
@export_multiline var narrative: String = "Aquí aparecerá la información del lugar."

var player_inside := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false


func _unhandled_input(event: InputEvent) -> void:
	if player_inside and event.is_action_pressed("Interact"):
		narrative_requested.emit(title, narrative)
		get_viewport().set_input_as_handled()
