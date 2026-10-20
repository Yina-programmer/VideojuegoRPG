extends Node

signal quest_changed(quest_id: String)
signal loading_changed(loading: bool)
signal notice(message: String)
signal puzzle_ready(quest_id: String)

const CACHE_PATH := "user://quest_queue.cfg"
const NPC_QUESTS := {"hippie": "hippies", "polito": "politecnico", "theatron_host": "theatron"}
const QUESTS := {
	"hippies": {"title": "Los mensajes perdidos", "npc": "Nico", "items": ["arte", "calle", "memoria"], "symbol": "Arte"},
	"politecnico": {"title": "El archivo secreto", "npc": "Polito", "items": ["doc_1980", "doc_1981", "doc_1991"], "symbol": "Conocimiento"},
	"theatron": {"title": "La entrada equivocada", "npc": "Dante", "items": ["boleto_1", "boleto_2"], "symbol": "Diversidad"},
	"final": {"title": "El misterio de Chapinero", "npc": "Chapinero", "items": [], "symbol": "Insignia"},
}
const ITEM_CLUES := {
	"arte": "ARTE: creatividad en el espacio público",
	"calle": "CALLE: donde se encuentran las personas",
	"memoria": "MEMORIA: lo que el barrio conserva",
	"cartel_falso": "CARTEL FALSO: la letra no coincide",
	"doc_1980": "1980: fundación del Poli",
	"doc_1981": "Marzo de 1981: inicio de actividades académicas",
	"doc_1991": "1991: institución universitaria",
	"boleto_1": "Boleto I: pantalla y sala",
	"boleto_2": "Boleto II: proyector; el edificio fue un cine",
}

var _confirmed: Dictionary = {}
var _pending: Array[Dictionary] = []
var _loading := true
var _sending := false
var _retry: Timer


func _ready() -> void:
	ApiService.quests_loaded.connect(_on_loaded)
	ApiService.quest_load_failed.connect(_on_load_failed)
	ApiService.quest_event_saved.connect(_on_saved)
	ApiService.quest_event_failed.connect(_on_event_failed)
	_retry = Timer.new()
	_retry.wait_time = 12.0
	_retry.one_shot = true
	add_child(_retry)
	_retry.timeout.connect(_refresh)
	_load_cache()
	_refresh()


func is_loading() -> bool:
	return _loading


func get_quest(quest_id: String) -> Dictionary:
	var state: Dictionary = _confirmed.get(quest_id, {}).duplicate(true)
	for action in _pending:
		if str(action.get("quest_id", "")) != quest_id:
			continue
		match str(action.get("event", "")):
			"start":
				if state.is_empty():
					state = {"status": "active", "collected_items": [], "solved_steps": []}
			"collect":
				if not state.is_empty():
					var item := str(action.get("payload", {}).get("item_id", ""))
					var items: Array = state.get("collected_items", [])
					if not items.has(item):
						items.append(item)
					state["collected_items"] = items
	return state


func is_collected(quest_id: String, item_id: String) -> bool:
	return get_quest(quest_id).get("collected_items", []).has(item_id)


func is_completed(quest_id: String) -> bool:
	return str(_confirmed.get(quest_id, {}).get("status", "")) == "completed"


func is_unlocked(place_id: String) -> bool:
	return is_completed(place_id) or ProgressManager.has_confirmed_discovery(place_id)


func has_items(quest_id: String) -> bool:
	var state := get_quest(quest_id)
	for item in QUESTS[quest_id]["items"]:
		if not state.get("collected_items", []).has(item):
			return false
	return true


func has_step(quest_id: String, step: String) -> bool:
	return get_quest(quest_id).get("solved_steps", []).has(step)


func has_pending_puzzle(quest_id: String) -> bool:
	for action in _pending:
		if action.get("quest_id") == quest_id and action.get("event") in ["solve_order", "choose_gate", "answer"]:
			return true
	return false


func can_open_puzzle(quest_id: String) -> bool:
	if quest_id == "final":
		return can_start_final() and not has_step("final", "order")
	if not has_items(quest_id):
		return false
	if quest_id == "politecnico" and not has_step(quest_id, "outfit"):
		return false
	return not has_step(quest_id, "question" if quest_id == "theatron" else "order")


func can_start_final() -> bool:
	return is_completed("hippies") and is_completed("politecnico") and is_completed("theatron")


func instruction(quest_id: String) -> String:
	var state := get_quest(quest_id)
	if state.is_empty():
		return "Habla con %s para comenzar." % QUESTS[quest_id]["npc"] if quest_id != "final" else "Completa las tres aventuras culturales."
	if str(state.get("status", "")) == "completed":
		return "Misión completada. Historia desbloqueada." if quest_id != "final" else "Insignia: Explorador de Chapinero."
	if quest_id == "politecnico" and not has_step(quest_id, "outfit"):
		return "Viste Formal (hombre) o Lazo blanco (mujer), guarda y vuelve con Polito."
	if not has_items(quest_id):
		return "Busca las pistas de %s en el mapa (%d/%d)." % [QUESTS[quest_id]["npc"], _count_items(quest_id), QUESTS[quest_id]["items"].size()]
	if not has_step(quest_id, "order") and quest_id in ["hippies", "politecnico", "final"]:
		return "Ordena las tarjetas en la Libreta de pistas."
	if quest_id == "theatron" and not has_step(quest_id, "gate"):
		return "Elige la entrada indicada por el boleto reconstruido."
	if quest_id == "theatron" and not has_step(quest_id, "question"):
		return "Responde el acertijo cultural en la Libreta."
	return "Regresa con %s para concluir la misión." % QUESTS[quest_id]["npc"] if quest_id != "final" else "Combina los tres símbolos."


func _count_items(quest_id: String) -> int:
	var result := 0
	for item in QUESTS[quest_id]["items"]:
		if is_collected(quest_id, item):
			result += 1
	return result


func get_dialogue_lines(npc_id: String, fallback: PackedStringArray) -> PackedStringArray:
	var quest_id := str(NPC_QUESTS.get(npc_id, ""))
	if quest_id.is_empty() or is_completed(quest_id):
		return fallback
	if is_loading():
		return PackedStringArray(["Estoy ordenando mis pistas. Vuelve a hablarme en un momento."])
	if get_quest(quest_id).is_empty():
		match quest_id:
			"hippies": return PackedStringArray(["¡Ey, parce! Perdí unos carteles por el parque y alguien mezcló mis mensajes.", "Encuentra ARTE, CALLE y MEMORIA. Ojo: hay un cartel que no es mío.", "Si me ayudas a reconstruir el mensaje, te mostraré una historia especial. Pulsa E para aceptar."])
			"politecnico": return PackedStringArray(["¡Hola! Estoy organizando un archivo de la historia del Poli.", "Para entrar, usa el atuendo apropiado: Formal para el personaje masculino o Lazo blanco para el femenino. Guarda el cambio y regresa.", "Pulsa E para aceptar el desafío."])
			"theatron": return PackedStringArray(["El edificio guarda historias de antes de la fiesta: un pase antiguo quedó dividido.", "Busca sus dos fragmentos cerca de aquí. La pista del pase te ayudará a elegir la entrada correcta.", "Pulsa E para aceptar el misterio."])
	if quest_id == "politecnico" and not has_step(quest_id, "outfit"):
		return PackedStringArray(["Bienvenido al archivo. Veamos si tu atuendo guardado permite entrar.", "Si todavía no sirve, prueba Formal o Lazo blanco en el armario y vuelve."])
	if not has_items(quest_id):
		return PackedStringArray([instruction(quest_id), "Explora el sector y examina los objetos con E. La Libreta de pistas (K) te ayudará."])
	if (quest_id == "theatron" and not has_step(quest_id, "question")) or (quest_id != "theatron" and not has_step(quest_id, "order")):
		return PackedStringArray([instruction(quest_id), "Resuelve el desafío en la Libreta de pistas y vuelve cuando tengas la respuesta."])
	return PackedStringArray(["¡Lo lograste! Uniste las pistas y el lugar cobra otro sentido.", "El arte, la educación y la diversidad construyen la memoria de Chapinero. Ahora podrás conocer la historia de este lugar."])


func on_npc_dialogue_finished(npc_id: String) -> void:
	var quest_id := str(NPC_QUESTS.get(npc_id, ""))
	if quest_id.is_empty() or _loading or is_completed(quest_id):
		return
	if get_quest(quest_id).is_empty():
		send_event(quest_id, "start")
	elif quest_id == "politecnico" and not has_step(quest_id, "outfit"):
		send_event(quest_id, "verify_outfit")
	elif (quest_id == "theatron" and has_step(quest_id, "question")) or (quest_id != "theatron" and has_step(quest_id, "order")):
		send_event(quest_id, "complete")


func send_event(quest_id: String, event_type: String, payload: Dictionary = {}) -> void:
	if not QUESTS.has(quest_id):
		return
	if event_type == "collect" and is_collected(quest_id, str(payload.get("item_id", ""))):
		return
	for action in _pending:
		if action.get("quest_id") == quest_id and action.get("event") == event_type and action.get("payload") == payload:
			return
	_pending.append({"quest_id": quest_id, "event": event_type, "payload": payload.duplicate(true)})
	_save_cache()
	quest_changed.emit(quest_id)
	if event_type == "start":
		notice.emit("Nueva misión: %s" % QUESTS[quest_id]["title"])
	elif event_type == "collect":
		notice.emit("El cartel no pertenece al mensaje. Sigue investigando." if str(payload.get("item_id", "")) == "cartel_falso" else "Has encontrado una pista: %s" % str(payload.get("item_id", "")))
	_flush()


func _refresh() -> void:
	ApiService.cargar_misiones()


func _on_loaded(quests: Array) -> void:
	_loading = false
	_retry.stop()
	_confirmed.clear()
	for value in quests:
		if value is Dictionary and QUESTS.has(str(value.get("quest_id", ""))):
			_confirmed[str(value["quest_id"])] = value.duplicate(true)
	_save_cache()
	loading_changed.emit(false)
	for quest_id in QUESTS:
		quest_changed.emit(quest_id)
	if has_step("final", "order") and not is_completed("final"):
		send_event("final", "complete")
	_flush()


func _on_load_failed(reason: String) -> void:
	_loading = false
	loading_changed.emit(false)
	notice.emit("Misiones sin conexión: %s" % reason)
	_retry.start()
	_flush()


func _flush() -> void:
	if _sending or _pending.is_empty():
		return
	_sending = true
	var action: Dictionary = _pending.front()
	ApiService.registrar_evento_mision(str(action["quest_id"]), str(action["event"]), action["payload"])


func _on_saved(quest_id: String, event_type: String, record: Dictionary) -> void:
	_sending = false
	_confirmed[quest_id] = record.duplicate(true)
	if not _pending.is_empty():
		_pending.pop_front()
	_save_cache()
	quest_changed.emit(quest_id)
	if quest_id == "final" and event_type == "solve_order" and record.get("solved_steps", []).has("order") and str(record.get("status", "")) != "completed":
		send_event("final", "complete")
	if not bool(record.get("changed", false)):
		_flush()
		return
	if event_type == "complete":
		notice.emit("¡Misión completada! Nueva historia desbloqueada." if quest_id != "final" else "Insignia: Explorador de Chapinero")
	elif event_type in ["solve_order", "choose_gate", "answer"]:
		notice.emit("¡Acertijo resuelto!" if event_type != "choose_gate" else "Entrada correcta: la del cine.")
	elif event_type == "verify_outfit":
		notice.emit("Atuendo aprobado. Busca los documentos del archivo.")
	if event_type == "collect" and has_items(quest_id) and can_open_puzzle(quest_id):
		puzzle_ready.emit(quest_id)
	_flush()


func _on_event_failed(quest_id: String, _event_type: String, reason: String, retryable: bool) -> void:
	_sending = false
	notice.emit(reason)
	if retryable:
		_retry.start()
	else:
		if not _pending.is_empty():
			_pending.pop_front()
		_save_cache()
		quest_changed.emit(quest_id)
		_flush()


func _load_cache() -> void:
	var config := ConfigFile.new()
	if config.load(_cache_path()) != OK or str(config.get_value("quests", "player_id", "")) != ApiService.get_player_id():
		return
	var confirmed: Variant = config.get_value("quests", "confirmed", {})
	var pending: Variant = config.get_value("quests", "pending", [])
	if confirmed is Dictionary:
		_confirmed = confirmed
	if pending is Array:
		for value in pending:
			if value is Dictionary:
				_pending.append(value)


func _save_cache() -> void:
	var config := ConfigFile.new()
	config.set_value("quests", "player_id", ApiService.get_player_id())
	config.set_value("quests", "confirmed", _confirmed)
	config.set_value("quests", "pending", _pending)
	if config.save(_cache_path()) != OK:
		push_warning("No se pudo guardar la cola local de misiones")


func _cache_path() -> String:
	var isolated_path := OS.get_environment("VIDEOJUEGO_QUEST_CACHE")
	return isolated_path if not isolated_path.is_empty() else CACHE_PATH
