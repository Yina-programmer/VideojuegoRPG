extends CharacterBody2D

@onready var body: AnimatedSprite2D = $visual/body
@onready var hair_down: AnimatedSprite2D = $visual/hair_down
@onready var hair_left: AnimatedSprite2D = $visual/hair_left
@onready var hair_right: AnimatedSprite2D = $visual/hair_right
@onready var hair_up: AnimatedSprite2D = $visual/hair_up
@onready var visual: Node2D = $visual


var speed = 400.0
var lastDirection = "down"

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


func _physics_process(_delta):
	getInput()
	move_and_slide()

func getInput():
	var inputDirection = Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown")
	if inputDirection == Vector2.ZERO:
		velocity = Vector2.ZERO
		updateAnimation("walk")
		return


	if abs(inputDirection.x) > abs(inputDirection.y):
		#Movimineto horizontal
		if inputDirection.x > 0:
			lastDirection = "right"
		else:
			lastDirection = "left"
	else:
		if inputDirection.y > 0:
			lastDirection = "down"
		else:
			lastDirection = "up"
	velocity = speed * inputDirection
	
	updateAnimation("walk")

func updateAnimation (state):
	body.play(state + "_" + lastDirection)
