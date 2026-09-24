extends CharacterBody2D

signal personalizacion_cambiada(outfit_name: String, hair_name: String)

const CUSTOMIZATION_PATH = "user://player_customization.cfg"

@onready var body: AnimatedSprite2D = $visual/body
@onready var visual: Node2D = $visual
@onready var hair_styles = {
	"hair_male_black": $visual/hair_male_black,
	"hair_male_brown": $visual/hair_male_brown,
	"hair_male_silver": $visual/hair_male_silver,
	"hair_male_blonde": $visual/hair_male_blonde
}

var speed = 400.0
var lastDirection = "down"

var outfits = {
	"general": preload("res://assets/player_male/outfits/outfit_male_general_frames.tres"),
	"blue": preload("res://assets/player_male/outfits/outfit_male_blue_frames.tres"),
	"beige": preload("res://assets/player_male/outfits/outfit_male_beige_frames.tres"),
	"black": preload("res://assets/player_male/outfits/outfit_male_black_frames.tres"),
	"olive": preload("res://assets/player_male/outfits/outfit_male_olive_frames.tres"),
	"formal": preload("res://assets/player_male/outfits/outfit_male_formal_frames.tres"),
	"shirtless": preload("res://assets/player_male/outfits/outfit_male_shirtless_frames.tres")
}

var outfit_actual: String = "general"
var cabello_actual: String = "hair_male_black"


func _ready() -> void:
	cambiar_outfit(outfit_actual)
	cargar_personalizacion()
	actualizar_cabello_visual()


func _process(_delta) -> void:
	actualizar_cabello_visual()


func _physics_process(_delta) -> void:
	getInput()
	move_and_slide()


func getInput() -> void:
	var inputDirection = Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown")
	if inputDirection == Vector2.ZERO:
		velocity = Vector2.ZERO
		updateAnimation("walk")
		return

	if abs(inputDirection.x) > abs(inputDirection.y):
		lastDirection = "right" if inputDirection.x > 0 else "left"
	else:
		lastDirection = "down" if inputDirection.y > 0 else "up"

	velocity = speed * inputDirection
	updateAnimation("walk")


func updateAnimation(state: String) -> void:
	body.play(state + "_" + lastDirection)


func actualizar_cabello_visual() -> void:
	for hair_style in hair_styles.values():
		hair_style.visible = false

	var selected_style: Node2D = hair_styles.get(cabello_actual)
	if selected_style == null:
		return

	selected_style.visible = true
	for hair_sprite in selected_style.get_children():
		if hair_sprite is AnimatedSprite2D:
			hair_sprite.visible = false

	var direction := "down"
	match body.animation:
		"walk_left":
			direction = "left"
		"walk_right":
			direction = "right"
		"walk_up":
			direction = "up"

	var active_hair: AnimatedSprite2D = selected_style.get_node("hair_" + direction)
	active_hair.animation = body.animation
	active_hair.frame = body.frame
	active_hair.frame_progress = body.frame_progress
	active_hair.visible = true


func cambiar_outfit(nombre: String) -> void:
	if not outfits.has(nombre):
		push_warning("No existe el outfit masculino: " + nombre)
		return

	body.sprite_frames = outfits[nombre]
	outfit_actual = nombre
	body.play("walk_" + lastDirection)
	personalizacion_cambiada.emit(outfit_actual, cabello_actual)


func cambiar_cabello(nombre: String) -> void:
	if not hair_styles.has(nombre):
		push_warning("No existe el cabello masculino: " + nombre)
		return

	cabello_actual = nombre
	actualizar_cabello_visual()
	personalizacion_cambiada.emit(outfit_actual, cabello_actual)


func guardar_personalizacion() -> Error:
	var config = ConfigFile.new()
	config.set_value("character", "type", "hombre")
	config.set_value("character", "outfit", outfit_actual)
	config.set_value("character", "hair", cabello_actual)
	return config.save(CUSTOMIZATION_PATH)


func cargar_personalizacion() -> void:
	var config = ConfigFile.new()
	if config.load(CUSTOMIZATION_PATH) != OK:
		return
	if str(config.get_value("character", "type", "mujer")) != "hombre":
		return

	var saved_outfit = str(config.get_value("character", "outfit", outfit_actual))
	var saved_hair = str(config.get_value("character", "hair", cabello_actual))
	if outfits.has(saved_outfit):
		cambiar_outfit(saved_outfit)
	if hair_styles.has(saved_hair):
		cambiar_cabello(saved_hair)


func _unhandled_key_input(event) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var outfit_keys = outfits.keys()
		var number: int = int(event.physical_keycode) - int(KEY_1)
		if number >= 0 and number < outfit_keys.size():
			cambiar_outfit(outfit_keys[number])
