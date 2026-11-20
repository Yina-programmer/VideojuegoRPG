extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tunnel := (load("res://scenes/map/TunelEcosChapinero_Generado.tscn") as PackedScene).instantiate()
	root.add_child(tunnel)
	await process_frame
	await physics_frame
	var activities = tunnel.get_node_or_null("ActividadesUI")
	if activities == null:
		_fail("No se creo la interfaz de actividades")
		return

	# Hippies: orden cronologico 1945 -> 1970 -> actualidad.
	activities.open_hippies_timeline(false)
	for item_id in ["1945", "1970", "actual"]:
		activities._on_hippies_card_pressed(item_id, activities._hippies_buttons[item_id])
	await process_frame
	if not bool(tunnel._solved_secrets["hippies_timeline"]):
		_fail("El minijuego cronologico de Hippies no entrego su cristal")
		return
	activities.close()

	# Pozzetto: antes de 1986 -> 1986 -> memoria actual.
	activities._open_pozzetto_timeline_step()
	for milestone in ["antes", "1986", "memoria"]:
		var button := Button.new()
		button.text = milestone
		activities._on_pozzetto_milestone_pressed(milestone, button)
		button.queue_free()
	await process_frame
	if not bool(tunnel._solved_secrets["pozzetto_archive"]):
		_fail("La linea del tiempo de Pozzetto no encendio su cristal")
		return
	activities.close()

	# Visor Metro Riviera/Theatron: ambas imagenes deben alternarse.
	tunnel._on_tunnel_interaction("metro_theatron", "", "")
	if not activities.is_open() or activities._dual_texture_rect == null or activities._dual_texture_rect.texture == null:
		_fail("El visor Metro Riviera/Theatron no abrio su primera imagen")
		return
	activities._toggle_dual_comparison()
	if not activities._dual_showing_second or activities._dual_texture_rect.texture == null:
		_fail("El visor Metro Riviera/Theatron no cambio a Theatron")
		return
	activities.close()

	# KINDER: valida la entrega real del cristal al finalizar la ultima ronda.
	activities.open_kinder_lights(false)
	activities._kinder_round = 3
	activities._kinder_sequence.clear()
	activities._kinder_sequence.append(0)
	activities._kinder_input_index = 0
	activities._kinder_accepting = true
	activities._on_kinder_pad_pressed(0)
	await process_frame
	if not bool(tunnel._solved_secrets["kinder_lights"]):
		_fail("La consola KINDER no activo el modo Supernova")
		return
	activities.close()

	# Terror: la grieta secreta completa el cuarto eco y habilita la puerta final.
	tunnel._on_tunnel_interaction("terror_secret_crack", "", "")
	if not bool(tunnel._solved_secrets["terror_secret"]):
		_fail("El pasadizo de terror no revelo su cristal")
		return
	if tunnel._count_solved_secrets() != 4:
		_fail("El pedestal final no conto los cuatro ecos")
		return
	tunnel._on_tunnel_interaction("final_gate", "", "")
	if not tunnel.notice_panel.visible or "4 / 4" not in tunnel.notice_title.text:
		_fail("La puerta final no respondio al progreso completo")
		return

	tunnel._shutdown_ambient_audio()
	tunnel.queue_free()
	await process_frame
	print("TUNNEL_ACTIVITIES: Hippies, Pozzetto, Metro/Theatron, KINDER, terror y puerta final verificados")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
