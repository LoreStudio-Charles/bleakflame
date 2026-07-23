extends Node2D
## Infinite scrolling starfield with parallax layers, generated procedurally —
## stars are hashed from world-cell coordinates so the field is stable and
## endless with no textures or bounds.

const LAYERS := [
	{"parallax": 0.15, "cell": 140.0, "per_cell": 3, "size": 1.0, "brightness": 0.45},
	{"parallax": 0.35, "cell": 180.0, "per_cell": 2, "size": 1.6, "brightness": 0.7},
	{"parallax": 0.65, "cell": 260.0, "per_cell": 1, "size": 2.2, "brightness": 1.0},
]

@onready var camera: Camera2D = get_viewport().get_camera_2d()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if camera == null:
		camera = get_viewport().get_camera_2d()
		if camera == null:
			return
	var view_size := get_viewport_rect().size
	var cam_pos := camera.get_screen_center_position()

	for layer in LAYERS:
		var parallax: float = layer["parallax"]
		var cell: float = layer["cell"]
		# The layer scrolls slower than the world; convert the visible rect
		# into layer-space and stamp stars from hashed cells.
		var layer_origin := cam_pos * parallax
		var top_left := layer_origin - view_size * 0.5
		var first_cell := Vector2i((top_left / cell).floor())
		var cells_x := int(view_size.x / cell) + 2
		var cells_y := int(view_size.y / cell) + 2

		for cy in range(first_cell.y, first_cell.y + cells_y):
			for cx in range(first_cell.x, first_cell.x + cells_x):
				var cell_seed := hash(Vector2i(cx, cy)) + hash(parallax)
				var rng := RandomNumberGenerator.new()
				rng.seed = cell_seed
				for i in layer["per_cell"]:
					var star_layer_pos := Vector2(
						(cx + rng.randf()) * cell,
						(cy + rng.randf()) * cell)
					# Back to screen space: undo the parallax offset.
					var screen_pos := star_layer_pos - layer_origin + view_size * 0.5
					var world_pos := cam_pos - view_size * 0.5 + screen_pos
					var b: float = layer["brightness"] * rng.randf_range(0.5, 1.0)
					draw_circle(world_pos, layer["size"], Color(b, b, min(1.0, b * 1.15)))
