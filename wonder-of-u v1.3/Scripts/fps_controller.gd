extends CharacterBody3D

@export var walk_speed := 5.0
@export var run_speed := 8.0
@export var crouch_speed := 2.5
@export var jump_velocity := 9.0
@export var mouse_sensitivity := 0.1
@export var gravity := 9.8
@export var head_bob_speed := 3.0
@export var inventory_size := 16

var is_running := false
var is_crouching := false
var camera_control_enabled := true
var bobbing_time := 0.0
var standing_height := 1.8
var crouching_height := 1.0

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var inventory_panel = $UI/InventoryPanel
@onready var inventory_grid = $UI/InventoryPanel/InventoryGrid
@onready var inventory_slot_scene = preload("res://Prefabs/InventorySlot.tscn")

func _ready():
	inventory_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_inventory()
	_setup_ui()

func _setup_ui():
	inventory_panel.anchor_left = 0.0
	inventory_panel.anchor_top = 1.0
	inventory_panel.anchor_right = 0.0
	inventory_panel.anchor_bottom = 1.0
	inventory_panel.offset_left = 10
	inventory_panel.offset_bottom = -10

func _setup_inventory():
	for _i in inventory_size:
		var slot = inventory_slot_scene.instantiate()
		var margin_container = MarginContainer.new()
		margin_container.add_child(slot)
		margin_container.add_theme_constant_override("margin_left", 6)
		margin_container.add_theme_constant_override("margin_top", 6)
		inventory_grid.add_child(margin_container)

func _input(event):
	if event.is_action_pressed("toggle_inventory"):
		inventory_panel.visible = !inventory_panel.visible
	
	if event.is_action_pressed("lose_control"):
		camera_control_enabled = !camera_control_enabled
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if camera_control_enabled else Input.MOUSE_MODE_VISIBLE
	
	if camera_control_enabled and event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if camera_control_enabled:
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		is_running = Input.is_action_pressed("run")
		is_crouching = Input.is_action_pressed("crouch")
		var current_speed = run_speed if is_running and not is_crouching else crouch_speed if is_crouching else walk_speed

		head.position.y = lerp(head.position.y, crouching_height if is_crouching else standing_height, delta * 8.0)

		if direction:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
			if is_on_floor():
				_apply_head_bobbing(delta, current_speed)
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)
			velocity.z = move_toward(velocity.z, 0, current_speed)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()
	_apply_push_force()

func _apply_push_force():
	for i in get_slide_collision_count():
		var collider = get_slide_collision(i).get_collider()
		if collider is RigidBody3D:
			collider.apply_central_impulse(-get_slide_collision(i).get_normal() * 2)

func _apply_head_bobbing(delta, speed):
	bobbing_time += delta * (speed * 0.5)
	head.position.y += sin(bobbing_time * head_bob_speed) * (0.075 if is_running else 0.05)
