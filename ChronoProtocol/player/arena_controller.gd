extends Node2D

@onready var arena_layer: TileMapLayer = $TileMapLayer


func _ready() -> void:
	call_deferred("_apply_camera_limits")


func _apply_camera_limits() -> void:
	var camera := get_tree().get_first_node_in_group("arena_camera") as Camera2D
	if camera == null:
		push_error("Arena bounds could not find a Camera2D in the arena_camera group.")
		return

	var used_rect := arena_layer.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		push_error("Cannot set camera limits: the arena TileMapLayer has no used cells.")
		return

	var tile_size := Vector2(arena_layer.tile_set.tile_size)
	var top_left := arena_layer.map_to_local(used_rect.position) - tile_size * 0.5
	var bottom_right := arena_layer.map_to_local(used_rect.end - Vector2i.ONE) + tile_size * 0.5
	var corners: Array[Vector2] = [
		arena_layer.to_global(top_left),
		arena_layer.to_global(Vector2(bottom_right.x, top_left.y)),
		arena_layer.to_global(bottom_right),
		arena_layer.to_global(Vector2(top_left.x, bottom_right.y))
	]

	var min_x := corners[0].x
	var max_x := corners[0].x
	var min_y := corners[0].y
	var max_y := corners[0].y
	for corner in corners:
		min_x = minf(min_x, corner.x)
		max_x = maxf(max_x, corner.x)
		min_y = minf(min_y, corner.y)
		max_y = maxf(max_y, corner.y)

	camera.limit_left = floori(min_x)
	camera.limit_right = ceili(max_x)
	camera.limit_top = floori(min_y)
	camera.limit_bottom = ceili(max_y)
