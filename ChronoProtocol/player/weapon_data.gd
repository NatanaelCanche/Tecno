class_name WeaponData
extends Resource

@export var weapon_name: String = "Weapon"
@export var projectile_scene: PackedScene
@export_range(0.01, 10.0, 0.01) var fire_interval: float = 0.25
