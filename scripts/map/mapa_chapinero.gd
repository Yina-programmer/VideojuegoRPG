extends Node2D

@onready var calles: TileMapLayer = $Calles


func _ready() -> void:
	crear_limites_del_mapa()


## Crea cuatro paredes invisibles alrededor de todas las celdas usadas del mapa.
## Los limites se calculan en tiempo de ejecucion para seguir funcionando aunque
## el TileMap crezca o cambie de posicion.
func crear_limites_del_mapa() -> void:
	var celdas_usadas := calles.get_used_rect()
	if celdas_usadas.size == Vector2i.ZERO:
		push_warning("No se pudieron crear los limites: el mapa no tiene celdas.")
		return

	var tamano_celda := Vector2(calles.tile_set.tile_size)
	var ultima_celda := celdas_usadas.position + celdas_usadas.size - Vector2i.ONE
	var esquina_superior_izquierda := calles.map_to_local(celdas_usadas.position) - tamano_celda * 0.5
	var esquina_inferior_derecha := calles.map_to_local(ultima_celda) + tamano_celda * 0.5

	# Convertir del espacio local del TileMap al espacio local de esta escena.
	esquina_superior_izquierda = to_local(calles.to_global(esquina_superior_izquierda))
	esquina_inferior_derecha = to_local(calles.to_global(esquina_inferior_derecha))

	var rectangulo_mapa := Rect2(
		esquina_superior_izquierda,
		esquina_inferior_derecha - esquina_superior_izquierda,
	).abs()
	var grosor_pared := maxf(tamano_celda.x, tamano_celda.y)
	var limites := StaticBody2D.new()
	limites.name = "LimitesDelMapa"
	add_child(limites)

	_agregar_pared(
		limites,
		Vector2(rectangulo_mapa.get_center().x, rectangulo_mapa.position.y - grosor_pared * 0.5),
		Vector2(rectangulo_mapa.size.x + grosor_pared * 2.0, grosor_pared),
	)
	_agregar_pared(
		limites,
		Vector2(rectangulo_mapa.get_center().x, rectangulo_mapa.end.y + grosor_pared * 0.5),
		Vector2(rectangulo_mapa.size.x + grosor_pared * 2.0, grosor_pared),
	)
	_agregar_pared(
		limites,
		Vector2(rectangulo_mapa.position.x - grosor_pared * 0.5, rectangulo_mapa.get_center().y),
		Vector2(grosor_pared, rectangulo_mapa.size.y),
	)
	_agregar_pared(
		limites,
		Vector2(rectangulo_mapa.end.x + grosor_pared * 0.5, rectangulo_mapa.get_center().y),
		Vector2(grosor_pared, rectangulo_mapa.size.y),
	)


func _agregar_pared(contenedor: StaticBody2D, posicion: Vector2, tamano: Vector2) -> void:
	var forma := RectangleShape2D.new()
	forma.size = tamano

	var colision := CollisionShape2D.new()
	colision.position = posicion
	colision.shape = forma
	contenedor.add_child(colision)
