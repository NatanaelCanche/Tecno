class_name Player
extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)

@export var speed: float = 300.0
@export var acceleration: float = 14.0
@export var friction: float = 12.0
@export var max_health: int = 10
var current_health: int = 10
var has_shotgun: bool = false
var has_grenade_launcher: bool = false
var unlocked_weapons: Array[String] = ["pistol"]
var current_weapon_index: int = 0
var current_weapon: String = "pistol"
@export var dash_speed: float = 900.0
@export var dash_duration: float = 0.18
@export var dash_invulnerability_duration: float = 0.25
@export var dash_cooldown: float = 0.8
var core_fragments: int = 0
@onready var anim_sprite = $AnimatedSprite2D
@onready var hit_flash: HitFlashComponent = $HitFlashComponent
@onready var weapon_manager: WeaponManager = $WeaponManager

var _dash_direction := Vector2.ZERO
var _dash_time_remaining: float = 0.0
var _dash_cooldown_remaining: float = 0.0
var _invulnerability_time_remaining: float = 0.0
var _trail_time_remaining: float = 0.0


func _ready() -> void:
	current_health = clampi(current_health, 0, max_health)
	var health_container: HBoxContainer = $CanvasLayer/HBoxContainer
	health_changed.connect(health_container.update_health)
	health_changed.emit(current_health, max_health)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var direction := 0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			direction = 1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			direction = -1

		if direction != 0:
			if unlocked_weapons.is_empty():
				push_error("Cannot switch weapons: no weapons are unlocked.")
				return
			current_weapon_index = posmod(
				current_weapon_index + direction,
				unlocked_weapons.size()
			)
			current_weapon = unlocked_weapons[current_weapon_index]
			return

	if not event.is_action_pressed("shoot"):
		return

	var fired := false
	if current_weapon == "shotgun":
		fired = weapon_manager.fire_at(get_global_mouse_position(), 5, 45.0, 0.8)
	else:
		fired = weapon_manager.fire_at(get_global_mouse_position())
	if fired:
		anim_sprite.play("shoot")


func _physics_process(delta: float) -> void:
	_dash_cooldown_remaining = maxf(0.0, _dash_cooldown_remaining - delta)
	_invulnerability_time_remaining = maxf(0.0, _invulnerability_time_remaining - delta)

	var input_direction: Vector2 = _get_move_direction()
	if Input.is_action_just_pressed("dash") and _dash_cooldown_remaining == 0.0:
		_start_dash(input_direction)

	if _dash_time_remaining > 0.0:
		velocity = _dash_direction * dash_speed
		move_and_slide()
		_dash_time_remaining = maxf(0.0, _dash_time_remaining - delta)
		_trail_time_remaining -= delta
		if _trail_time_remaining <= 0.0:
			_spawn_dash_trail()
			_trail_time_remaining = 0.04
		if _dash_time_remaining == 0.0:
			velocity = _dash_direction * speed
		_update_animation()
		return

	var weight: float

	if input_direction != Vector2.ZERO:
		weight = 1.0 - exp(-acceleration * delta)
		velocity = velocity.lerp(input_direction * speed, weight)
	else:
		weight = 1.0 - exp(-friction * delta)
		velocity = velocity.lerp(Vector2.ZERO, weight)

	move_and_slide()

	_update_animation()


func _start_dash(input_direction: Vector2) -> void:
	_dash_direction = input_direction
	if _dash_direction == Vector2.ZERO:
		_dash_direction = velocity.normalized()
	if _dash_direction == Vector2.ZERO:
		_dash_direction = get_global_mouse_position() - global_position
	_dash_direction = _dash_direction.normalized()
	_dash_time_remaining = dash_duration
	_dash_cooldown_remaining = dash_cooldown
	_invulnerability_time_remaining = dash_invulnerability_duration
	_trail_time_remaining = 0.0


func _spawn_dash_trail() -> void:
	var trail := anim_sprite.duplicate() as AnimatedSprite2D
	trail.modulate = Color(0.35, 0.85, 1.0, 0.5)
	trail.z_index = -1
	trail.stop()
	get_parent().add_child(trail)
	trail.global_transform = anim_sprite.global_transform
	var tween := create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.16)
	tween.tween_callback(trail.queue_free)


func _update_animation() -> void:
	var facing_target := get_global_mouse_position()
	anim_sprite.flip_h = facing_target.x < global_position.x
	if anim_sprite.animation == "shoot" and anim_sprite.is_playing():
		return

	if velocity.length() > 0:
		anim_sprite.play("run")
	else:
		anim_sprite.play("idle")


func _get_move_direction() -> Vector2:
	var direction := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	if Input.is_physical_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		direction.y += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		direction.y -= 1.0

	return direction.normalized()


func take_damage() -> void:
	if _invulnerability_time_remaining > 0.0 or current_health <= 0:
		return

	current_health = maxi(0, current_health - 1)
	health_changed.emit(current_health, max_health)
	hit_flash.flash()
	var screen_shake := get_tree().get_first_node_in_group("screen_shake")
	if screen_shake != null:
		screen_shake.shake()
	if current_health <= 0:
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.show_game_over()


func add_fragment(amount: int) -> void:
	if amount <= 0:
		push_error("Fragment amount must be greater than zero.")
		return

	core_fragments += amount
