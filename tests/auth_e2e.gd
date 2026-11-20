extends Node

var _auth_result: Dictionary = {}
var _customization_result: Dictionary = {}
var _logout_complete := false
var _quest_event_result: Dictionary = {}
var _exploration_event_result: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var suffix := "%d_%d" % [int(Time.get_unix_time_from_system()), randi_range(1000, 9999)]
	var username := "godot_%s" % suffix
	var email := "%s@auth-tests.invalid" % username
	var password := "ChapiUnderLand-%s!" % suffix

	_connect_auth_result()
	AuthManager.register_account(username, email, password, password)
	if not await _wait_for_auth(15.0):
		_fail("El registro desde Godot excedio el tiempo de espera")
		return
	_disconnect_auth_result()
	if not bool(_auth_result.get("success", false)):
		_fail("Registro Godot rechazado: %s" % str(_auth_result.get("message", "")))
		return
	var player_id := AuthManager.get_player_id()
	var first_token := AuthManager.get_token()
	if player_id.is_empty() or first_token.is_empty() or ApiService.get_player_id() != player_id:
		_fail("La cuenta no configuro su player_id autenticado")
		return

	_connect_customization_result()
	ApiService.cargar_personalizacion()
	if not await _wait_for_customization(12.0):
		_fail("La personalizacion inicial no respondio")
		return
	_disconnect_customization_result()
	if bool(_customization_result.get("success", false)):
		_fail("Una cuenta nueva heredo personalizacion ajena")
		return

	_customization_result.clear()
	_connect_customization_result()
	ApiService.guardar_personalizacion("azul", "castano", "mujer")
	if not await _wait_for_customization(12.0):
		_fail("No se guardo la personalizacion autenticada")
		return
	_disconnect_customization_result()
	if not bool(_customization_result.get("saved", false)):
		_fail("El backend rechazo el guardado autenticado")
		return

	ApiService.quest_event_saved.connect(_on_quest_saved)
	ApiService.quest_event_failed.connect(_on_quest_failed)
	ApiService.registrar_evento_mision("hippies", "start")
	if not await _wait_for_quest_event(12.0) or not bool(_quest_event_result.get("success", false)):
		_fail("No se guardo la mision autenticada")
		return
	_disconnect_progress_events()
	ApiService.exploration_event_saved.connect(_on_exploration_saved)
	ApiService.exploration_event_failed.connect(_on_exploration_failed)
	ApiService.registrar_evento_exploracion("hippies", "visit")
	if not await _wait_for_exploration_event(12.0) or not bool(_exploration_event_result.get("success", false)):
		_fail("No se guardo la exploracion autenticada")
		return
	_disconnect_progress_events()

	_logout_complete = false
	AuthManager.session_ended.connect(_on_session_ended, CONNECT_ONE_SHOT)
	AuthManager.logout()
	if not await _wait_for_logout(12.0):
		_fail("El cierre de sesion no termino")
		return
	if AuthManager.is_authenticated() or not ApiService.get_player_id().is_empty():
		_fail("Cerrar sesion dejo datos privados en memoria")
		return
	if not QuestManager.get_quest("hippies").is_empty() or not ProgressManager.get_record("hippies").is_empty():
		_fail("Cerrar sesion dejo progreso de la cuenta anterior en los gestores")
		return
	var raw := HTTPRequest.new()
	add_child(raw)
	var request_error := raw.request(
		_api_base_url() + "/api/auth/me",
		PackedStringArray(["Authorization: Bearer %s" % first_token]),
		HTTPClient.METHOD_GET,
	)
	if request_error != OK:
		_fail("No se pudo comprobar la revocacion de la sesion")
		return
	var raw_response: Array = await raw.request_completed
	if int(raw_response[1]) != 401:
		_fail("El token cerrado aun permite acceder al perfil")
		return
	raw.queue_free()

	_auth_result.clear()
	_connect_auth_result()
	AuthManager.login(username, password)
	if not await _wait_for_auth(15.0):
		_fail("El reingreso desde Godot excedio el tiempo de espera")
		return
	_disconnect_auth_result()
	if not bool(_auth_result.get("success", false)) or AuthManager.get_player_id() != player_id:
		_fail("El reingreso no recupero el mismo perfil")
		return
	if not await _wait_for_managers(12.0):
		_fail("Los gestores de progreso no terminaron de cargar")
		return
	if QuestManager.get_quest("hippies").is_empty():
		_fail("La mision guardada no se recupero al iniciar sesion")
		return
	if ProgressManager.get_record("hippies").is_empty():
		_fail("La visita guardada no se recupero al iniciar sesion")
		return

	_customization_result.clear()
	_connect_customization_result()
	ApiService.cargar_personalizacion()
	if not await _wait_for_customization(12.0):
		_fail("La recuperacion de personalizacion excedio el tiempo")
		return
	_disconnect_customization_result()
	if (
		not bool(_customization_result.get("success", false))
		or str(_customization_result.get("outfit", "")) != "azul"
		or str(_customization_result.get("hair", "")) != "castano"
	):
		_fail("La cuenta no recupero su personalizacion guardada")
		return

	print("AUTH_E2E: registro, perfil, personalizacion, misiones, exploracion, logout, revocacion y recuperacion verificados")
	get_tree().quit(0)


func _connect_auth_result() -> void:
	AuthManager.authentication_succeeded.connect(_on_auth_success)
	AuthManager.authentication_failed.connect(_on_auth_failure)


func _disconnect_auth_result() -> void:
	if AuthManager.authentication_succeeded.is_connected(_on_auth_success):
		AuthManager.authentication_succeeded.disconnect(_on_auth_success)
	if AuthManager.authentication_failed.is_connected(_on_auth_failure):
		AuthManager.authentication_failed.disconnect(_on_auth_failure)


func _connect_customization_result() -> void:
	ApiService.customization_loaded.connect(_on_customization_loaded)
	ApiService.customization_load_failed.connect(_on_customization_failed)
	ApiService.customization_saved.connect(_on_customization_saved)
	ApiService.customization_save_failed.connect(_on_customization_save_failed)


func _disconnect_customization_result() -> void:
	if ApiService.customization_loaded.is_connected(_on_customization_loaded):
		ApiService.customization_loaded.disconnect(_on_customization_loaded)
	if ApiService.customization_load_failed.is_connected(_on_customization_failed):
		ApiService.customization_load_failed.disconnect(_on_customization_failed)
	if ApiService.customization_saved.is_connected(_on_customization_saved):
		ApiService.customization_saved.disconnect(_on_customization_saved)
	if ApiService.customization_save_failed.is_connected(_on_customization_save_failed):
		ApiService.customization_save_failed.disconnect(_on_customization_save_failed)


func _on_auth_success(is_new: bool, profile: Dictionary) -> void:
	_auth_result = {"success": true, "is_new": is_new, "profile": profile}


func _on_auth_failure(message: String, field: String) -> void:
	_auth_result = {"success": false, "message": message, "field": field}


func _on_customization_loaded(outfit: String, hair: String, character_type: String) -> void:
	_customization_result = {"success": true, "outfit": outfit, "hair": hair, "character_type": character_type}


func _on_customization_failed(reason: String) -> void:
	_customization_result = {"success": false, "reason": reason}


func _on_customization_saved() -> void:
	_customization_result = {"saved": true}


func _on_customization_save_failed(reason: String) -> void:
	_customization_result = {"saved": false, "reason": reason}


func _on_session_ended() -> void:
	_logout_complete = true


func _on_quest_saved(_quest_id: String, _event: String, _record: Dictionary) -> void:
	_quest_event_result = {"success": true}


func _on_quest_failed(_quest_id: String, _event: String, reason: String, _retryable: bool) -> void:
	_quest_event_result = {"success": false, "reason": reason}


func _on_exploration_saved(_place_id: String, _event: String, _record: Dictionary) -> void:
	_exploration_event_result = {"success": true}


func _on_exploration_failed(_place_id: String, _event: String, reason: String) -> void:
	_exploration_event_result = {"success": false, "reason": reason}


func _disconnect_progress_events() -> void:
	if ApiService.quest_event_saved.is_connected(_on_quest_saved):
		ApiService.quest_event_saved.disconnect(_on_quest_saved)
	if ApiService.quest_event_failed.is_connected(_on_quest_failed):
		ApiService.quest_event_failed.disconnect(_on_quest_failed)
	if ApiService.exploration_event_saved.is_connected(_on_exploration_saved):
		ApiService.exploration_event_saved.disconnect(_on_exploration_saved)
	if ApiService.exploration_event_failed.is_connected(_on_exploration_failed):
		ApiService.exploration_event_failed.disconnect(_on_exploration_failed)


func _wait_for_auth(timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while _auth_result.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return not _auth_result.is_empty()


func _wait_for_customization(timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while _customization_result.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return not _customization_result.is_empty()


func _wait_for_logout(timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not _logout_complete and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return _logout_complete


func _wait_for_quest_event(timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while _quest_event_result.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return not _quest_event_result.is_empty()


func _wait_for_exploration_event(timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while _exploration_event_result.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return not _exploration_event_result.is_empty()


func _wait_for_managers(timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while (QuestManager.is_loading() or ProgressManager.is_loading()) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return not QuestManager.is_loading() and not ProgressManager.is_loading()


func _api_base_url() -> String:
	return OS.get_environment("VIDEOJUEGO_API_BASE_URL")


func _fail(message: String) -> void:
	_disconnect_auth_result()
	_disconnect_customization_result()
	_disconnect_progress_events()
	push_error(message)
	get_tree().quit(1)
