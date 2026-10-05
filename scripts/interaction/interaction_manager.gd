extends Node

signal dialogue_started
signal dialogue_finished

const DIALOGUE_UI_SCENE := preload("res://scenes/ui/dialogue_ui.tscn")
const INTERACT_ACTION := "Interact"
const CONVERSATION_SIDE_DISTANCE := 76.0
const CONVERSATION_CAMERA_OFFSET := Vector2(0.0, 58.0)
const CONVERSATION_ZOOM := Vector2(1.55, 1.55)
const CONVERSATION_ENTER_DURATION := 0.48
const CONVERSATION_EXIT_DURATION := 0.38

var _candidates: Array[Node2D] = []
var _focused_interactable: Node2D
var _nearby_player: CharacterBody2D
var _active_interactable: Node2D
var _dialogue_player: CharacterBody2D
var _dialogue_lines := PackedStringArray()
var _dialogue_index := 0
var _dialogue_active := false
var _dialogue_closing := false
var _dialogue_transitioning := false
var _dialogue_ui
var _player_original_global_position := Vector2.ZERO
var _conversation_camera: Camera2D
var _camera_original_parent: Node
var _camera_original_position := Vector2.ZERO
var _camera_original_global_position := Vector2.ZERO
var _camera_original_zoom := Vector2.ONE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dialogue_ui = DIALOGUE_UI_SCENE.instantiate()
	add_child(_dialogue_ui)
	_dialogue_ui.closed.connect(_on_dialogue_closed)


func _process(_delta: float) -> void:
	_cleanup_candidates()
	if not _dialogue_active:
		_update_focused_interactable()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(INTERACT_ACTION):
		return
	if event is InputEventKey and event.echo:
		return

	get_viewport().set_input_as_handled()
	if _dialogue_active:
		if _dialogue_closing or _dialogue_transitioning:
			return
		if _dialogue_ui.is_revealing_text():
			_dialogue_ui.finish_text_reveal()
		else:
			_advance_dialogue()
		return

	if is_instance_valid(_focused_interactable) and is_instance_valid(_nearby_player):
		_execute_interaction(_focused_interactable, _nearby_player)


func register_interactable(interactable: Node2D, player: CharacterBody2D) -> void:
	if not is_instance_valid(interactable) or not player.is_in_group("player"):
		return
	if interactable not in _candidates:
		_candidates.append(interactable)
	_nearby_player = player
	_update_focused_interactable()


func unregister_interactable(interactable: Node2D) -> void:
	_candidates.erase(interactable)
	if interactable == _focused_interactable and not _dialogue_active:
		_set_focused_interactable(null)
	if _candidates.is_empty() and not _dialogue_active:
		_nearby_player = null
	else:
		_update_focused_interactable()


func is_dialogue_active() -> bool:
	return _dialogue_active


func _cleanup_candidates() -> void:
	for index in range(_candidates.size() - 1, -1, -1):
		if not is_instance_valid(_candidates[index]):
			_candidates.remove_at(index)
	if not is_instance_valid(_nearby_player):
		_nearby_player = null


func _update_focused_interactable() -> void:
	if not is_instance_valid(_nearby_player) or _candidates.is_empty():
		_set_focused_interactable(null)
		return

	var nearest: Node2D
	var nearest_distance := INF
	for candidate in _candidates:
		if not is_instance_valid(candidate):
			continue
		var distance := _nearby_player.global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate

	_set_focused_interactable(nearest)


func _set_focused_interactable(next_interactable: Node2D) -> void:
	if next_interactable == _focused_interactable:
		return
	if is_instance_valid(_focused_interactable) and _focused_interactable.has_method("set_interaction_focus"):
		_focused_interactable.set_interaction_focus(false, _nearby_player)
	_focused_interactable = next_interactable
	if is_instance_valid(_focused_interactable) and _focused_interactable.has_method("set_interaction_focus"):
		_focused_interactable.set_interaction_focus(true, _nearby_player)


func _execute_interaction(interactable: Node2D, player: CharacterBody2D) -> void:
	if not interactable.has_method("interact"):
		push_warning("El nodo %s no implementa interact(player)." % interactable.name)
		return
	interactable.interact(player)


func start_dialogue(interactable: Node2D, player: CharacterBody2D, dialogue_data: Dictionary) -> void:
	if _dialogue_active:
		return
	_dialogue_lines = PackedStringArray(dialogue_data.get("lines", PackedStringArray()))
	if _dialogue_lines.is_empty():
		push_warning("El interactuable %s no tiene dialogos configurados." % interactable.name)
		return

	_dialogue_active = true
	_dialogue_closing = false
	_dialogue_transitioning = true
	_active_interactable = interactable
	_dialogue_player = player
	_dialogue_index = 0
	_set_focused_interactable(null)
	dialogue_started.emit()

	if player.has_method("set_movement_enabled"):
		player.set_movement_enabled(false)
	else:
		push_warning("El jugador no implementa set_movement_enabled().")
	if interactable.has_method("begin_interaction"):
		interactable.begin_interaction(player)

	await _prepare_conversation_view(interactable, player)
	if not is_instance_valid(interactable) or not is_instance_valid(player):
		_reset_dialogue_state()
		return

	_dialogue_ui.open_dialogue(dialogue_data)
	_dialogue_ui.show_line(_dialogue_lines[_dialogue_index], _dialogue_index, _dialogue_lines.size())
	_dialogue_transitioning = false


func _advance_dialogue() -> void:
	_dialogue_index += 1
	if _dialogue_index >= _dialogue_lines.size():
		_finish_dialogue()
		return
	_dialogue_ui.show_line(_dialogue_lines[_dialogue_index], _dialogue_index, _dialogue_lines.size())


func _finish_dialogue() -> void:
	_dialogue_closing = true
	_dialogue_transitioning = true
	_dialogue_ui.close_dialogue()


func _on_dialogue_closed() -> void:
	await _restore_conversation_view()
	if is_instance_valid(_active_interactable) and _active_interactable.has_method("end_interaction"):
		_active_interactable.end_interaction()
	if is_instance_valid(_dialogue_player) and _dialogue_player.has_method("set_movement_enabled"):
		_dialogue_player.set_movement_enabled(true)
	_reset_dialogue_state()
	dialogue_finished.emit()
	_update_focused_interactable()


func _prepare_conversation_view(interactable: Node2D, player: CharacterBody2D) -> void:
	_player_original_global_position = player.global_position
	var side := -1.0 if player.global_position.x <= interactable.global_position.x else 1.0
	var player_target := interactable.global_position + Vector2(side * CONVERSATION_SIDE_DISTANCE, 8.0)

	_conversation_camera = player.get_node_or_null("Camera2D") as Camera2D
	if is_instance_valid(_conversation_camera):
		_camera_original_parent = _conversation_camera.get_parent()
		_camera_original_position = _conversation_camera.position
		_camera_original_global_position = _conversation_camera.global_position
		_camera_original_zoom = _conversation_camera.zoom
		var scene_root := get_tree().current_scene
		if scene_root != null and _conversation_camera.get_parent() != scene_root:
			_conversation_camera.reparent(scene_root, true)

	var transition := create_tween().set_parallel(true)
	transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	transition.tween_property(player, "global_position", player_target, CONVERSATION_ENTER_DURATION)
	if is_instance_valid(_conversation_camera):
		var camera_target := (interactable.global_position + player_target) * 0.5 + CONVERSATION_CAMERA_OFFSET
		transition.tween_property(
			_conversation_camera,
			"global_position",
			camera_target,
			CONVERSATION_ENTER_DURATION,
		)
		transition.tween_property(
			_conversation_camera,
			"zoom",
			CONVERSATION_ZOOM,
			CONVERSATION_ENTER_DURATION,
		)
	await transition.finished

	if is_instance_valid(player) and player.has_method("face_towards"):
		player.face_towards(interactable.global_position)
	if is_instance_valid(interactable) and interactable.has_method("refresh_interaction_facing"):
		interactable.refresh_interaction_facing(player)


func _restore_conversation_view() -> void:
	var transition := create_tween().set_parallel(true)
	transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(_dialogue_player):
		transition.tween_property(
			_dialogue_player,
			"global_position",
			_player_original_global_position,
			CONVERSATION_EXIT_DURATION,
		)
	if is_instance_valid(_conversation_camera):
		transition.tween_property(
			_conversation_camera,
			"global_position",
			_camera_original_global_position,
			CONVERSATION_EXIT_DURATION,
		)
		transition.tween_property(
			_conversation_camera,
			"zoom",
			_camera_original_zoom,
			CONVERSATION_EXIT_DURATION,
		)
	await transition.finished

	if is_instance_valid(_conversation_camera) and is_instance_valid(_camera_original_parent):
		_conversation_camera.reparent(_camera_original_parent, true)
		_conversation_camera.position = _camera_original_position
		_conversation_camera.zoom = _camera_original_zoom


func _reset_dialogue_state() -> void:

	_dialogue_active = false
	_dialogue_closing = false
	_dialogue_transitioning = false
	_active_interactable = null
	_dialogue_player = null
	_dialogue_lines.clear()
	_dialogue_index = 0
	_conversation_camera = null
	_camera_original_parent = null
