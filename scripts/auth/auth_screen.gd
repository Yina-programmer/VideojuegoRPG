extends Control

const MAP_SCENE := "res://scenes/map/Mapa_Chapinero.tscn"
const CUSTOMIZATION_PATH := "user://player_customization.cfg"

@onready var welcome_panel: VBoxContainer = %WelcomePanel
@onready var login_form: VBoxContainer = %LoginForm
@onready var register_form: VBoxContainer = %RegisterForm
@onready var status_label: Label = %StatusLabel
@onready var loading_label: Label = %LoadingLabel
@onready var login_value: LineEdit = %LoginValue
@onready var login_password: LineEdit = %LoginPassword
@onready var register_username: LineEdit = %RegisterUsername
@onready var register_email: LineEdit = %RegisterEmail
@onready var register_password: LineEdit = %RegisterPassword
@onready var register_confirmation: LineEdit = %RegisterConfirmation
@onready var login_button: Button = %LoginButton
@onready var register_button: Button = %RegisterButton
@onready var female_character: CharacterBody2D = %FemaleCharacter
@onready var male_character: CharacterBody2D = %MaleCharacter

var _preparing_game := false
var _base_female_position := Vector2.ZERO
var _base_male_position := Vector2.ZERO
var _animation_time := 0.0


func _ready() -> void:
	AuthManager.authentication_succeeded.connect(_on_authentication_succeeded)
	AuthManager.authentication_failed.connect(_on_authentication_failed)
	AuthManager.busy_changed.connect(_on_busy_changed)
	ApiService.customization_loaded.connect(_on_customization_loaded)
	ApiService.customization_load_failed.connect(_on_customization_load_failed)
	get_viewport().size_changed.connect(_position_characters)
	_configure_characters()
	_connect_controls()
	_show_welcome()
	_position_characters()


func _process(delta: float) -> void:
	_animation_time += delta
	if female_character != null:
		female_character.position = _base_female_position + Vector2(0, sin(_animation_time * 1.5) * 4.0)
	if male_character != null:
		male_character.position = _base_male_position + Vector2(0, sin(_animation_time * 1.5 + 1.4) * 4.0)
	loading_label.modulate.a = 0.7 + 0.3 * sin(_animation_time * 3.0) if loading_label.visible else 1.0


func _connect_controls() -> void:
	%WelcomeLogin.pressed.connect(_show_login)
	%WelcomeRegister.pressed.connect(_show_register)
	%LoginBack.pressed.connect(_show_welcome)
	%RegisterBack.pressed.connect(_show_welcome)
	%GoRegister.pressed.connect(_show_register)
	%GoLogin.pressed.connect(_show_login)
	%ShowLoginPassword.toggled.connect(func(pressed: bool) -> void: login_password.secret = not pressed)
	%ShowRegisterPassword.toggled.connect(func(pressed: bool) -> void:
		register_password.secret = not pressed
		register_confirmation.secret = not pressed
	)
	login_button.pressed.connect(_submit_login)
	register_button.pressed.connect(_submit_register)
	login_password.text_submitted.connect(func(_value: String) -> void: _submit_login())
	register_confirmation.text_submitted.connect(func(_value: String) -> void: _submit_register())
	login_value.text_submitted.connect(func(_value: String) -> void: login_password.grab_focus())
	register_username.text_submitted.connect(func(_value: String) -> void: register_email.grab_focus())
	register_email.text_submitted.connect(func(_value: String) -> void: register_password.grab_focus())
	register_password.text_submitted.connect(func(_value: String) -> void: register_confirmation.grab_focus())


func _configure_characters() -> void:
	female_character.set_movement_enabled(false)
	female_character.cambiar_outfit("azul")
	female_character.cambiar_cabello("castano")
	female_character.body.play("walk_down")
	female_character.body.pause()
	female_character.body.frame = 1
	male_character.set_movement_enabled(false)
	male_character.cambiar_outfit("formal")
	male_character.cambiar_cabello("hair_male_silver")
	male_character.body.play("walk_down")
	male_character.body.pause()
	male_character.body.frame = 1


func _position_characters() -> void:
	var size := get_viewport_rect().size
	var ui_scale := clampf(minf(size.x / 1152.0, size.y / 648.0), 0.72, 1.0)
	var content_center := $ContentCenter as Control
	content_center.pivot_offset = content_center.size * 0.5
	content_center.scale = Vector2.ONE * ui_scale
	var spacing := clampf(size.x * 0.39, 390.0, 540.0)
	var character_y := size.y * 0.82
	_base_female_position = Vector2(size.x * 0.5 - spacing, character_y)
	_base_male_position = Vector2(size.x * 0.5 + spacing, character_y)
	female_character.scale = Vector2.ONE * (0.72 if size.x >= 1100 else 0.58) * ui_scale
	male_character.scale = female_character.scale


func _show_welcome() -> void:
	welcome_panel.show()
	login_form.hide()
	register_form.hide()
	_set_status("Explora Chapinero, descubre sus historias y conserva tu aventura.", false)


func _show_login() -> void:
	welcome_panel.hide()
	login_form.show()
	register_form.hide()
	_set_status("Ingresa con tu cuenta para recuperar tu partida.", false)
	login_value.grab_focus()


func _show_register() -> void:
	welcome_panel.hide()
	login_form.hide()
	register_form.show()
	_set_status("Crea una partida nueva e independiente.", false)
	register_username.grab_focus()


func _submit_login() -> void:
	var identity := login_value.text.strip_edges()
	if identity.is_empty() or login_password.text.is_empty():
		_set_status("Escribe tu usuario o correo y la contrasena.", true)
		return
	AuthManager.login(identity, login_password.text)


func _submit_register() -> void:
	var username := register_username.text.strip_edges()
	var email := register_email.text.strip_edges()
	var password := register_password.text
	var confirmation := register_confirmation.text
	if username.is_empty() or email.is_empty() or password.is_empty() or confirmation.is_empty():
		_set_status("Completa todos los campos obligatorios.", true)
		return
	if username.length() < 3 or username.length() > 24:
		_set_status("El usuario debe tener entre 3 y 24 caracteres.", true)
		register_username.grab_focus()
		return
	var username_regex := RegEx.new()
	username_regex.compile("^[A-Za-z0-9_.-]+$")
	if username_regex.search(username) == null:
		_set_status("El usuario admite letras, numeros, punto, guion y guion bajo.", true)
		register_username.grab_focus()
		return
	var email_regex := RegEx.new()
	email_regex.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")
	if email_regex.search(email) == null:
		_set_status("Escribe un correo electronico valido.", true)
		register_email.grab_focus()
		return
	if password.length() < 8:
		_set_status("La contrasena debe tener minimo 8 caracteres.", true)
		register_password.grab_focus()
		return
	if password.length() > 256:
		_set_status("La contrasena es demasiado larga.", true)
		return
	if password != confirmation:
		_set_status("Las contrasenas no coinciden.", true)
		register_confirmation.grab_focus()
		return
	AuthManager.register_account(username, email, password, confirmation)


func _on_busy_changed(is_busy: bool) -> void:
	login_button.disabled = is_busy
	register_button.disabled = is_busy
	loading_label.visible = is_busy
	if is_busy:
		_set_status("Conectando de forma segura...", false)


func _on_authentication_failed(message: String, field: String) -> void:
	_preparing_game = false
	_set_status(message, true)
	if field == "username":
		register_username.grab_focus()
	elif field == "email":
		register_email.grab_focus()


func _on_authentication_succeeded(is_new_account: bool, profile: Dictionary) -> void:
	_preparing_game = true
	AuthManager.preserve_legacy_customization()
	_set_status(
		"Cuenta creada. Preparando tu primera aventura..." if is_new_account
		else "Bienvenido, %s. Recuperando tu partida..." % str(profile.get("username", "")),
		false,
	)
	loading_label.show()
	ApiService.cargar_personalizacion()


func _on_customization_loaded(outfit: String, hair: String, character_type: String) -> void:
	if not _preparing_game:
		return
	_write_customization(outfit, hair, character_type)
	_enter_game()


func _on_customization_load_failed(reason: String) -> void:
	if not _preparing_game:
		return
	if reason.contains("Sin registro"):
		_write_customization("original", "castano", "mujer")
		_enter_game()
		return
	_preparing_game = false
	loading_label.hide()
	_set_status("No se pudo recuperar el personaje: %s" % reason, true)


func _write_customization(outfit: String, hair: String, character_type: String) -> void:
	var config := ConfigFile.new()
	config.set_value("character", "type", character_type)
	config.set_value("character", "outfit", outfit)
	config.set_value("character", "hair", hair)
	var path := OS.get_environment("VIDEOJUEGO_CUSTOMIZATION_CACHE")
	config.save(path if not path.is_empty() else CUSTOMIZATION_PATH)


func _enter_game() -> void:
	_set_status("Partida recuperada. Entrando a Chapinero...", false)
	loading_label.show()
	await get_tree().create_timer(0.65).timeout
	if is_inside_tree() and AuthManager.is_authenticated():
		get_tree().change_scene_to_file(MAP_SCENE)


func _set_status(message: String, is_error: bool) -> void:
	status_label.text = message
	status_label.modulate = Color(1.0, 0.45, 0.68) if is_error else Color(0.76, 0.9, 1.0)


func _exit_tree() -> void:
	if AuthManager.authentication_succeeded.is_connected(_on_authentication_succeeded):
		AuthManager.authentication_succeeded.disconnect(_on_authentication_succeeded)
	if AuthManager.authentication_failed.is_connected(_on_authentication_failed):
		AuthManager.authentication_failed.disconnect(_on_authentication_failed)
	if AuthManager.busy_changed.is_connected(_on_busy_changed):
		AuthManager.busy_changed.disconnect(_on_busy_changed)
	if ApiService.customization_loaded.is_connected(_on_customization_loaded):
		ApiService.customization_loaded.disconnect(_on_customization_loaded)
	if ApiService.customization_load_failed.is_connected(_on_customization_load_failed):
		ApiService.customization_load_failed.disconnect(_on_customization_load_failed)
