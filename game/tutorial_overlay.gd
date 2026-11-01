class_name TutorialOverlay
extends Control
## Tutoriel forcé : voile troué sur la cible, main qui pointe. Seule la cible répond.

signal target_pressed

const SHADE: Color = Color(0.0, 0.0, 0.0, 0.65)
const HAND_COLOR: Color = Color(1.0, 0.95, 0.85)
const HAND_OUTLINE: Color = Color(0.15, 0.15, 0.15)
const HAND_GAP: float = 12.0
const HAND_BOB: float = 14.0
const BOB_SECONDS: float = 0.45
const HINT_FONT_SIZE: int = 32
const HINT_MARGIN: float = 40.0
const HINT_TOP_RATIO: float = 0.3
## Doigt pointant vers le bas, pointe à l'origine.
const HAND_SHAPE: Array[Vector2] = [
	Vector2(0, 0), Vector2(-14, -22), Vector2(-14, -60), Vector2(-34, -60), Vector2(-34, -110),
	Vector2(34, -110), Vector2(34, -60), Vector2(14, -60), Vector2(14, -22),
]

var target_rect: Rect2 = Rect2()

var _hint: Label = Label.new()
var _bob: float = 0.0
var _tween: Tween = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hint.add_theme_font_size_override("font_size", HINT_FONT_SIZE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	hide()


func point_at(target: Rect2, hint_text: String) -> void:
	target_rect = target
	_hint.text = hint_text
	_hint.position = Vector2(HINT_MARGIN, size.y * HINT_TOP_RATIO)
	_hint.size = Vector2(size.x - HINT_MARGIN * 2.0, 0.0)
	show()
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_loops()
	_tween.tween_method(_set_bob, 0.0, HAND_BOB, BOB_SECONDS).set_trans(Tween.TRANS_SINE)
	_tween.tween_method(_set_bob, HAND_BOB, 0.0, BOB_SECONDS).set_trans(Tween.TRANS_SINE)
	queue_redraw()


func close() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	hide()


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT and target_rect.has_point(button.position):
		target_pressed.emit()


func _set_bob(value: float) -> void:
	_bob = value
	queue_redraw()


func _draw() -> void:
	var hole: Rect2 = target_rect
	draw_rect(Rect2(0.0, 0.0, size.x, hole.position.y), SHADE)
	draw_rect(Rect2(0.0, hole.end.y, size.x, size.y - hole.end.y), SHADE)
	draw_rect(Rect2(0.0, hole.position.y, hole.position.x, hole.size.y), SHADE)
	draw_rect(Rect2(hole.end.x, hole.position.y, size.x - hole.end.x, hole.size.y), SHADE)
	var tip: Vector2 = Vector2(hole.get_center().x, hole.position.y - HAND_GAP - _bob)
	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in HAND_SHAPE:
		points.append(tip + point)
	draw_colored_polygon(points, HAND_COLOR)
	points.append(points[0])
	draw_polyline(points, HAND_OUTLINE, 3.0)
