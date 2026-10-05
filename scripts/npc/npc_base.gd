extends CharacterBody2D

@export_category("Identity")
@export var npc_id := "npc"
@export var display_name := "Personaje"
@export var role := "Habitante de Chapinero"
@export var category := "Cultura urbana"
@export var location_name := "Chapinero"
@export var dialogue_lines := PackedStringArray()
@export var accent_color := Color("e6ad55")

@export_category("Appearance")
@export_enum("down", "left", "right", "up") var default_facing := "down"
@export_range(3.0, 12.0, 0.1) var glance_interval := 5.0

@export_category("Patrol")
@export var patrol_offset := Vector2.ZERO
@export var patrol_points := PackedVector2Array()
@export_range(10.0, 200.0, 1.0) var patrol_speed := 90.0
@export_range(1.0, 120.0, 1.0) var patrol_walk_seconds := 30.0
@export_range(1.0, 120.0, 1.0) var patrol_wait_seconds := 30.0
@export_range(1.0, 12.0, 0.5) var patrol_arrival_distance := 3.0

@onready var visual: Node2D = $Visual
@onready var body_sprite: AnimatedSprite2D = $Visual/Body
@onready var shadow: Polygon2D = $Shadow
@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_indicator: Control = $InteractionIndicator
@onready var indicator_panel: PanelContainer = $InteractionIndicator/Panel
@onready var indicator_key_panel: PanelContainer = $InteractionIndicator/Panel/Margin/Content/KeyPanel
@onready var glance_timer: Timer = $GlanceTimer

var _focused := false
var _speaking := false
var _focused_player: Node2D
var _indicator_tween: Tween
var _reaction_tween: Tween
var _breathing_tween: Tween
var _rng := RandomNumberGenerator.new()
var _home_position := Vector2.ZERO
var _patrol_point_index := 0
var _patrol_walk_elapsed := 0.0
var _patrol_wait_remaining := 0.0
var _patrol_waiting := false


func _ready() -> void:
	add_to_group("interactable")
	_validate_configuration()
	_apply_accent_color()
	interaction_indicator.visible = false
	interaction_indicator.modulate.a = 0.0
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	glance_timer.timeout.connect(_on_glance_timeout)
	_rng.seed = hash(npc_id)
	_home_position = position
	_play_front_idle()
	_start_breathing()
	if not _has_patrol():
		_schedule_glance()


func _physics_process(delta: float) -> void:
	if _speaking or not _has_patrol():
		velocity = Vector2.ZERO
		return

	if _patrol_waiting:
		velocity = Vector2.ZERO
		_patrol_wait_remaining -= delta
		if _patrol_wait_remaining <= 0.0:
			_patrol_waiting = false
		return

	_patrol_walk_elapsed += delta
	if _patrol_walk_elapsed >= patrol_walk_seconds:
		_begin_patrol_wait()
		return

	_move_along_patrol()


func _exit_tree() -> void:
	if InteractionManager != null:
		InteractionManager.unregister_interactable(self)


func get_dialogue_data() -> Dictionary:
	return {
		"id": npc_id,
		"name": display_name,
		"role": role,
		"category": category,
		"location": location_name,
		"lines": dialogue_lines,
		"accent": accent_color,
	}


func interact(player: CharacterBody2D) -> void:
	InteractionManager.start_dialogue(self, player, get_dialogue_data())


func set_interaction_focus(has_focus: bool, player: Node2D) -> void:
	if _focused == has_focus:
		return
	_focused = has_focus
	_focused_player = player if has_focus else null
	if has_focus:
		glance_timer.stop()
		_show_indicator()
	else:
		_hide_indicator()
		if not _speaking:
			if _patrol_waiting:
				_play_front_idle()
			elif not _has_patrol():
				_play_idle(StringName(default_facing))
				_schedule_glance()


func begin_interaction(player: Node2D) -> void:
	_speaking = true
	glance_timer.stop()
	_hide_indicator()
	_face_player(player)
	_play_reaction()


func end_interaction() -> void:
	_speaking = false
	_focused_player = null
	if _patrol_waiting:
		_play_front_idle()
	elif not _has_patrol():
		_play_idle(StringName(default_facing))
		_schedule_glance()


func refresh_interaction_facing(player: Node2D) -> void:
	_face_player(player)


func _validate_configuration() -> void:
	if npc_id.strip_edges().is_empty():
		push_warning("NPC sin npc_id: %s" % name)
	if body_sprite.sprite_frames == null:
		push_warning("NPC sin recurso SpriteFrames en Visual/Body: %s" % name)
	else:
		for animation: StringName in [&"idle_down", &"idle_left", &"idle_right", &"idle_up", &"walk_down", &"walk_left", &"walk_right", &"walk_up"]:
			if not body_sprite.sprite_frames.has_animation(animation):
				push_warning("NPC sin animacion %s: %s" % [animation, name])
	if dialogue_lines.is_empty():
		push_warning("NPC sin dialogos: %s" % name)


func _apply_accent_color() -> void:
	var panel_style := indicator_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	panel_style.border_color = accent_color
	indicator_panel.add_theme_stylebox_override("panel", panel_style)

	var key_style := indicator_key_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	key_style.bg_color = accent_color
	key_style.border_color = accent_color.lightened(0.28)
	indicator_key_panel.add_theme_stylebox_override("panel", key_style)


func _on_body_entered(candidate: Node2D) -> void:
	if not candidate.is_in_group("player") or not (candidate is CharacterBody2D):
		return
	InteractionManager.register_interactable(self, candidate as CharacterBody2D)


func _on_body_exited(candidate: Node2D) -> void:
	if not candidate.is_in_group("player"):
		return
	InteractionManager.unregister_interactable(self)


func _show_indicator() -> void:
	if is_instance_valid(_indicator_tween):
		_indicator_tween.kill()
	interaction_indicator.visible = true
	interaction_indicator.modulate.a = 0.0
	interaction_indicator.scale = Vector2(0.86, 0.86)
	interaction_indicator.pivot_offset = interaction_indicator.size * 0.5
	_indicator_tween = create_tween().set_parallel(true)
	_indicator_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_indicator_tween.tween_property(interaction_indicator, "modulate:a", 1.0, 0.18)
	_indicator_tween.tween_property(interaction_indicator, "scale", Vector2.ONE, 0.24)


func _hide_indicator() -> void:
	if not interaction_indicator.visible:
		return
	if is_instance_valid(_indicator_tween):
		_indicator_tween.kill()
	_indicator_tween = create_tween().set_parallel(true)
	_indicator_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_indicator_tween.tween_property(interaction_indicator, "modulate:a", 0.0, 0.12)
	_indicator_tween.tween_property(interaction_indicator, "scale", Vector2(0.92, 0.92), 0.12)
	_indicator_tween.chain().tween_callback(func() -> void: interaction_indicator.visible = false)


func _face_player(player: Node2D) -> void:
	if not is_instance_valid(player):
		return
	var offset := player.global_position - global_position
	var direction := &"down"
	if absf(offset.x) > absf(offset.y):
		direction = &"right" if offset.x > 0.0 else &"left"
	else:
		direction = &"down" if offset.y > 0.0 else &"up"
	_play_idle(direction)


func _play_idle(direction: StringName) -> void:
	var animation := StringName("idle_%s" % direction)
	if body_sprite.sprite_frames != null and body_sprite.sprite_frames.has_animation(animation):
		body_sprite.play(animation)


func _play_front_idle() -> void:
	_play_idle(&"down")


func _play_walk(direction: StringName) -> void:
	var animation := StringName("walk_%s" % direction)
	if body_sprite.sprite_frames != null and body_sprite.sprite_frames.has_animation(animation):
		if body_sprite.animation != animation or not body_sprite.is_playing():
			body_sprite.play(animation)


func _move_along_patrol() -> void:
	var route := _get_patrol_route()
	var target := _home_position + route[_patrol_point_index]
	var offset := target - position
	if offset.length() <= patrol_arrival_distance:
		position = target
		_patrol_point_index = (_patrol_point_index + 1) % route.size()
		target = _home_position + route[_patrol_point_index]
		offset = target - position

	var direction := offset.normalized()
	velocity = direction * patrol_speed
	_play_walk(_direction_from_vector(direction))
	move_and_slide()


func _begin_patrol_wait() -> void:
	velocity = Vector2.ZERO
	_patrol_waiting = true
	_patrol_wait_remaining = patrol_wait_seconds
	_patrol_walk_elapsed = 0.0
	_play_front_idle()


func _has_patrol() -> bool:
	return not patrol_points.is_empty() or not patrol_offset.is_zero_approx()


func _get_patrol_route() -> PackedVector2Array:
	if not patrol_points.is_empty():
		return patrol_points
	return PackedVector2Array([patrol_offset, Vector2.ZERO])


func _direction_from_vector(direction: Vector2) -> StringName:
	if absf(direction.x) > absf(direction.y):
		return &"right" if direction.x > 0.0 else &"left"
	return &"down" if direction.y > 0.0 else &"up"


func _start_breathing() -> void:
	if is_instance_valid(_breathing_tween):
		_breathing_tween.kill()
	visual.position = Vector2.ZERO
	shadow.modulate.a = 0.42
	_breathing_tween = create_tween().set_loops().set_parallel(true)
	_breathing_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathing_tween.tween_property(visual, "position:y", -1.2, 1.35)
	_breathing_tween.tween_property(shadow, "modulate:a", 0.31, 1.35)
	_breathing_tween.chain().set_parallel(true)
	_breathing_tween.tween_property(visual, "position:y", 0.0, 1.35)
	_breathing_tween.tween_property(shadow, "modulate:a", 0.42, 1.35)


func _play_reaction() -> void:
	if is_instance_valid(_reaction_tween):
		_reaction_tween.kill()
	visual.scale = Vector2.ONE
	_reaction_tween = create_tween()
	_reaction_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reaction_tween.tween_property(visual, "scale", Vector2(1.035, 1.035), 0.12)
	_reaction_tween.tween_property(visual, "scale", Vector2.ONE, 0.16)


func _schedule_glance() -> void:
	if (
		_focused
		or _speaking
		or _has_patrol()
		or not is_inside_tree()
		or not glance_timer.is_inside_tree()
	):
		return
	glance_timer.wait_time = glance_interval + _rng.randf_range(-0.65, 0.85)
	glance_timer.start()


func _on_glance_timeout() -> void:
	if _focused or _speaking:
		return
	var glance_directions: Array[StringName] = [&"left", &"right", StringName(default_facing)]
	_play_idle(glance_directions[_rng.randi_range(0, glance_directions.size() - 1)])
	await get_tree().create_timer(0.65).timeout
	if not _focused and not _speaking:
		_play_idle(StringName(default_facing))
		_schedule_glance()
