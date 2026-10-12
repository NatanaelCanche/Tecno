extends Area2D

@export var amount: int = 1
@export var float_amplitude: float = 6.0
@export var float_frequency: float = 2.5
@export var magnet_speed: float = 1200.0

var _elapsed_time: float = 0.0
var _base_y: float
var _collected: bool = false
var _magnet_target: Node2D


func _ready() -> void:
	_base_y = position.y
	add_to_group("fragments")
	body_entered.connect(_on_body_entered)
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.closing_magnet_active:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			activate_closing_magnet(player)


func _process(delta: float) -> void:
	if _collected:
		return

	if is_instance_valid(_magnet_target):
		global_position = global_position.move_toward(
			_magnet_target.global_position,
			magnet_speed * delta
		)
		if global_position.distance_squared_to(_magnet_target.global_position) <= 400.0:
			_collect(_magnet_target)
		return

	_elapsed_time += delta
	position.y = _base_y + sin(_elapsed_time * float_frequency) * float_amplitude


func activate_closing_magnet(target: Node2D) -> void:
	_magnet_target = target
	monitoring = false
	monitorable = false


func set_amount(value: int) -> void:
	if value <= 0:
		push_error("Fragment amount must be greater than zero.")
		return
	amount = value


func set_spawn_position(world_position: Vector2) -> void:
	global_position = world_position
	_base_y = position.y


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group("player"):
		return

	_collect(body)


func _collect(player: Node2D) -> void:
	if _collected:
		return
	if not player.has_method("add_fragment"):
		push_error("Player body must implement add_fragment(amount).")
		return

	_collected = true
	remove_from_group("fragments")
	player.add_fragment(amount)
	queue_free()
