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
var bobbing_intensity := 0.05

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

	# Set InventoryPanel position to bottom-left with a 5px offset
	inventory_panel.anchor_left = 0.0
	inventory_panel.anchor_top = 1.0
	inventory_panel.anchor_right = 0.0
	inventory_panel.anchor_bottom = 1.0
	inventory_panel.offset_left = 10       # 10px from the left
	inventory_panel.offset_bottom = -10   # 10px above the bottom


func _setup_inventory():
	for i in range(inventory_size):
		# Instantiate the inventory slot
		var slot = inventory_slot_scene.instantiate()

		# Create a MarginContainer dynamically
		var margin_container = MarginContainer.new()
		margin_container.add_child(slot)

		# Set the margin offsets
		margin_container.add_theme_constant_override("margin_left", 6)
		margin_container.add_theme_constant_override("margin_top", 6)

		# Add to the grid
		inventory_grid.add_child(margin_container)


func _input(event):
	if event.is_action_pressed("toggle_inventory"):
		inventory_panel.visible = !inventory_panel.visible
	
	if Input.is_action_just_pressed("lose_control"):
		camera_control_enabled = !camera_control_enabled
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if camera_control_enabled else Input.MOUSE_MODE_VISIBLE

	if camera_control_enabled and event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta):
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Movement
	if camera_control_enabled:
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		is_running = Input.is_action_pressed("run")
		is_crouching = Input.is_action_pressed("crouch")

		var current_speed = walk_speed
		if is_running and not is_crouching:
			current_speed = run_speed
		elif is_crouching:
			current_speed = crouch_speed

		# Adjust camera height for crouching
		var target_height = crouching_height if is_crouching else standing_height
		head.position.y = lerp(head.position.y, target_height, delta * 8.0)

		if direction:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
			if is_on_floor():
				_apply_head_bobbing(delta, current_speed)
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)
			velocity.z = move_toward(velocity.z, 0, current_speed)

	# Jumping
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()

func _apply_head_bobbing(delta, speed):
	bobbing_time += delta * (speed * 0.5)
	var intensity = bobbing_intensity * (1.5 if is_running else 1.0)
	head.position.y += sin(bobbing_time * head_bob_speed) * intensity
