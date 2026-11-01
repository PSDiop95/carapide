class_name GestureTracker
extends RefCounted
## Traduit les touchers en tap, glissé ou pincement. Un tap se décide au relâchement,
## pour qu'un glissé ou un pincement ne sorte jamais un véhicule.

enum Kind { NONE, TAP, PAN, PINCH }

var kind: Kind = Kind.NONE
## Tap : position. Pincement : centre.
var position: Vector2 = Vector2.ZERO
var delta: Vector2 = Vector2.ZERO
var factor: float = 1.0

var _move_threshold: float
var _touches: Dictionary[int, Vector2] = {}
var _press_position: Vector2 = Vector2.ZERO
var _is_tap_candidate: bool = false


func _init(move_threshold: float) -> void:
	_move_threshold = move_threshold


## Analyse un événement ; le résultat est dans `kind`, `position`, `delta` et `factor`.
func process(event: InputEvent) -> Kind:
	kind = Kind.NONE
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if touch != null:
		_on_touch(touch.index, touch.position, touch.pressed)
	elif drag != null and _touches.has(drag.index):
		_on_drag(drag.index, drag.position)
	return kind


func _on_touch(index: int, at: Vector2, pressed: bool) -> void:
	if pressed:
		_touches[index] = at
		_is_tap_candidate = _touches.size() == 1
		_press_position = at
		return
	var had_touch: bool = _touches.erase(index)
	if had_touch and _is_tap_candidate and _touches.is_empty():
		kind = Kind.TAP
		position = at
	_is_tap_candidate = false


func _on_drag(index: int, at: Vector2) -> void:
	var previous: Vector2 = _touches[index]
	if _touches.size() == 1:
		_touches[index] = at
		if _is_tap_candidate and at.distance_to(_press_position) < _move_threshold:
			return
		_is_tap_candidate = false
		kind = Kind.PAN
		delta = at - previous
	elif _touches.size() == 2:
		_on_pinch_drag(index, at)


func _on_pinch_drag(index: int, at: Vector2) -> void:
	var points: Array[Vector2] = _touch_points()
	var old_center: Vector2 = (points[0] + points[1]) * 0.5
	var old_span: float = points[0].distance_to(points[1])
	_touches[index] = at
	points = _touch_points()
	var span: float = points[0].distance_to(points[1])
	if old_span <= 0.0:
		return
	kind = Kind.PINCH
	position = (points[0] + points[1]) * 0.5
	delta = position - old_center
	factor = span / old_span


func _touch_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for index: int in _touches:
		points.append(_touches[index])
	return points
