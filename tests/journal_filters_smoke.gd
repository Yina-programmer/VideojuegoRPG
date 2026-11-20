extends SceneTree


func _initialize() -> void:
	call_deferred("_check_filters")


func _check_filters() -> void:
	if OS.get_environment("VIDEOJUEGO_TEST_PLAYER_ID").is_empty() \
			or OS.get_environment("VIDEOJUEGO_API_BASE_URL") != "http://127.0.0.1:1" \
			or OS.get_environment("VIDEOJUEGO_EXPLORATION_CACHE").is_empty():
		_fail("Esta prueba requiere UUID y caché aislados y la API deshabilitada")
		return
	var progress := root.get_node("ProgressManager")
	progress.register_places([
		{"place_id": "hippies", "name": "Parque de los Hippies", "category": "Cultura urbana"},
		{"place_id": "politecnico", "name": "Politécnico Grancolombiano", "category": "Educación"},
		{"place_id": "theatron", "name": "Theatron", "category": "Vida nocturna"},
	])
	progress.record_visit("hippies")
	progress.record_discovery("politecnico")

	var journal := (load("res://scenes/ui/ExplorationJournal.tscn") as PackedScene).instantiate()
	root.add_child(journal)
	await process_frame
	var cards := journal.get_node("Root/Window/Margin/Content/CardsScroll/CardsFlow")
	var search := journal.get_node("Root/Window/Margin/Content/SearchFilters/SearchInput") as LineEdit
	var categories := journal.get_node("Root/Window/Margin/Content/SearchFilters/CategoryFilter") as OptionButton
	var states := journal.get_node("Root/Window/Margin/Content/SearchFilters/StateFilter") as OptionButton
	if not _expect_cards(cards, 3, "Todos los lugares"):
		return

	search.text = "hippies"
	search.text_changed.emit(search.text)
	if not _expect_cards(cards, 1, "Búsqueda por nombre"):
		return
	search.text = ""
	search.text_changed.emit(search.text)

	var education_index := -1
	for index in range(categories.item_count):
		if categories.get_item_text(index) == "Educación":
			education_index = index
	if education_index < 0:
		_fail("No aparece la categoría Educación")
		return
	categories.select(education_index)
	categories.item_selected.emit(education_index)
	if not _expect_cards(cards, 1, "Filtro por categoría"):
		return

	categories.select(0)
	categories.item_selected.emit(0)
	states.select(2)
	states.item_selected.emit(2)
	if not _expect_cards(cards, 1, "Filtro de descubiertos"):
		return
	states.select(1)
	states.item_selected.emit(1)
	if not _expect_cards(cards, 2, "Filtro de pendientes"):
		return

	journal.free()
	print("Bitácora: búsqueda, categoría y estados filtran correctamente")
	quit(0)


func _expect_cards(cards: Node, expected: int, description: String) -> bool:
	if cards.get_child_count() == expected:
		return true
	_fail("%s: se esperaban %d tarjetas y hay %d" % [description, expected, cards.get_child_count()])
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
