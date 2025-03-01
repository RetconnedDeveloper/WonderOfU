extends Node

@export var lighting_intensity: float = 1.0  # 0.0 (dark) to 1.0 (bright)

@onready var world_environment: WorldEnvironment = $".."  # Reference WorldEnvironment node

func _process(_delta):
	if world_environment and world_environment.environment:
		var env: Environment = world_environment.environment  # Get the Environment resource

		# Ensure the background is Sky and uses a ProceduralSkyMaterial
		if env.background_mode == Environment.BG_SKY and env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var sky_material: ProceduralSkyMaterial = env.sky.sky_material
			# Adjust only the brightness without modifying anything else
			sky_material.energy_multiplier = lighting_intensity
