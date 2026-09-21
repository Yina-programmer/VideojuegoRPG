## ApiService — Autoload singleton
##
## Centraliza TODAS las comunicaciones HTTP con el backend.
## Nunca debe instanciarse directamente; se accede globalmente como ApiService.
##
## Flujo al abrir el armario (llamar iniciar_sincronizacion):
##   - Si pending_sync = true  → PUT con datos locales primero
##   - Si pending_sync = false → GET para cargar del servidor
##
## Flujo al presionar Guardar (llamar guardar_personalizacion):
##   1. pending_sync = true  (inmediato, antes de enviar)
##   2. PUT al servidor
##   3. Si 200 → pending_sync = false, emit customization_saved
##   4. Si error → pending_sync se mantiene true, emit customization_save_failed

extends Node

# ── Señales públicas ─────────────────────────────────────────────────────────

## El servidor devolvió la personalización del jugador.
signal customization_loaded(outfit_id: String, hair_style_id: String)

## No se pudo cargar del servidor (primera vez o error de red).
## closet_ui debe usar los valores locales existentes.
signal customization_load_failed(reason: String)

## El servidor confirmó el guardado (UPSERT exitoso).
signal customization_saved()

## El servidor no respondió o respondió con error.
## pending_sync queda en true para reintentar al abrir el armario.
signal customization_save_failed(reason: String)

# ── Configuración ─────────────────────────────────────────────────────────────

## URL base de la API. Cambiar aquí si el backend corre en otro puerto o host.
const API_BASE_URL    := "http://localhost:4000"
const PLAYER_ID_PATH  := "user://player_id.cfg"

# ── Estado interno ────────────────────────────────────────────────────────────

enum _ReqType { NONE, GET_CUSTOMIZATION, PUT_CUSTOMIZATION }

var _http: HTTPRequest
var _request_in_progress := false
var _current_req: _ReqType = _ReqType.NONE
var _player_id := ""

# ── Ciclo de vida ─────────────────────────────────────────────────────────────

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_player_id = _load_or_create_player_id()
	print("[ApiService] Inicializado. Player ID: ", _player_id)

# ── API pública ───────────────────────────────────────────────────────────────

## Devuelve el player_id del jugador actual (UUID v4).
func get_player_id() -> String:
	return _player_id

## Inicia la sincronización al abrir el armario.
##
## Regla: si hay pending_sync, los datos locales tienen prioridad
## y se envían primero al servidor (PUT). Solo si no hay pendientes
## se carga del servidor (GET) para no sobreescribir cambios locales.
func iniciar_sincronizacion(outfit_local: String, hair_local: String) -> void:
	if _request_in_progress:
		return

	if _get_pending_sync():
		# Cambios locales no sincronizados → prioridad al dato local
		print("[ApiService] pending_sync = true. Sincronizando datos locales...")
		guardar_personalizacion(outfit_local, hair_local, "mujer")
	else:
		# Sin cambios pendientes → cargar del servidor
		print("[ApiService] Sin pendientes. Cargando del servidor...")
		_enviar_get()

## Guarda la personalización en el servidor mediante UPSERT.
##
## Orden garantizado:
##   1. pending_sync = true (antes de enviar, por si el juego se cierra)
##   2. PUT a la API
##   3. Si 200 → pending_sync = false + emit customization_saved
##   4. Si error → pending_sync se mantiene true + emit customization_save_failed
func guardar_personalizacion(
	outfit_id: String,
	hair_style_id: String,
	character_type: String,
) -> void:
	if _request_in_progress:
		print("[ApiService] Solicitud en curso. Ignorando guardado duplicado.")
		return

	# 1. Marcar pending ANTES de enviar
	_set_pending_sync(true)

	# 2. Enviar PUT
	_request_in_progress = true
	_current_req = _ReqType.PUT_CUSTOMIZATION

	var body := JSON.stringify({
		"outfit_id":      outfit_id,
		"hair_style_id":  hair_style_id,
		"character_type": character_type,
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := "%s/api/customization/%s" % [API_BASE_URL, _player_id]

	var err := _http.request(url, headers, HTTPClient.METHOD_PUT, body)
	if err != OK:
		_request_in_progress = false
		_current_req = _ReqType.NONE
		# pending_sync se mantiene true
		print("[ApiService] Error al iniciar PUT: ", err)
		customization_save_failed.emit("Error al iniciar solicitud PUT (código %d)" % err)

# ── Privado: enviar GET ───────────────────────────────────────────────────────

func _enviar_get() -> void:
	_request_in_progress = true
	_current_req = _ReqType.GET_CUSTOMIZATION

	var url := "%s/api/customization/%s" % [API_BASE_URL, _player_id]
	var err := _http.request(url, PackedStringArray(), HTTPClient.METHOD_GET)
	if err != OK:
		_request_in_progress = false
		_current_req = _ReqType.NONE
		print("[ApiService] Error al iniciar GET: ", err)
		customization_load_failed.emit("Error al iniciar solicitud GET (código %d)" % err)

# ── Privado: callback HTTPRequest ─────────────────────────────────────────────

func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	var req_type := _current_req
	_request_in_progress = false
	_current_req = _ReqType.NONE

	match req_type:
		_ReqType.GET_CUSTOMIZATION:
			_manejar_respuesta_get(result, response_code, body)
		_ReqType.PUT_CUSTOMIZATION:
			_manejar_respuesta_put(result, response_code)

func _manejar_respuesta_get(
	result: int,
	response_code: int,
	body: PackedByteArray,
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[ApiService] Error de red en GET: ", result)
		customization_load_failed.emit("Error de red (GET): código %d" % result)
		return

	if response_code == 404:
		# Primera vez — sin registro en el servidor. Usar valores locales.
		print("[ApiService] 404 — sin registro en servidor (primera vez).")
		customization_load_failed.emit("Sin registro en el servidor (primera vez)")
		return

	if response_code != 200:
		print("[ApiService] Error del servidor en GET: ", response_code)
		customization_load_failed.emit("Error del servidor (GET): %d" % response_code)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		customization_load_failed.emit("Error al parsear respuesta JSON")
		return

	var data = json.get_data()
	if not data is Dictionary:
		customization_load_failed.emit("Respuesta inesperada del servidor")
		return

	var outfit     := str(data.get("outfit_id",     ""))
	var hair_style := str(data.get("hair_style_id", ""))

	if outfit.is_empty() or hair_style.is_empty():
		customization_load_failed.emit("Datos incompletos en la respuesta")
		return

	print("[ApiService] Personalización cargada: outfit=%s, cabello=%s" % [outfit, hair_style])
	customization_loaded.emit(outfit, hair_style)

func _manejar_respuesta_put(result: int, response_code: int) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		# pending_sync se mantiene true para reintentar
		print("[ApiService] Error de red en PUT: ", result)
		customization_save_failed.emit("Error de red (PUT): código %d" % result)
		return

	if response_code != 200:
		# pending_sync se mantiene true
		print("[ApiService] Error del servidor en PUT: ", response_code)
		customization_save_failed.emit("Error del servidor (PUT): %d" % response_code)
		return

	# Éxito: limpiar pending_sync
	_set_pending_sync(false)
	print("[ApiService] Guardado confirmado por el servidor.")
	customization_saved.emit()

# ── Privado: Player ID ────────────────────────────────────────────────────────

func _load_or_create_player_id() -> String:
	var config := ConfigFile.new()
	if config.load(PLAYER_ID_PATH) == OK:
		var saved_id := str(config.get_value("player", "id", ""))
		if not saved_id.is_empty():
			return saved_id

	# Primera ejecución: generar UUID v4 y persistirlo
	var new_id := _generar_uuid_v4()
	config.set_value("player", "id", new_id)
	config.set_value("sync", "pending", false)
	config.save(PLAYER_ID_PATH)
	print("[ApiService] Nuevo player_id generado: ", new_id)
	return new_id

## Genera un UUID v4 aleatorio (RFC 4122).
func _generar_uuid_v4() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var b := PackedByteArray()
	b.resize(16)
	for i in range(16):
		b[i] = rng.randi() % 256

	# Versión 4: bits 4-7 del byte 6 = 0100
	b[6] = (b[6] & 0x0f) | 0x40
	# Variante RFC 4122: bits 6-7 del byte 8 = 10
	b[8] = (b[8] & 0x3f) | 0x80

	const HEX := "0123456789abcdef"
	var uuid := ""
	for i in range(16):
		uuid += HEX[b[i] >> 4]
		uuid += HEX[b[i] & 0x0f]
		if i in [3, 5, 7, 9]:
			uuid += "-"
	return uuid

# ── Privado: Pending Sync ─────────────────────────────────────────────────────

func _get_pending_sync() -> bool:
	var config := ConfigFile.new()
	if config.load(PLAYER_ID_PATH) != OK:
		return false
	return bool(config.get_value("sync", "pending", false))

func _set_pending_sync(value: bool) -> void:
	var config := ConfigFile.new()
	# Cargar datos existentes para no perder el player_id
	config.load(PLAYER_ID_PATH)
	config.set_value("sync", "pending", value)
	config.save(PLAYER_ID_PATH)
