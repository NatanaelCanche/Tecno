extends Node2D

signal wave_ended

const SHOP_TRANSITION_DELAY: float = 2.5
const KILLS_PER_WAVE: Array[int] = [15, 20, 30, 50, 60]
const SHOP_COSTS: Array[int] = [5, 8, 10, 12, 15]

@export var enemy_scene: PackedScene
@export var minion_scene: PackedScene
@export var boss_scene: PackedScene
@onready var score_label = $UI/ScoreLabel
@onready var game_over_panel = $UI/GameOverPanel
@onready var final_score_label = $UI/GameOverPanel/FinalScoreLabel
@onready var wave_time_label: Label = $UI/WaveTimeLabel
@onready var shop_panel: ColorRect = $UI/ShopPanel
@onready var shop_fragments_label: Label = $UI/ShopPanel/ShopFragmentsLabel
@onready var boss_warning_label: Label = $UI/BossWarningLabel
@onready var shop_status_label: Label = $UI/ShopPanel/ShopStatusLabel
var spawn_timer: Timer
var score: int = 0
var closing_magnet_active: bool = false
var _wave_has_ended: bool = false
var current_wave: int = 1
var enemies_to_kill: int = 15
var enemies_killed: int = 0

func _ready() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 1.5
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_spawn_enemy)
	$UI/GameOverPanel/RetryButton.pressed.connect(_on_retry_pressed)
	$UI/ShopPanel/ShopTabs/Clínica/RepairButton.pressed.connect(_on_shop_purchase_pressed.bind(0))
	$UI/ShopPanel/ShopTabs/Clínica/OverdriveButton.pressed.connect(_on_shop_purchase_pressed.bind(1))
	$UI/ShopPanel/ShopTabs/Clínica/ExtraBatteryButton.pressed.connect(_on_shop_purchase_pressed.bind(2))
	$UI/ShopPanel/ShopTabs/Armería/ShotgunButton.pressed.connect(_on_shop_purchase_pressed.bind(3))
	$UI/ShopPanel/ShopTabs/Armería/GrenadeLauncherButton.pressed.connect(_on_shop_purchase_pressed.bind(4))
	$UI/ShopPanel/ContinueButton.pressed.connect(_on_continue_pressed)
	wave_ended.connect(_on_wave_ended)
	enemies_to_kill = KILLS_PER_WAVE[current_wave - 1]
	_update_wave_progress()
	spawn_timer.start()

func add_score(points: int) -> void:
	score += points
	score_label.text = str(score)
	spawn_timer.wait_time = max(0.3, spawn_timer.wait_time - 0.05)


func register_enemy_kill(points: int = 10) -> void:
	if _wave_has_ended:
		return

	add_score(points)
	enemies_killed += 1
	_update_wave_progress()
	if enemies_killed >= enemies_to_kill:
		end_wave()


func show_game_over() -> void:
	get_tree().paused = true
	if final_score_label:
		final_score_label.text = "Score: %d" % score
	game_over_panel.show()

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func end_wave() -> void:
	if _wave_has_ended:
		return

	_wave_has_ended = true
	spawn_timer.stop()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()
	call_deferred("_finish_wave_transition")


func _finish_wave_transition() -> void:
	_update_wave_progress()
	activate_closing_magnet()
	await get_tree().create_timer(SHOP_TRANSITION_DELAY).timeout
	if current_wave == KILLS_PER_WAVE.size():
		spawn_boss()
	else:
		wave_ended.emit()


func activate_closing_magnet() -> void:
	closing_magnet_active = true
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_error("Cannot activate closing magnet: no player in the player group.")
		return

	for node in get_tree().get_nodes_in_group("fragments"):
		var fragment := node as Node
		if fragment.has_method("activate_closing_magnet"):
			fragment.activate_closing_magnet(player)


func _on_wave_ended() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		push_error("Cannot show shop: no Player exists in the player group.")
		return

	shop_fragments_label.text = "Core Fragments: %d" % player.core_fragments
	shop_status_label.text = "Elige una mejora o arma"
	shop_panel.show()
	get_tree().paused = true


func _on_shop_purchase_pressed(option_index: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		push_error("Cannot purchase upgrade: no Player exists in the player group.")
		return
	if option_index < 0 or option_index >= SHOP_COSTS.size():
		push_error("Invalid shop option index: %d" % option_index)
		return

	if option_index == 3 and player.has_shotgun:
		shop_status_label.text = "Ya tienes la Escopeta"
		return
	if option_index == 4 and player.has_grenade_launcher:
		shop_status_label.text = "Ya tienes el Lanzagranadas"
		return

	var cost := SHOP_COSTS[option_index]
	if player.core_fragments < cost:
		shop_status_label.text = "No tienes suficientes Fragmentos de Núcleo"
		return

	player.core_fragments -= cost
	match option_index:
		0:
			player.current_health = mini(player.max_health, player.current_health + 3)
			player.health_changed.emit(player.current_health, player.max_health)
			shop_status_label.text = "Chasis reparado"
		1:
			player.speed *= 1.15
			shop_status_label.text = "Sobremarcha instalada"
		2:
			player.max_health += 2
			player.health_changed.emit(player.current_health, player.max_health)
			shop_status_label.text = "Batería máxima aumentada"
		3:
			player.has_shotgun = true
			player.unlocked_weapons.append("shotgun")
			player.current_weapon_index = player.unlocked_weapons.size() - 1
			player.current_weapon = "shotgun"
			print("Escopeta comprada")
			shop_status_label.text = "Escopeta añadida al inventario"
		4:
			player.has_grenade_launcher = true
			print("Lanzagranadas comprado")
			shop_status_label.text = "Lanzagranadas añadido al inventario"

	shop_fragments_label.text = "Core Fragments: %d" % player.core_fragments


func spawn_boss() -> void:
	print("AQUÍ APARECE EL JEFE")
	boss_warning_label.show()
	await get_tree().create_timer(1.5).timeout
	boss_warning_label.hide()
	if boss_scene == null:
		push_error("Cannot spawn final boss: boss_scene is not assigned.")
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_error("Cannot spawn final boss: no player exists in the player group.")
		return

	var boss := boss_scene.instantiate() as Boss
	if boss == null:
		push_error("boss_scene must have a Boss root node.")
		return
	add_child(boss)
	boss.global_position = player.global_position + Vector2(0.0, -300.0)
	boss.defeated.connect(_on_boss_defeated)


func _on_boss_defeated() -> void:
	boss_warning_label.text = "BOSS DEFEATED"
	boss_warning_label.show()


func _update_wave_progress() -> void:
	if current_wave == KILLS_PER_WAVE.size():
		wave_time_label.text = "WAVE %d  |  BOSS" % current_wave
		return

	wave_time_label.text = "WAVE %d  |  KILLS %d/%d" % [
		current_wave,
		enemies_killed,
		enemies_to_kill
	]


func _on_continue_pressed() -> void:
	if current_wave >= KILLS_PER_WAVE.size():
		return

	current_wave += 1
	enemies_killed = 0
	closing_magnet_active = false
	_wave_has_ended = false
	shop_panel.hide()
	get_tree().paused = false
	if current_wave == 5:
		_update_wave_progress()
		spawn_boss()
	else:
		enemies_to_kill = KILLS_PER_WAVE[current_wave - 1]
		spawn_timer.wait_time = 1.5
		_update_wave_progress()
		spawn_timer.start()


func _spawn_enemy() -> void:
	if _wave_has_ended:
		return

	var scene_to_spawn := enemy_scene
	if minion_scene != null and (scene_to_spawn == null or randf() < 0.7):
		scene_to_spawn = minion_scene
	if scene_to_spawn == null:
		return

	var enemy := scene_to_spawn.instantiate() as Node2D
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_error("Cannot spawn enemy: no player exists in the player group.")
		enemy.queue_free()
		return

	var spawn_direction := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	var spawn_distance := randf_range(400.0, 600.0)
	add_child(enemy)
	enemy.global_position = player.global_position + spawn_direction * spawn_distance
