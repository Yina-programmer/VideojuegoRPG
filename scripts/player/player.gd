@tool
extends CharacterBody2D
var speed = 400.0

func _process(_delta):
	var cuerpo = get_node_or_null("visual/body")
	var down = get_node_or_null("visual/hair_down")
	var left = get_node_or_null("visual/hair_left")
	var right = get_node_or_null("visual/hair_right")
	var up = get_node_or_null("visual/hair_up")

	if cuerpo == null or down == null or left == null or right == null or up == null:
		return

	down.visible = false
	left.visible = false
	right.visible = false
	up.visible = false

	match cuerpo.animation:
		"walk_down":
			down.animation = "walk_down"
			down.frame = cuerpo.frame
			down.visible = true

		"walk_left":
			left.animation = "walk_left"
			left.frame = cuerpo.frame
			left.visible = true

		"walk_right":
			right.animation = "walk_right"
			right.frame = cuerpo.frame
			right.visible = true

		"walk_up":
			up.animation = "walk_up"
			up.frame = cuerpo.frame
			up.visible = true

func _physics_process(delta):
	var inputDirection = Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown")
	velocity = speed * inputDirection
	move_and_slide()
