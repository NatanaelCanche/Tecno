class_name Enemy
extends CharacterBody2D

@export var speed: float = 150.0
@export var bullet_scene: PackedScene
@export var fragment_scene: PackedScene
@export_range(1, 100, 1) var fragment_drop_amount: int = 1
@export_range(0.1, 10.0, 0.1) var fire_interval: float = 1.5

@onready var hit_flash: HitFlashComponent = $HitFlashComponent
@onready var shoot_timer: Timer = $ShootTimer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: Variant = $HealthComponent

var _is_dead: bool = false


func _ready() -> void:
	if bullet_scene == null:
		push_error("Enemy requires a bullet_scene to fire.")
	shoot_timer.wait_time = fire_interval
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	shoot_timer.start()
	health_component.took_damage.connect(_on_health_took_damage)
	health_component.died.connect(_on_health_died)
	sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(_delta: float) -> void:
	if _is_dead:
		return

	velocity = Vector2.ZERO
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	sprite.flip_h = player.global_position.x < global_position.x
	if sprite.animation != &"hurt" or not sprite.is_playing():
		sprite.play(&"idle")


func _on_shoot_timer_timeout() -> void:
	if _is_dead or bullet_scene == null:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var bullet := bullet_scene.instantiate() as Node2D
	if bullet == null:
		push_error("Enemy bullet_scene must have a Node2D root.")
		return

	get_parent().add_child(bullet)
	bullet.global_position = global_position
	bullet.look_at(player.global_position)


func _on_health_took_damage(_current_health: int, _damage_amount: int) -> void:
	if _is_dead:
		return

	hit_flash.flash()
	sprite.play(&"hurt")


func _on_health_died() -> void:
	_is_dead = true
	remove_from_group("enemy")
	shoot_timer.stop()
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	_spawn_fragment()
	var main := get_tree().get_first_node_in_group("main")
	if main != null:
		main.register_enemy_kill()
	sprite.play(&"death")


func _spawn_fragment() -> void:
	call_deferred("_spawn_fragment_deferred", global_position)


func _spawn_fragment_deferred(spawn_position: Vector2) -> void:
	if fragment_scene == null:
		push_error("Enemy requires a fragment_scene to drop core fragments.")
		return

	var fragment := fragment_scene.instantiate() as Node2D
	if fragment == null:
		push_error("Enemy fragment_scene must have a Node2D root.")
		return

	fragment.set_amount(fragment_drop_amount)
	get_parent().add_child(fragment)
	fragment.set_spawn_position(spawn_position)


func _on_animation_finished() -> void:
	if sprite.animation == &"death":
		queue_free()
	elif sprite.animation == &"hurt" and not _is_dead:
		sprite.play(&"idle")
