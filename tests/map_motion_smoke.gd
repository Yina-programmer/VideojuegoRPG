extends SceneTree


func _initialize() -> void:
	call_deferred("_check_motion")


func _check_motion() -> void:
	var map := (load("res://scenes/map/Mapa_Chapinero.tscn") as PackedScene).instantiate()
	var buildings := map.get_node("EdificiosColision") as StaticBody2D
	map.remove_child(buildings)
	buildings.owner = null
	root.add_child(buildings)
	map.free()

	for scene_path in ["res://scenes/player/player.tscn", "res://scenes/player/player_male.tscn"]:
		var player := (load(scene_path) as PackedScene).instantiate() as CharacterBody2D
		player.set_script(null)
		root.add_child(player)
		await physics_frame
		if not await _can_walk(player, Vector2(-415, -3112), [
			Vector2(-560, -3180), Vector2(-240, -3090), Vector2(-500, -3050),
		]):
			_fail("No se puede alcanzar un documento: %s" % scene_path)
			return
		if not await _can_walk(player, Vector2(-492, -1949), [
			Vector2(-220, -1949), Vector2(-220, -1710), Vector2(-250, -1710),
		]):
			_fail("No se puede alcanzar el cartel ARTE: %s" % scene_path)
			return
		if not await _can_walk(player, Vector2(-492, -1949), [
			Vector2(-1130, -1949), Vector2(-1130, -1490),
			Vector2(-1060, -1490), Vector2(-840, -1180), Vector2(-355, -1250),
		]):
			_fail("No se pueden alcanzar los demás carteles: %s" % scene_path)
			return
		if not await _can_walk(player, Vector2(-4610, 640), [
			Vector2(-4670, 455), Vector2(-4600, 740),
		]):
			_fail("No se pueden alcanzar los boletos: %s" % scene_path)
			return
		player.free()

	buildings.free()
	print("Movimiento: ambos personajes alcanzan documentos, carteles y boletos sin atravesar edificios")
	quit(0)


func _can_walk(player: CharacterBody2D, start: Vector2, targets: Array[Vector2]) -> bool:
	player.global_position = start
	await physics_frame
	for target in targets:
		var collision := player.move_and_collide(target - player.global_position)
		if collision != null:
			print("Bloqueo desde %s hacia %s, contacto %s" % [player.global_position, target, collision.get_position()])
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
