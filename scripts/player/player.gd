extends CharacterBody2D

signal personalizacion_cambiada(outfit_name: String, hair_name: String)

const CUSTOMIZATION_PATH = "user://player_customization.cfg"

@onready var body: AnimatedSprite2D = $visual/body
@onready var visual: Node2D = $visual
@onready var hair_styles = {
	"castano": $visual/hair_castano,
	"flor_verde": $visual/hair_flor_verde,
	"trenzas_rojas": $visual/hair_trenzas_rojas,
	"rojo_medio": $visual/hair_rojo_medio,
	"negro_liso": $visual/hair_negro_liso
}

var speed = 400.0
var lastDirection = "down"

var outfits = {
	"original": preload("res://assets/player/outfits/outfit_original_frames.tres"),
	"rosa": preload("res://assets/player/outfits/outfit_rosa_frames.tres"),
	"azul": preload("res://assets/player/outfits/outfit_azul_frames.tres"),
	"negro": preload("res://assets/player/outfits/outfit_negro_frames.tres"),
	"blanco_mono": preload("res://assets/player/outfits/outfit_blanco_mono_frames.tres"),
	"negro_mono": preload("res://assets/player/outfits/outfit_negro_mono_frames.tres")
}

var outfit_actual: String = "original"
var cabello_actual: String = "castano"


func _ready() -> void:
	cargar_personalizacion()


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
	var animation_name = state + "_" + lastDirection
	body.play(animation_name)


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
		push_warning("No existe el outfit: " + nombre)
		return

	body.sprite_frames = outfits[nombre]
	outfit_actual = nombre
	body.play("walk_" + lastDirection)
	personalizacion_cambiada.emit(outfit_actual, cabello_actual)


func cambiar_cabello(nombre: String) -> void:
	if not hair_styles.has(nombre):
		push_warning("No existe el cabello: " + nombre)
		return

	cabello_actual = nombre
	actualizar_cabello_visual()
	personalizacion_cambiada.emit(outfit_actual, cabello_actual)


func guardar_personalizacion() -> Error:
	var config = ConfigFile.new()
	config.set_value("character", "type", "mujer")
	config.set_value("character", "outfit", outfit_actual)
	config.set_value("character", "hair", cabello_actual)
	return config.save(CUSTOMIZATION_PATH)


func cargar_personalizacion() -> void:
	var config = ConfigFile.new()
	if config.load(CUSTOMIZATION_PATH) != OK:
		return

	var saved_outfit = str(config.get_value("character", "outfit", outfit_actual))
	var saved_hair = str(config.get_value("character", "hair", cabello_actual))
	if outfits.has(saved_outfit):
		cambiar_outfit(saved_outfit)
	if hair_styles.has(saved_hair):
		cambiar_cabello(saved_hair)


func _unhandled_key_input(event) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_KP_1:
				cambiar_outfit("original")
			KEY_2, KEY_KP_2:
				cambiar_outfit("rosa")
			KEY_3, KEY_KP_3:
				cambiar_outfit("azul")
			KEY_4, KEY_KP_4:
				cambiar_outfit("negro")
			KEY_5, KEY_KP_5:
				cambiar_outfit("blanco_mono")
			KEY_6, KEY_KP_6:
				cambiar_outfit("negro_mono")
