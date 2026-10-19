extends Node

## Estado local visible y estado confirmado son cosas distintas. PostgreSQL es la
## fuente de verdad; este archivo local solo conserva eventos pendientes si no hay red.
signal place_visited(place_id: String)
signal place_discovered(place_id: String)
signal place_discovery_confirmed(place_id: String)
signal exploration_progress_changed(discovered: int, total: int)
signal place_state_changed(place_id: String)
signal loading_changed(loading: bool)
signal synchronization_changed(pending_count: int, online: bool)
signal discovery_reward_available

const CACHE_PATH := "user://exploration_queue.cfg"
const PENDING := 0
const VISITED := 1
const DISCOVERED := 2

var _catalog: Dictionary = {}
var _catalog_order: Array[String] = []
var _confirmed: Dictionary = {}
var _pending: Dictionary = {}
var _rewards: Array[String] = []
var _loading := true
var _online := false
var _load_in_flight := false
var _syncing_place_id := ""
var _retry_timer: Timer


func _ready() -> void:
	ApiService.exploration_loaded.connect(_on_exploration_loaded)
	ApiService.exploration_load_failed.connect(_on_exploration_load_failed)
	ApiService.exploration_event_saved.connect(_on_exploration_event_saved)
	ApiService.exploration_event_failed.connect(_on_exploration_event_failed)
	_retry_timer = Timer.new()
	_retry_timer.wait_time = 12.0
	_retry_timer.one_shot = true
	add_child(_retry_timer)
	_retry_timer.timeout.connect(_retry)
	_load_cache()
	_refresh_from_server()


func register_places(places: Array) -> void:
	_catalog.clear()
	_catalog_order.clear()
	for value in places:
		if not value is Dictionary:
			continue
		var place_id := str(value.get("place_id", ""))
		if place_id.is_empty() or _catalog.has(place_id):
			continue
		_catalog[place_id] = value.duplicate(true)
		_catalog_order.append(place_id)
	_emit_all_states()


func get_places() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for place_id in _catalog_order:
		result.append(_catalog[place_id])
	return result


func get_place_data(place_id: String) -> Dictionary:
	return _catalog.get(place_id, {})


func get_state(place_id: String) -> int:
	return maxi(_confirmed_level(place_id), int(_pending.get(place_id, PENDING)))


func get_record(place_id: String) -> Dictionary:
	return _confirmed.get(place_id, {}).duplicate(true)


func get_discovered_count() -> int:
	var discovered := 0
	for place_id in _catalog_order:
		if get_state(place_id) == DISCOVERED:
			discovered += 1
	return discovered


func get_total_count() -> int:
	return _catalog_order.size()


func get_pending_count() -> int:
	return _pending.size()


func is_pending_sync(place_id: String) -> bool:
	return _pending.has(place_id)


func is_loading() -> bool:
	return _loading


func is_online() -> bool:
	return _online


func take_discovery_reward() -> String:
	return "" if _rewards.is_empty() else _rewards.pop_front()


func record_visit(place_id: String) -> void:
	_record_event(place_id, VISITED)


func record_discovery(place_id: String) -> void:
	_record_event(place_id, DISCOVERED)


func _record_event(place_id: String, target_state: int) -> void:
	if not _catalog.has(place_id):
		push_warning("POI sin identificador registrado: %s" % place_id)
		return
	var previous := get_state(place_id)
	if previous >= target_state:
		return
	_pending[place_id] = target_state
	_save_cache() # guardar antes de intentar la red
	if previous == PENDING:
		place_visited.emit(place_id)
	if target_state == DISCOVERED:
		place_discovered.emit(place_id)
	place_state_changed.emit(place_id)
	_emit_progress()
	_emit_sync_status()
	_flush_pending()


func _confirmed_level(place_id: String) -> int:
	if not _confirmed.has(place_id):
		return PENDING
	var record: Dictionary = _confirmed[place_id]
	return DISCOVERED if record.get("discovered_at") != null else VISITED


func _refresh_from_server() -> void:
	if _load_in_flight or not _syncing_place_id.is_empty():
		return
	_load_in_flight = true
	ApiService.cargar_exploracion()


func _on_exploration_loaded(places: Array) -> void:
	_load_in_flight = false
	_loading = false
	_online = true
	_retry_timer.stop()
	_confirmed.clear()
	for value in places:
		if value is Dictionary and value.has("place_id"):
			_confirmed[str(value["place_id"])] = value.duplicate(true)
	for place_id in _pending.keys():
		if _confirmed_level(place_id) >= int(_pending[place_id]):
			_pending.erase(place_id)
	_save_cache()
	loading_changed.emit(false)
	_emit_all_states()
	_emit_sync_status()
	_flush_pending()


func _on_exploration_load_failed(reason: String) -> void:
	_load_in_flight = false
	_loading = false
	_online = false
	push_warning("Exploración sin conexión: %s" % reason)
	loading_changed.emit(false)
	_emit_all_states()
	_emit_sync_status()
	_retry_timer.start()


func _on_exploration_event_saved(place_id: String, _event_type: String, record: Dictionary) -> void:
	_syncing_place_id = ""
	if str(record.get("place_id", "")) != place_id or not record.has("discovered_at"):
		_on_exploration_event_failed(place_id, _event_type, "Respuesta incompleta")
		return
	_confirmed[place_id] = record.duplicate(true)
	if _pending.has(place_id) and _confirmed_level(place_id) >= int(_pending[place_id]):
		_pending.erase(place_id)
	_online = true
	_save_cache()
	place_state_changed.emit(place_id)
	_emit_progress()
	_emit_sync_status()
	if bool(record.get("newly_discovered", false)):
		place_discovery_confirmed.emit(place_id)
		_rewards.append(place_id)
		discovery_reward_available.emit()
	_flush_pending()


func _on_exploration_event_failed(place_id: String, _event_type: String, reason: String) -> void:
	_syncing_place_id = ""
	_online = false
	push_warning("No se sincronizó %s: %s" % [place_id, reason])
	_emit_sync_status()
	_retry_timer.start()


func _flush_pending() -> void:
	if _loading or not _online or _load_in_flight or not _syncing_place_id.is_empty():
		return
	if _pending.is_empty():
		return
	var place_id := str(_pending.keys()[0])
	var event_type := "discover" if int(_pending[place_id]) == DISCOVERED else "visit"
	_syncing_place_id = place_id
	ApiService.registrar_evento_exploracion(place_id, event_type)


func _retry() -> void:
	if not _online:
		_refresh_from_server()
	else:
		_flush_pending()


func _emit_progress() -> void:
	exploration_progress_changed.emit(get_discovered_count(), get_total_count())


func _emit_all_states() -> void:
	for place_id in _catalog_order:
		place_state_changed.emit(place_id)
	_emit_progress()


func _emit_sync_status() -> void:
	synchronization_changed.emit(_pending.size(), _online)


func _load_cache() -> void:
	var config := ConfigFile.new()
	if config.load(CACHE_PATH) != OK:
		return
	if str(config.get_value("exploration", "player_id", "")) != ApiService.get_player_id():
		return
	var confirmed: Variant = config.get_value("exploration", "confirmed", {})
	var pending: Variant = config.get_value("exploration", "pending", {})
	if confirmed is Dictionary:
		_confirmed = confirmed
	if pending is Dictionary:
		_pending = pending


func _save_cache() -> void:
	var config := ConfigFile.new()
	config.set_value("exploration", "player_id", ApiService.get_player_id())
	config.set_value("exploration", "confirmed", _confirmed)
	config.set_value("exploration", "pending", _pending)
	var result := config.save(CACHE_PATH)
	if result != OK:
		push_warning("No se pudo conservar la cola de exploración (%d)" % result)
