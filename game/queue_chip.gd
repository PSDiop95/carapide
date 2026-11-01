class_name QueueChip
extends Control
## Pancarte d'un bloc de file : pastille couleur + pictogramme, nom, nombre de passagers.

const CHIP_SIZE: Vector2 = Vector2(205.0, 56.0)
const BACKGROUND: Color = Color(0.13, 0.13, 0.15)
const HEAD_BORDER: Color = Color.WHITE
const HEAD_BORDER_WIDTH: float = 4.0
const SWATCH_SIZE: float = 44.0
const SWATCH_MARGIN: float = 6.0
const PICTO_RADIUS: float = 15.0
const PICTO_OUTLINE: Color = Color(0.05, 0.05, 0.05)
const PICTO_OUTLINE_SCALE: float = 1.3
const FONT_SIZE: int = 22
const TEXT_LEFT: float = 56.0

var _label: Label = Label.new()
var _color: Color = Color.GRAY
var _outline: PackedVector2Array = PackedVector2Array()
var _is_head: bool = false


func _init() -> void:
	custom_minimum_size = CHIP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.position = Vector2(TEXT_LEFT, 0.0)
	_label.size = Vector2(CHIP_SIZE.x - TEXT_LEFT, CHIP_SIZE.y)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func show_block(color: Color, picto: String, text: String, is_head: bool) -> void:
	_color = color
	_outline = PictoShapes.points(picto)
	_label.text = text
	_is_head = is_head
	queue_redraw()


func label_text() -> String:
	return _label.text


func _draw() -> void:
	var area: Rect2 = Rect2(Vector2.ZERO, CHIP_SIZE)
	draw_rect(area, BACKGROUND)
	if _is_head:
		draw_rect(area, HEAD_BORDER, false, HEAD_BORDER_WIDTH)
	var swatch: Rect2 = Rect2(Vector2.ONE * SWATCH_MARGIN, Vector2.ONE * SWATCH_SIZE)
	draw_rect(swatch, _color)
	if _outline.is_empty():
		return
	var center: Vector2 = swatch.get_center()
	draw_colored_polygon(_placed(center, PICTO_RADIUS * PICTO_OUTLINE_SCALE), PICTO_OUTLINE)
	draw_colored_polygon(_placed(center, PICTO_RADIUS), Color.WHITE)


## Les contours ont y vers le haut, l'écran 2D y vers le bas.
func _placed(center: Vector2, radius: float) -> PackedVector2Array:
	var placed: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in _outline:
		placed.append(center + Vector2(point.x, -point.y) * radius)
	return placed
