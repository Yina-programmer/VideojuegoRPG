extends CanvasLayer

signal poi_selected(point_of_interest: Area2D)

@onready var card: PanelContainer = $Root/Card
@onready var location_glyph: Label = $Root/Card/Margin/Content/Header/LocationGlyph
@onready var custom_icon: TextureRect = $Root/Card/Margin/Content/Header/CustomIcon
@onready var place_label: Label = $Root/Card/Margin/Content/Header/PlaceInfo/PlaceName
@onready var category_label: Label = $Root/Card/Margin/Content/Header/PlaceInfo/Category
@onready var discover_button: Button = $Root/Card/Margin/Content/DiscoverButton

var _current_poi: Area2D
var _suspended := false
var _transition: Tween
var _shown_position := Vector2.ZERO


func _ready() -> void:
	_shown_position = card.position
	card.visible = false
	card.modulate.a = 0.0
	discover_button.pressed.connect(_on_discover_pressed)


func show_poi(point_of_interest: Area2D) -> void:
	if not is_instance_valid(point_of_interest) or not point_of_interest.has_method("get_poi_data"):
		return
	_current_poi = point_of_interest
	_apply_data(point_of_interest.get_poi_data())
	if not _suspended:
		_animate_in()


func clear_poi(point_of_interest: Area2D = null) -> void:
	if point_of_interest != null and point_of_interest != _current_poi:
		return
	_current_poi = null
	_animate_out()


func set_suspended(suspended: bool) -> void:
	_suspended = suspended
	if _suspended:
		_animate_out()
	elif is_instance_valid(_current_poi):
		_animate_in()


func get_current_poi() -> Area2D:
	return _current_poi


func _apply_data(data: Dictionary) -> void:
	place_label.text = str(data.get("name", "Lugar cultural")).to_upper()
	category_label.text = str(data.get("category", "Cultura"))
	var poi_icon := data.get("icon") as Texture2D
	custom_icon.texture = poi_icon
	custom_icon.visible = poi_icon != null
	location_glyph.visible = poi_icon == null
	_apply_category_color(data.get("category_color", Color("d99a45")) as Color)


func _apply_category_color(color: Color) -> void:
	category_label.add_theme_color_override("font_color", color.lightened(0.18))
	var card_style := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	card_style.border_color = color
	card.add_theme_stylebox_override("panel", card_style)
	var normal := discover_button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	normal.bg_color = color.darkened(0.12)
	normal.border_color = color.lightened(0.22)
	discover_button.add_theme_stylebox_override("normal", normal)
	var hover := discover_button.get_theme_stylebox("hover").duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.08)
	hover.border_color = color.lightened(0.34)
	discover_button.add_theme_stylebox_override("hover", hover)
	var pressed := discover_button.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.24)
	discover_button.add_theme_stylebox_override("pressed", pressed)


func _animate_in() -> void:
	if not is_instance_valid(_current_poi):
		return
	_kill_transition()
	card.visible = true
	card.position = _shown_position + Vector2(-22.0, 0.0)
	card.modulate.a = 0.0
	card.scale = Vector2(0.96, 0.96)
	card.pivot_offset = card.size * 0.5
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition.tween_property(card, "position", _shown_position, 0.24)
	_transition.tween_property(card, "modulate:a", 1.0, 0.2)
	_transition.tween_property(card, "scale", Vector2.ONE, 0.24)


func _animate_out() -> void:
	if not card.visible:
		return
	_kill_transition()
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition.tween_property(card, "position", _shown_position + Vector2(-18.0, 0.0), 0.16)
	_transition.tween_property(card, "modulate:a", 0.0, 0.14)
	_transition.tween_property(card, "scale", Vector2(0.97, 0.97), 0.16)
	_transition.chain().tween_callback(func() -> void: card.visible = false)


func _kill_transition() -> void:
	if is_instance_valid(_transition):
		_transition.kill()


func _on_discover_pressed() -> void:
	if is_instance_valid(_current_poi) and not _suspended:
		poi_selected.emit(_current_poi)
