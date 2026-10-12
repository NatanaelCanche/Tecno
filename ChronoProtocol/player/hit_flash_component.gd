class_name HitFlashComponent
extends Node

@export var target_path: NodePath = ^"../AnimatedSprite2D"
@export var flash_duration: float = 0.12
@export var peak_duration: float = 0.025

var _target: CanvasItem
var _original_modulate: Color
var _tween: Tween


func _ready() -> void:
	_target = get_node_or_null(target_path) as CanvasItem
	if _target == null:
		push_error("HitFlashComponent requires a CanvasItem at target_path.")
		return
	_original_modulate = _target.modulate


func flash() -> void:
	if _target == null:
		return

	if _tween != null and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(_target, "modulate", Color.WHITE, peak_duration)
	_tween.tween_property(_target, "modulate", _original_modulate, flash_duration - peak_duration)
