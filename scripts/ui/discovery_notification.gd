extends CanvasLayer

signal finished

## Asignar desde el Inspector si se incorpora un sonido local apropiado.
@export var discovery_sound: AudioStream

@onready var root: Control = $Root
@onready var card: PanelContainer = $Root/Card
@onready var place_label: Label = $Root/Card/Margin/Content/Place
@onready var progress_bar: ProgressBar = $Root/Card/Margin/Content/Progress
@onready var counter_label: Label = $Root/Card/Margin/Content/Counter
@onready var audio_player: AudioStreamPlayer = $Audio

var _transition: Tween
var _shown_position := Vector2.ZERO
var _sparkles: Array[Label] = []


func _ready() -> void:
	_shown_position = card.position
	root.hide()


func is_showing() -> bool:
	return root.visible


func dismiss() -> void:
	if not root.visible:
		return
	if is_instance_valid(_transition):
		_transition.kill()
	_finish()


func show_discovery(place: Dictionary, discovered: int, total: int) -> void:
	if is_instance_valid(_transition):
		_transition.kill()
	_clear_sparkles()
	var accent: Color = place.get("category_color", Color(0.9, 0.68, 0.34, 1))
	place_label.text = str(place.get("name", "Lugar cultural")).to_upper()
	place_label.add_theme_color_override("font_color", accent.lightened(0.28))
	counter_label.text = "+1 descubrimiento cultural  ·  Progreso: %d / %d" % [discovered, total]
	var card_style := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	card_style.border_color = accent
	card.add_theme_stylebox_override("panel", card_style)
	var fill_style := progress_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	fill_style.bg_color = accent
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	progress_bar.value = 0.0
	root.modulate.a = 0.0
	root.show()
	await get_tree().process_frame
	if not root.visible:
		return
	card.position = _shown_position + Vector2(0, -16)
	card.offset_bottom = card.offset_top + maxf(196.0, card.get_combined_minimum_size().y)
	_make_sparkles(accent)
	if discovery_sound != null:
		audio_player.stream = discovery_sound
		audio_player.play()
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(root, "modulate:a", 1.0, 0.3)
	_transition.tween_property(card, "position", _shown_position, 0.36)
	var target := 100.0 * discovered / total if total > 0 else 0.0
	_transition.tween_property(progress_bar, "value", target, 0.9)
	_transition.chain().tween_interval(3.4)
	_transition.chain().tween_property(root, "modulate:a", 0.0, 0.35)
	_transition.chain().tween_callback(_finish)


func _make_sparkles(accent: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index in 6:
		var sparkle := Label.new()
		sparkle.text = "✦"
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sparkle.add_theme_font_size_override("font_size", 10 + index % 3 * 2)
		sparkle.add_theme_color_override("font_color", accent.lightened(0.25))
		sparkle.position = card.position + Vector2(rng.randf_range(16, card.size.x - 20), rng.randf_range(16, card.size.y - 12))
		sparkle.modulate.a = 0.0
		root.add_child(sparkle)
		_sparkles.append(sparkle)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(sparkle, "modulate:a", 0.75, 0.22).set_delay(index * 0.07)
		tween.tween_property(sparkle, "position:y", sparkle.position.y - rng.randf_range(14, 29), 0.95)
		tween.chain().tween_property(sparkle, "modulate:a", 0.0, 0.4)


func _clear_sparkles() -> void:
	for sparkle in _sparkles:
		if is_instance_valid(sparkle):
			sparkle.queue_free()
	_sparkles.clear()


func _finish() -> void:
	root.hide()
	_clear_sparkles()
	finished.emit()
