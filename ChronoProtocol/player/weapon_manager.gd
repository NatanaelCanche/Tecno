class_name WeaponManager
extends Node

const MAX_WEAPON_SLOTS: int = 4

@export var player_path: NodePath = ^".."
@export var initial_weapon: WeaponData

var _player: Node2D
var _active_weapons: Array[WeaponData] = []
var _fire_cooldowns: Array[float] = []


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		push_error("WeaponManager requires a Node2D at player_path.")
		return
	if initial_weapon == null:
		push_error("WeaponManager requires an initial_weapon.")
		return

	add_weapon(initial_weapon)


func _process(delta: float) -> void:
	for index in range(_fire_cooldowns.size()):
		_fire_cooldowns[index] = maxf(0.0, _fire_cooldowns[index] - delta)


func add_weapon(weapon: WeaponData) -> bool:
	if weapon == null:
		push_error("Cannot add a null weapon.")
		return false
	if _active_weapons.size() >= MAX_WEAPON_SLOTS:
		return false

	_active_weapons.append(weapon)
	_fire_cooldowns.append(0.0)
	return true


func get_active_weapons() -> Array[WeaponData]:
	return _active_weapons.duplicate()


func fire_at(
	target_position: Vector2,
	projectile_count: int = 1,
	spread_degrees: float = 0.0,
	minimum_fire_interval: float = 0.0
) -> bool:
	if _player == null:
		return false
	if projectile_count < 1:
		push_error("Projectile count must be at least one.")
		return false
	if spread_degrees < 0.0 or minimum_fire_interval < 0.0:
		push_error("Spread and minimum fire interval cannot be negative.")
		return false

	var aim_direction := _player.global_position.direction_to(target_position)
	if aim_direction == Vector2.ZERO:
		return false

	var fired := false
	for index in range(_active_weapons.size()):
		if _fire_cooldowns[index] > 0.0:
			continue

		var weapon := _active_weapons[index]
		if weapon.projectile_scene == null:
			push_error("Weapon '%s' has no projectile scene." % weapon.weapon_name)
			continue

		var total_spread := deg_to_rad(spread_degrees)
		var angle_step := total_spread / float(projectile_count - 1) if projectile_count > 1 else 0.0
		var first_angle := -total_spread * 0.5
		var weapon_fired := true

		for projectile_index in range(projectile_count):
			var spread_offset := first_angle + angle_step * projectile_index
			var projectile_direction := aim_direction.rotated(spread_offset)
			var projectile := weapon.projectile_scene.instantiate() as Node2D
			if projectile == null:
				push_error(
					"Weapon '%s' projectile scene must have a Node2D root." % weapon.weapon_name
				)
				weapon_fired = false
				continue

			_player.get_parent().add_child(projectile)
			projectile.global_position = _player.global_position
			projectile.global_rotation = projectile_direction.angle()

		if weapon_fired:
			_fire_cooldowns[index] = maxf(weapon.fire_interval, minimum_fire_interval)
			fired = true

	return fired
