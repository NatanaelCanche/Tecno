class_name Bullet
extends Area2D

@export var speed: float = 600.0


func _ready() -> void:
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy_hurtbox"):
		return

	var health_component: Variant = area.get_parent().get_node_or_null("HealthComponent")
	if health_component == null or not health_component.take_damage():
		return

	queue_free()


func _on_screen_exited() -> void:
	queue_free()
