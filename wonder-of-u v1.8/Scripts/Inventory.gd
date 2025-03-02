extends Node

@export var inventory_size := 16
var highlighted_item = null
var inventory = []
var item_data = {
	"CubeItem": {"id": 1, "icon": preload("res://Sprites/Item Sprites/CubeIcon.png")}
}

@onready var inventory_panel = $"../UI/InventoryPanel"
@onready var inventory_grid = $"../UI/InventoryPanel/InventoryGrid"
@onready var inventory_slot_scene = preload("res://Prefabs/InventorySlot.tscn")

func _ready():
	inventory_panel.visible = false
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
	inventory_grid.columns = 4  
	for _i in inventory_size:
		var margin_container = MarginContainer.new()
		margin_container.add_theme_constant_override("margin_left", 6)
		margin_container.add_theme_constant_override("margin_top", 6)
		var slot = inventory_slot_scene.instantiate()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.size_flags_horizontal = Control.SIZE_FILL
		slot.size_flags_vertical = Control.SIZE_FILL
		margin_container.add_child(slot)
		inventory_grid.add_child(margin_container)
		inventory.append(null)

func _on_item_entered(body):
	if not body or not item_data.has(body.name):
		print("[DEBUG] Ignoring non-item:", body.name)
		return

	var player_pos = $"..".global_transform.origin
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
	highlight_sprite.texture = preload("res://Sprites/EquipIcon.png")
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
		var margin_container = inventory_grid.get_child(i)
		var slot = margin_container.get_child(0)

		if not slot.has_node("IconTexture"):
			print("[ERROR] Slot", i, "is missing IconTexture!")
			continue

		var texture_rect = slot.get_node("IconTexture")

		slot.custom_minimum_size = Vector2(64, 64)
		slot.size_flags_horizontal = Control.SIZE_FILL
		slot.size_flags_vertical = Control.SIZE_FILL

		if inventory[i] != null:
			texture_rect.texture = item_data[inventory[i]]["icon"]
		else:
			texture_rect.texture = null

func toggle_inventory():
	inventory_panel.visible = !inventory_panel.visible
