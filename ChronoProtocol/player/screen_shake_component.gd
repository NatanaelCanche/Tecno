extends Camera2D

@export var shake_duration: float = 0.18
@export var shake_strength: float = 12.0
@export_range(1, 30) var shake_steps: int = 8

var _default_offset := Vector2.ZERO
var _shake_tween: Tween


func _ready() -> void:
	_default_offset = offset


func shake() -> void:
	if _shake_tween != null and _shake_tween.is_running():
		_shake_tween.kill()

	_shake_tween = create_tween()
	for step in range(shake_steps):
		var falloff := 1.0 - float(step) / shake_steps
		var displacement := Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		) * falloff
		_shake_tween.tween_property(
			self,
			"offset",
			_default_offset + displacement,
			shake_duration / shake_steps
		)
	_shake_tween.tween_property(self, "offset", _default_offset, 0.04)
