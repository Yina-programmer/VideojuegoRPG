extends Control

@onready var preview_player = $ClosetPanel/CharacterPanel/player

@onready var original_button = $ClosetPanel/OutfitsPanel/OutfitsGrid/OriginalButton
@onready var pink_button = $ClosetPanel/OutfitsPanel/OutfitsGrid/PinkButton
@onready var blue_button = $ClosetPanel/OutfitsPanel/OutfitsGrid/BlueButton
@onready var black_button = $ClosetPanel/OutfitsPanel/OutfitsGrid/BlackButton
@onready var white_bow_button = $ClosetPanel/OutfitsPanel/OutfitsGrid/WhiteBowButton
@onready var black_bow_button = $ClosetPanel/OutfitsPanel/OutfitsGrid/BlackBowButton


func _ready():
	# El personaje de la izquierda es solo una vista previa.
	preview_player.set_physics_process(false)
	preview_player.set_process_input(false)

	original_button.pressed.connect(_on_original_pressed)
	pink_button.pressed.connect(_on_pink_pressed)
	blue_button.pressed.connect(_on_blue_pressed)
	black_button.pressed.connect(_on_black_pressed)
	white_bow_button.pressed.connect(_on_white_bow_pressed)
	black_bow_button.pressed.connect(_on_black_bow_pressed)

	cambiar_preview("original")


func cambiar_preview(outfit_name: String):
	preview_player.cambiar_outfit(outfit_name)
	preview_player.lastDirection = "down"
	preview_player.body.animation = "walk_down"
	preview_player.body.frame = 0
	preview_player.body.stop()


func _on_original_pressed():
	cambiar_preview("original")


func _on_pink_pressed():
	cambiar_preview("rosa")


func _on_blue_pressed():
	cambiar_preview("azul")


func _on_black_pressed():
	cambiar_preview("negro")


func _on_white_bow_pressed():
	cambiar_preview("blanco_mono")


func _on_black_bow_pressed():
	cambiar_preview("negro_mono")
