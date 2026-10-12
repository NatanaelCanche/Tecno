class_name HealthComponent
extends Node

signal took_damage(current_health: int, damage_amount: int)
signal died

@export_range(1, 1000, 1) var max_health: int = 3

var current_health: int
var is_dead: bool = false


func _ready() -> void:
	current_health = max_health


func take_damage(damage_amount: int = 1) -> bool:
	if is_dead or damage_amount <= 0:
		return false

	current_health = maxi(0, current_health - damage_amount)
	took_damage.emit(current_health, damage_amount)
	if current_health == 0:
		is_dead = true
		died.emit()
	return true
