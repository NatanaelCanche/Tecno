class_name Boss
extends CharacterBody2D

enum BossState { IDLE, LASER, MISSILES, SWARM, SLAM }

signal defeated

@export_range(1, 5000, 1) var max_health: int = 500
@export_range(0.1, 10.0, 0.1) var laser_speed: float = 1.2
@export_range(1.0, 3000.0, 1.0) var slam_speed: float = 900.0
@export_range(0.1, 10.0, 0.1) var attack_interval_min: float = 3.0
@export_range(0.1, 10.0, 0.1) var attack_interval_max: float = 4.0
@export var missile_scene: PackedScene
@export var spider_scene: PackedScene

var current_state: BossState = BossState.IDLE
var _slam_target: Vector2
var _attack_time_remaining: float = 0.0
var _laser_damage_cooldown: float = 0.0
var _is_defeated: bool = false
var _flash_tween: Tween

@onready var laser_pivot: Node2D = $LaserPivot
@onready var laser_hitbox: Area2D = $LaserPivot/LaserHitbox
@onready var attack_timer: Timer = $AttackTimer
@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	health_component.max_health = max_health
	health_component.current_health = max_health
	health_component.took_damage.connect(_on_health_took_damage)
	health_component.died.connect(_on_health_died)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	laser_pivot.hide()
	laser_hitbox.body_entered.connect(_on_laser_body_entered)
	_start_attack_timer()


func _physics_process(delta: float) -> void:
	if _is_defeated:
		return

	_laser_damage_cooldown = maxf(0.0, _laser_damage_cooldown - delta)
	match current_state:
		BossState.LASER:
			laser_pivot.rotation += laser_speed * delta
			_damage_laser_overlaps()
			_attack_time_remaining -= delta
			if _attack_time_remaining <= 0.0:
				_return_to_idle()
		BossState.SLAM:
			var distance_to_target := global_position.distance_to(_slam_target)
			if distance_to_target <= slam_speed * delta:
				global_position = _slam_target
				velocity = Vector2.ZERO
				_return_to_idle()
			else:
				velocity = global_position.direction_to(_slam_target) * slam_speed
				move_and_slide()
		_:
			velocity = Vector2.ZERO


func _start_attack_timer() -> void:
	attack_timer.wait_time = randf_range(
		minf(attack_interval_min, attack_interval_max),
		maxf(attack_interval_min, attack_interval_max)
	)
	attack_timer.start()


func _on_attack_timer_timeout() -> void:
	if _is_defeated or current_state != BossState.IDLE:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_error("Boss cannot attack: no player exists in the player group.")
		_start_attack_timer()
		return

	var attack_states: Array[BossState] = [
		BossState.LASER,
		BossState.MISSILES,
		BossState.SWARM,
		BossState.SLAM
	]
	match attack_states.pick_random():
		BossState.LASER:
			_start_laser(player)
		BossState.MISSILES:
			_fire_missiles(player)
		BossState.SWARM:
			_spawn_swarm()
		BossState.SLAM:
			_start_slam(player)


func _start_laser(player: Node2D) -> void:
	current_state = BossState.LASER
	_attack_time_remaining = 3.0
	_laser_damage_cooldown = 0.0
	laser_pivot.global_rotation = global_position.direction_to(player.global_position).angle()
	laser_pivot.show()


func _fire_missiles(player: Node2D) -> void:
	current_state = BossState.MISSILES
	if missile_scene == null:
		push_error("Boss requires missile_scene for the MISSILES attack.")
		_return_to_idle()
		return

	for index in range(3):
		var spawn_offset := Vector2.RIGHT.rotated(TAU * float(index) / 3.0) * 90.0
		var missile := missile_scene.instantiate() as Node2D
		if missile == null:
			push_error("Boss missile_scene must have a Node2D root.")
			continue
		get_parent().add_child(missile)
		missile.global_position = global_position + spawn_offset
		missile.look_at(player.global_position)
	_return_to_idle()


func _spawn_swarm() -> void:
	current_state = BossState.SWARM
	if spider_scene == null:
		push_error("Boss requires spider_scene for the SWARM attack.")
		_return_to_idle()
		return

	for _index in range(5):
		var spider := spider_scene.instantiate() as Node2D
		if spider == null:
			push_error("Boss spider_scene must have a Node2D root.")
			continue
		get_parent().add_child(spider)
		spider.global_position = global_position + Vector2(
			randf_range(-100.0, 100.0),
			randf_range(-100.0, 100.0)
		)
	_return_to_idle()


func _start_slam(player: Node2D) -> void:
	current_state = BossState.SLAM
	_slam_target = player.global_position


func _damage_laser_overlaps() -> void:
	if _laser_damage_cooldown > 0.0:
		return
	for body in laser_hitbox.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage()
			_laser_damage_cooldown = 0.5
			return


func _on_laser_body_entered(body: Node2D) -> void:
	if current_state == BossState.LASER and body.is_in_group("player"):
		_damage_laser_overlaps()


func _return_to_idle() -> void:
	if current_state == BossState.LASER:
		laser_pivot.hide()
	velocity = Vector2.ZERO
	current_state = BossState.IDLE
	_start_attack_timer()


func _on_health_took_damage(_current_health: int, _damage_amount: int) -> void:
	if _is_defeated:
		return
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()
	sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func _on_health_died() -> void:
	_is_defeated = true
	attack_timer.stop()
	laser_pivot.hide()
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	defeated.emit()
	queue_free()
