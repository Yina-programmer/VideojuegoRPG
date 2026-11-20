extends Node

signal authentication_succeeded(is_new_account: bool, profile: Dictionary)
signal authentication_failed(message: String, field: String)
signal busy_changed(is_busy: bool)
signal session_started(profile: Dictionary)
signal session_ended

const API_BASE_URL := "http://localhost:4000"
const AUTH_SCENE := "res://scenes/auth/AuthScreen.tscn"
const ACTIVE_CUSTOMIZATION := "user://player_customization.cfg"

enum RequestKind { NONE, REGISTER, LOGIN, VERIFY, LOGOUT }

var _http: HTTPRequest
var _kind := RequestKind.NONE
var _busy := false
var _token := ""
var _profile: Dictionary = {}
var _pending_is_new := false
var _logout_layer: CanvasLayer
var _logout_button: Button


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 12.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	get_tree().scene_changed.connect(_on_scene_changed)
	_create_logout_button()
	call_deferred("_on_scene_changed")


func is_authenticated() -> bool:
	return not _token.is_empty() and not _profile.is_empty()


func is_busy() -> bool:
	return _busy


func get_token() -> String:
	return _token


func get_player_id() -> String:
	return str(_profile.get("player_id", ""))


func get_profile() -> Dictionary:
	return _profile.duplicate(true)


func authorization_headers(include_json: bool = false) -> PackedStringArray:
	var headers := PackedStringArray()
	if include_json:
		headers.append("Content-Type: application/json")
	if not _token.is_empty():
		headers.append("Authorization: Bearer %s" % _token)
	return headers


func register_account(username: String, email: String, password: String, confirmation: String) -> void:
	_begin_credentials_request(RequestKind.REGISTER, "/api/auth/register", {
		"username": username.strip_edges(),
		"email": email.strip_edges(),
		"password": password,
		"password_confirmation": confirmation,
	})


func login(login_value: String, password: String) -> void:
	_begin_credentials_request(RequestKind.LOGIN, "/api/auth/login", {
		"login": login_value.strip_edges(),
		"password": password,
	})


func logout() -> void:
	if _busy:
		return
	_archive_active_customization()
	if _token.is_empty():
		_clear_session_and_return()
		return
	_set_busy(true)
	_kind = RequestKind.LOGOUT
	var error := _http.request(
		_api_base_url() + "/api/auth/logout",
		authorization_headers(),
		HTTPClient.METHOD_POST,
	)
	if error != OK:
		_clear_session_and_return()


func expire_session() -> void:
	if _kind == RequestKind.LOGOUT:
		return
	_archive_active_customization()
	_clear_session_and_return()


func _begin_credentials_request(kind: RequestKind, endpoint: String, payload: Dictionary) -> void:
	if _busy:
		return
	_set_busy(true)
	_kind = kind
	var error := _http.request(
		_api_base_url() + endpoint,
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload),
	)
	if error != OK:
		_kind = RequestKind.NONE
		_set_busy(false)
		authentication_failed.emit("No se pudo conectar con el servidor.", "")


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	var completed_kind := _kind
	var body_text := body.get_string_from_utf8()
	var data: Variant = {} if body_text.is_empty() else JSON.parse_string(body_text)
	if completed_kind == RequestKind.LOGOUT:
		_clear_session_and_return()
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		_reset_pending_auth()
		authentication_failed.emit("No se pudo conectar con el servidor.", "")
		return
	if response_code < 200 or response_code >= 300 or not data is Dictionary:
		var message := "Respuesta invalida del servidor."
		var field := ""
		if data is Dictionary:
			message = str(data.get("error", message))
			field = str(data.get("field", ""))
		_reset_pending_auth()
		authentication_failed.emit(message, field)
		return

	if completed_kind in [RequestKind.REGISTER, RequestKind.LOGIN]:
		_token = str(data.get("token", ""))
		var response_profile: Variant = data.get("profile", {})
		if _token.is_empty() or not response_profile is Dictionary:
			_reset_pending_auth()
			authentication_failed.emit("La sesion recibida no es valida.", "")
			return
		_pending_is_new = completed_kind == RequestKind.REGISTER
		_kind = RequestKind.VERIFY
		var verify_error := _http.request(
			_api_base_url() + "/api/auth/me",
			authorization_headers(),
			HTTPClient.METHOD_GET,
		)
		if verify_error != OK:
			_reset_pending_auth()
			authentication_failed.emit("No se pudo verificar la sesion.", "")
		return

	if completed_kind == RequestKind.VERIFY:
		var verified_profile: Variant = data.get("profile", {})
		if not verified_profile is Dictionary or str(verified_profile.get("player_id", "")).is_empty():
			_reset_pending_auth()
			authentication_failed.emit("El perfil recibido esta incompleto.", "")
			return
		_profile = verified_profile.duplicate(true)
		_kind = RequestKind.NONE
		_set_busy(false)
		session_started.emit(_profile.duplicate(true))
		authentication_succeeded.emit(_pending_is_new, _profile.duplicate(true))
		_pending_is_new = false
		_update_logout_button()


func _reset_pending_auth() -> void:
	_token = ""
	_profile.clear()
	_pending_is_new = false
	_kind = RequestKind.NONE
	_set_busy(false)
	_update_logout_button()


func _clear_session_and_return() -> void:
	_http.cancel_request()
	_token = ""
	_profile.clear()
	_pending_is_new = false
	_kind = RequestKind.NONE
	_set_busy(false)
	_remove_active_customization()
	session_ended.emit()
	_update_logout_button()
	if (
		OS.get_environment("VIDEOJUEGO_AUTH_TEST_MODE") != "1"
		and (get_tree().current_scene == null or get_tree().current_scene.scene_file_path != AUTH_SCENE)
	):
		get_tree().change_scene_to_file(AUTH_SCENE)


func _set_busy(value: bool) -> void:
	_busy = value
	busy_changed.emit(_busy)


func _api_base_url() -> String:
	var override := OS.get_environment("VIDEOJUEGO_API_BASE_URL")
	return override if not override.is_empty() else API_BASE_URL


func _archive_active_customization() -> void:
	var player_id := get_player_id()
	if player_id.is_empty() or not FileAccess.file_exists(ACTIVE_CUSTOMIZATION):
		return
	_copy_file(ACTIVE_CUSTOMIZATION, "user://player_customization_%s.cfg" % player_id)


func preserve_legacy_customization() -> void:
	if not FileAccess.file_exists(ACTIVE_CUSTOMIZATION):
		return
	var legacy_path := "user://legacy_anonymous_customization.cfg"
	if not FileAccess.file_exists(legacy_path):
		_copy_file(ACTIVE_CUSTOMIZATION, legacy_path)


func _copy_file(source: String, destination: String) -> void:
	var input := FileAccess.open(source, FileAccess.READ)
	if input == null:
		return
	var data := input.get_buffer(input.get_length())
	var output := FileAccess.open(destination, FileAccess.WRITE)
	if output != null:
		output.store_buffer(data)


func _remove_active_customization() -> void:
	if FileAccess.file_exists(ACTIVE_CUSTOMIZATION):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ACTIVE_CUSTOMIZATION))


func _create_logout_button() -> void:
	_logout_layer = CanvasLayer.new()
	_logout_layer.layer = 120
	add_child(_logout_layer)
	_logout_button = Button.new()
	_logout_button.text = "Cerrar sesion"
	_logout_button.tooltip_text = "Salir de esta cuenta"
	_logout_button.custom_minimum_size = Vector2(150, 46)
	_logout_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_logout_button.offset_left = -174.0
	_logout_button.offset_top = 18.0
	_logout_button.offset_right = -18.0
	_logout_button.offset_bottom = 64.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.035, 0.13, 0.92)
	style.border_color = Color(1.0, 0.2, 0.78, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	_logout_button.add_theme_stylebox_override("normal", style)
	_logout_button.add_theme_font_size_override("font_size", 18)
	_logout_button.pressed.connect(logout)
	_logout_layer.add_child(_logout_button)
	_update_logout_button()


func _on_scene_changed() -> void:
	_update_logout_button()


func _update_logout_button() -> void:
	if _logout_button == null:
		return
	var path := get_tree().current_scene.scene_file_path if get_tree().current_scene != null else ""
	_logout_button.visible = is_authenticated() and path != AUTH_SCENE
