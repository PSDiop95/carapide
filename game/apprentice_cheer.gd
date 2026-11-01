class_name ApprenticeCheer
extends Control
## L'apprenti célèbre la victoire : silhouette grise qui saute, en attendant l'art final.

const FIGURE_SIZE: Vector2 = Vector2(120.0, 190.0)
const BODY_COLOR: Color = Color(0.72, 0.72, 0.7)
const BODY_RECT: Rect2 = Rect2(30.0, 70.0, 60.0, 90.0)
const HEAD_RECT: Rect2 = Rect2(38.0, 26.0, 44.0, 44.0)
const ARM_SIZE: Vector2 = Vector2(14.0, 60.0)
const ARM_LEFT: Vector2 = Vector2(30.0, 74.0)
const ARM_RIGHT: Vector2 = Vector2(90.0, 74.0)

var _height: float = 0.0
var _speed: float = 0.0
var _swing: float = 0.0
var _time: float = 0.0
var _figure: Control = Control.new()
var _left_arm: ColorRect = ColorRect.new()
var _right_arm: ColorRect = ColorRect.new()


func configure(config: PresentationConfig) -> void:
	_height = config.victory_cheer_height
	_speed = config.victory_cheer_speed
	_swing = config.victory_cheer_swing


func _ready() -> void:
	custom_minimum_size = FIGURE_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_figure)
	_figure.add_child(_part(BODY_RECT))
	_figure.add_child(_part(HEAD_RECT))
	_add_arm(_left_arm, ARM_LEFT)
	_add_arm(_right_arm, ARM_RIGHT)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	var beat: float = absf(sin(_time * _speed))
	_figure.position.y = -beat * _height
	_left_arm.rotation = PI - beat * _swing
	_right_arm.rotation = PI + beat * _swing


func hop_height() -> float:
	return -_figure.position.y


func _part(rect: Rect2) -> ColorRect:
	var part: ColorRect = ColorRect.new()
	part.color = BODY_COLOR
	part.position = rect.position
	part.size = rect.size
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return part


func _add_arm(arm: ColorRect, shoulder: Vector2) -> void:
	arm.color = BODY_COLOR
	arm.size = ARM_SIZE
	arm.position = shoulder
	arm.pivot_offset = Vector2(ARM_SIZE.x * 0.5, 0.0)
	arm.rotation = PI
	arm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_figure.add_child(arm)
