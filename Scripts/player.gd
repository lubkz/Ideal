extends CharacterBody2D

var speed = 180 # Velocidade de movimento

var input_direction = Vector2.ZERO
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _physics_process(delta):
	handle_input()
	move_and_slide()
	update_animation()

func handle_input():
	input_direction = Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		input_direction.y -= 1
	if Input.is_action_pressed("move_down"):
		input_direction.y += 1
	if Input.is_action_pressed("move_left"):
		input_direction.x -= 1
	if Input.is_action_pressed("move_right"):
		input_direction.x += 1

	# Normaliza a direção para que o movimento diagonal não seja mais rápido
	if input_direction.length() > 0:
		input_direction = input_direction.normalized()

	velocity = input_direction * speed

func update_animation():
	var anim_name = "idle_down" # Default
	if input_direction.x != 0 or input_direction.y != 0:
		if abs(input_direction.x) > abs(input_direction.y):
			if input_direction.x > 0:
				anim_name = "walk_right"
				animation_player.play(anim_name)
			else:
				anim_name = "walk_left"
				animation_player.play(anim_name)
		else:
			if input_direction.y > 0:
				anim_name = "walk_down"
				animation_player.play(anim_name)
			else:
				anim_name = "walk_up"
				animation_player.play(anim_name)
	
	# Exemplo de como você chamaria uma animação:
	# $AnimationPlayer.play(anim_name)
	# Certifique-se de ter essas animações configuradas no AnimationPlayer
