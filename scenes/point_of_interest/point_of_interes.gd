extends Area2D

signal zone_entered(point_of_interest: Area2D)
signal zone_exited(point_of_interest: Area2D)

@export_category("Cartografía cultural")
@export var place_name := "Punto de interés"
@export var category := "Cultura"
@export_multiline var description := "Aquí aparecerá la información cultural del lugar."
@export var icon: Texture2D
@export var category_color := Color("d99a45")

var player_inside := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or player_inside:
		return
	player_inside = true
	zone_entered.emit(self)


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player") or not player_inside:
		return
	player_inside = false
	zone_exited.emit(self)


func get_poi_data() -> Dictionary:
	return {
		"name": place_name,
		"category": category,
		"description": description,
		"icon": icon,
		"category_color": category_color,
	}
