extends HBoxContainer

func update_health(current_health: int, max_health: int) -> void:
	var cells := get_children()
	for index in range(cells.size()):
		var cell := cells[index] as TextureRect
		if cell == null:
			push_error("Health UI children must all be TextureRect nodes.")
			continue
		if index < current_health:
			cell.visible = true
			cell.modulate.a = 1.0
		elif index < max_health:
			cell.visible = true
			cell.modulate.a = 0.3
		else:
			cell.visible = false
