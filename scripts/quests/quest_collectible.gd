extends Area2D

@export var item_id := ""
@export var quest_id := ""
@export var item_name := "Pista"
@export_multiline var description := ""
@export_multiline var hint := ""
@export var required_step := ""
@export_enum("Cartel", "Documento", "Boleto") var appearance := "Cartel"
@export var paper_color := Color(0.97, 0.84, 0.59, 1)

@onready var prompt: PanelContainer = $Prompt


func _ready() -> void:
	add_to_group("quest_collectible")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	QuestManager.quest_changed.connect(_on_quest_changed)
	QuestManager.loading_changed.connect(_on_loading_changed)
	_refresh()


func _exit_tree() -> void:
	InteractionManager.unregister_interactable(self)


func _draw() -> void:
	var color := paper_color
	draw_rect(Rect2(-18, -11, 36, 25), Color(0.10, 0.07, 0.06, 0.56))
	draw_rect(Rect2(-16, -14, 32, 24), color)
	draw_rect(Rect2(-16, -14, 32, 24), Color(0.30, 0.18, 0.11, 1), false, 2.0)
	if appearance == "Boleto":
		draw_rect(Rect2(-11, -8, 21, 3), Color(0.35, 0.20, 0.18, 1))
		draw_rect(Rect2(-11, -2, 21, 2), Color(0.35, 0.20, 0.18, 1))
	else:
		draw_rect(Rect2(-10, -7, 20, 2), Color(0.37, 0.25, 0.16, 1))
		draw_rect(Rect2(-10, -2, 15, 2), Color(0.37, 0.25, 0.16, 1))
		draw_rect(Rect2(-10, 3, 18, 2), Color(0.37, 0.25, 0.16, 1))
	if appearance == "Documento":
		draw_rect(Rect2(8, -12, 6, 5), Color(0.48, 0.27, 0.12, 1))


func _refresh() -> void:
	var active := not QuestManager.is_loading() and not QuestManager.get_quest(quest_id).is_empty()
	if not required_step.is_empty():
		active = active and QuestManager.has_step(quest_id, required_step)
	active = active and not QuestManager.is_collected(quest_id, item_id)
	visible = active
	monitoring = active
	if not active:
		prompt.hide()
		InteractionManager.unregister_interactable(self)
	else:
		call_deferred("_register_overlapping")


func _register_overlapping() -> void:
	if not visible:
		return
	await get_tree().physics_frame
	for candidate in get_overlapping_bodies():
		_on_body_entered(candidate)


func _on_quest_changed(changed_id: String) -> void:
	if changed_id == quest_id:
		_refresh()


func _on_loading_changed(_loading: bool) -> void:
	_refresh()


func _on_body_entered(candidate: Node2D) -> void:
	if visible and candidate is CharacterBody2D and candidate.is_in_group("player"):
		InteractionManager.register_interactable(self, candidate)


func _on_body_exited(candidate: Node2D) -> void:
	if candidate.is_in_group("player"):
		InteractionManager.unregister_interactable(self)


func set_interaction_focus(focused: bool, _player: Node2D) -> void:
	prompt.visible = focused and visible


func get_interaction_priority() -> int:
	return 10


func interact(_player: CharacterBody2D) -> void:
	if not visible:
		return
	QuestManager.send_event(quest_id, "collect", {"item_id": item_id})
	QuestManager.notice.emit("%s: %s" % [item_name, description])
	if not hint.is_empty():
		QuestManager.notice.emit(hint)
