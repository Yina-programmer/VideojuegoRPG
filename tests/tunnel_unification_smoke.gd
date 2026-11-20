extends SceneTree

const OFFICIAL_SCENE := "res://scenes/map/TunelEcosChapinero_Generado.tscn"
const DUPLICATE_SCENE := "res://scenes/map/TunelEcosChapinero_Antigravity.tscn"
const OFFICIAL_SCRIPT := "res://scripts/map/tunel_ecos_chapinero_generado.gd"
const DUPLICATE_SCRIPT := "res://scripts/map/tunel_ecos_chapinero_antigravity.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(OFFICIAL_SCENE) as PackedScene
	if packed == null:
		_fail("No se pudo cargar la escena oficial")
		return
	var tunnel := packed.instantiate()
	if tunnel.get_script() == null or tunnel.get_script().resource_path != OFFICIAL_SCRIPT:
		_fail("La escena oficial no usa su controlador canonico")
		return

	var details := tunnel.get_node("Detalles") as TileMapLayer
	var manual_cell := Vector2i(15, 5)
	details.set_cell(manual_cell, 4, Vector2i(0, 0))
	root.add_child(tunnel)
	await process_frame
	await physics_frame
	if details.get_cell_source_id(manual_cell) != 4:
		_fail("El controlador borro una decoracion manual del TileMap")
		return

	for required_path in [
		"ElementosAntigravity/CorredorChapines/PosterChapinero",
		"ElementosAntigravity/Hippies/Tocadiscos",
		"ElementosAntigravity/ArchivoPozzetto/MesaProyector",
		"ElementosAntigravity/PuertasCulturalesExtras/PlacaMetroTheatron",
		"ElementosAntigravity/KinderExtras/BrilloSecretoKinder",
		"ElementosAntigravity/TerrorExtras/EspejoInquietante",
		"ElementosAntigravity/CamaraFinalExtras/CristalHippies",
		"ElementosAntigravity/CamaraFinalExtras/CristalPozzetto",
		"ElementosAntigravity/CamaraFinalExtras/CristalKinder",
		"ElementosAntigravity/CamaraFinalExtras/CristalTerror",
	]:
		if tunnel.get_node_or_null(required_path) == null:
			_fail("Falta contenido integrado: %s" % required_path)
			return

	var expected_interactions := {
		"chapinero_origin": false,
		"hippies_turntable": false,
		"hippies_mural": false,
		"hippies_timeline": false,
		"pozzetto_projector": false,
		"pozzetto_calendar": false,
		"pozzetto_tv": false,
		"metro_theatron": false,
		"kinder_lights": false,
		"kinder_secret": false,
		"terror_mirror": false,
		"terror_secret_crack": false,
		"final_gate": false,
	}
	for candidate in get_nodes_in_group("tunnel_interactable"):
		var interaction_id := str(candidate.get("interaction_id"))
		if expected_interactions.has(interaction_id):
			expected_interactions[interaction_id] = true
	for interaction_id in expected_interactions:
		if not bool(expected_interactions[interaction_id]):
			_fail("Falta la interaccion %s" % interaction_id)
			return

	var activities := tunnel.get_node_or_null("ActividadesUI")
	if activities == null or not activities.has_method("open_hippies_timeline") or not activities.has_method("open_pozzetto_projector") or not activities.has_method("open_kinder_lights"):
		_fail("No se integro el modulo de actividades")
		return
	if tunnel.get_node_or_null("UI/SectionPanel/Margin/Content/ProgressLabel") == null:
		_fail("Falta el contador de cuatro ecos")
		return
	if tunnel.get_node_or_null("player") == null:
		_fail("La escena oficial no crea el personaje seleccionado")
		return

	var allow_duplicate_during_migration := OS.get_environment("VIDEOJUEGO_ALLOW_TUNNEL_DUPLICATE") == "1"
	if not allow_duplicate_during_migration and (ResourceLoader.exists(DUPLICATE_SCENE) or FileAccess.file_exists(DUPLICATE_SCRIPT)):
		_fail("Aun permanecen archivos activos duplicados de Antigravity")
		return

	tunnel.call("_shutdown_ambient_audio")
	tunnel.queue_free()
	await process_frame
	print("TUNNEL_UNIFICATION: escena oficial, actividades, decoracion manual y controlador unico verificados")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
