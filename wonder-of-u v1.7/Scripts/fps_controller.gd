extends CharacterBody3D

@export var walk_speed := 5.0
@export var run_speed := 8.0
@export var crouch_speed := 2.5
@export var jump_velocity := 9.0
@export var mouse_sensitivity := 0.1
@export var gravity := 15.0
@export var head_bob_speed := 3.0
@export var inventory_size := 16

var is_running := false
var is_crouching := false
var camera_control_enabled := true
var bobbing_time := 0.0
var standing_height := 1.8
var crouching_height := 1.0
var highlighted_item = null
var inventory = []
var item_data = {
	"CubeItem": {"id": 1, "icon": preload("res://Sprites/Item Sprites/CubeIcon.png")}
}

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var inventory_panel = $UI/InventoryPanel
@onready var inventory_grid = $UI/InventoryPanel/InventoryGrid
@onready var inventory_slot_scene = preload("res://Prefabs/InventorySlot.tscn")
@onready var item_detector = $ItemDetector

func _ready():
	inventory_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_inventory()
	_setup_ui()
	item_detector.body_entered.connect(_on_item_entered)
	item_detector.body_exited.connect(_on_item_exited)

func _setup_ui():
	inventory_panel.anchor_left = 0.0
	inventory_panel.anchor_top = 1.0
	inventory_panel.anchor_right = 0.0
	inventory_panel.anchor_bottom = 1.0
	inventory_panel.offset_left = 10
	inventory_panel.offset_bottom = -10

func _setup_inventory():
	inventory_grid.columns = 4  
	for _i in inventory_size:
		var margin_container = MarginContainer.new()
		margin_container.add_theme_constant_override("margin_left", 6)
		margin_container.add_theme_constant_override("margin_top", 6)
		var slot = inventory_slot_scene.instantiate()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.size_flags_horizontal = Control.SIZE_FILL  # Force consistent size
		slot.size_flags_vertical = Control.SIZE_FILL  # Force consistent size
		margin_container.add_child(slot)
		inventory_grid.add_child(margin_container)
		inventory.append(null)  # Initialize inventory slots

func _on_item_entered(body):
	if not body or not item_data.has(body.name):
		print("[DEBUG] Ignoring non-item:", body.name)
		return

	var player_pos = global_transform.origin
	var item_pos = body.global_transform.origin
	var distance = player_pos.distance_to(item_pos)

	print("[DEBUG] Checking item:", body.name)
	print("[DEBUG] Calculated Distance:", distance)

	if distance > 3.5:
		print("[DEBUG] Ignoring", body.name, "because it's too far away (", distance, "m)")
		return

	highlighted_item = body
	_set_item_highlight(body, true)
	_spawn_highlight_sprite(body)

func _on_item_exited(body):
	if body == highlighted_item:
		_set_item_highlight(body, false)
		_remove_highlight_sprite(body)
		highlighted_item = null

func _set_item_highlight(item, highlight):
	if item.has_method("set_highlight"):
		item.set_highlight(highlight)

func _spawn_highlight_sprite(item):
	if not item.is_inside_tree():
		return

	if item.has_node("HighlightSprite"):
		return

	var highlight_sprite = Sprite3D.new()
	highlight_sprite.name = "HighlightSprite"
	highlight_sprite.texture = preload("res://Sprites/EquipIcon.png")  # Always use EquipIcon.png
	highlight_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	highlight_sprite.pixel_size = 0.008
	highlight_sprite.position = Vector3(0, 1.5, 0)
	item.add_child(highlight_sprite)

func _remove_highlight_sprite(item):
	if item and item.has_node("HighlightSprite"):
		item.get_node("HighlightSprite").queue_free()
		print("[DEBUG] Removed highlight sprite from", item.name)

func _pickup_item():
	if highlighted_item and item_data.has(highlighted_item.name):
		# Find an empty slot
		for i in range(inventory_size):
			if inventory[i] == null:
				inventory[i] = highlighted_item.name
				_update_inventory_ui()
				highlighted_item.queue_free()
				highlighted_item = null
				return
		print("[DEBUG] Inventory full!")
		
func _update_inventory_ui():
	for i in range(inventory_size):
		var margin_container = inventory_grid.get_child(i)  # Get MarginContainer
		var slot = margin_container.get_child(0)  # Get Button inside

		if not slot.has_node("IconTexture"):
			print("[ERROR] Slot", i, "is missing IconTexture!")
			continue  # Skip this slot if it doesn't have the TextureRect

		var texture_rect = slot.get_node("IconTexture")  # Get TextureRect safely

		# 🔒 Lock the button size
		slot.custom_minimum_size = Vector2(64, 64)
		slot.size_flags_horizontal = Control.SIZE_FILL
		slot.size_flags_vertical = Control.SIZE_FILL

		# Set the icon in the TextureRect, NOT the button
		if inventory[i] != null:
			texture_rect.texture = item_data[inventory[i]]["icon"]
		else:
			texture_rect.texture = null  # Clear when slot is empty


func debug_inventory_layout():
	for i in range(inventory_grid.get_child_count()):
		var slot_container = inventory_grid.get_child(i)
		print("[DEBUG] Slot", i, "has margin overrides:",
			  slot_container.get_theme_constant("margin_left"),
			  slot_container.get_theme_constant("margin_top"),
			  slot_container.get_theme_constant("margin_right"),
			  slot_container.get_theme_constant("margin_bottom"))

func _input(event):
	if event.is_action_pressed("toggle_inventory"):
		inventory_panel.visible = !inventory_panel.visible
	
	if event.is_action_pressed("lose_control"):
		camera_control_enabled = !camera_control_enabled
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if camera_control_enabled else Input.MOUSE_MODE_VISIBLE
		
	if event.is_action_pressed("pickup_item"):
		_pickup_item()
	
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
