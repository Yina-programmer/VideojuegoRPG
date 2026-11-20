extends Area2D

signal enter_requested
signal focus_changed(focused: bool)

@export_range(0, 30, 1) var interaction_priority := 20

@onready var prompt: PanelContainer = $Prompt
@onready var light: PointLight2D = $Visual/Light
@onready var outer_ring: Line2D = $Visual/OuterRing
@onready var inner_ring: Line2D = $Visual/InnerRing
@onready var symbols: Node2D = $Visual/Symbols
@onready var surface_spawn: Marker2D = $SurfaceSpawn

var _unlocked := false
var _elapsed := 0.0
var _focused := false


func _ready() -> void:
	add_to_group("tunnel_access")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_unlocked(false)


func _exit_tree() -> void:
	InteractionManager.unregister_interactable(self)


func _process(delta: float) -> void:
	if not _unlocked:
		return
	_elapsed += delta
	var pulse := (sin(_elapsed * 2.4) + 1.0) * 0.5
	light.energy = lerpf(0.72, 1.05, pulse)
	outer_ring.modulate.a = lerpf(0.72, 1.0, pulse)
	inner_ring.modulate.a = lerpf(0.58, 0.9, 1.0 - pulse)
	symbols.position.y = sin(_elapsed * 1.8) * 2.0


func set_unlocked(value: bool) -> void:
	_unlocked = value
	visible = value
	set_process(value)
	set_deferred("monitoring", value)
	if not value:
		set_interaction_focus(false, null)
		InteractionManager.unregister_interactable(self)
	else:
		call_deferred("_register_overlapping_player")


func is_unlocked() -> bool:
	return _unlocked


func get_surface_spawn_position() -> Vector2:
	return surface_spawn.global_position


func _register_overlapping_player() -> void:
	if not _unlocked:
		return
	for candidate in get_overlapping_bodies():
		_on_body_entered(candidate)


func _on_body_entered(candidate: Node2D) -> void:
	if _unlocked and candidate is CharacterBody2D and candidate.is_in_group("player"):
		InteractionManager.register_interactable(self, candidate)


func _on_body_exited(candidate: Node2D) -> void:
	if candidate.is_in_group("player"):
		InteractionManager.unregister_interactable(self)


func set_interaction_focus(focused: bool, _player: Node2D) -> void:
	var next_focus := focused and _unlocked
	prompt.visible = next_focus
	if _focused != next_focus:
		_focused = next_focus
		focus_changed.emit(_focused)


func get_interaction_priority() -> int:
	return interaction_priority


func interact(_player: CharacterBody2D) -> void:
	if _unlocked:
		enter_requested.emit()
