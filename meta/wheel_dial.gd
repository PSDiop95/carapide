class_name WheelDial
extends Control
## Disque de la Roue : six secteurs gris, le texte de chaque case. Tourne autour de son centre.

const RADIUS: float = 240.0
const LABEL_RADIUS: float = 150.0
const LABEL_SIZE: Vector2 = Vector2(180.0, 44.0)
const FONT_SIZE: int = 26
const ARC_POINTS: int = 12
const COLOR_A: Color = Color(0.62, 0.62, 0.6)
const COLOR_B: Color = Color(0.78, 0.78, 0.76)

var _texts: PackedStringArray = PackedStringArray()


func setup(texts: PackedStringArray) -> void:
	_texts = texts


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS, RADIUS) * 2.0
	size = custom_minimum_size
	pivot_offset = Vector2(RADIUS, RADIUS)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index: int in _texts.size():
		add_child(_make_label(index))


func _draw() -> void:
	for index: int in _texts.size():
		var points: PackedVector2Array = PackedVector2Array([pivot_offset])
		for step: int in ARC_POINTS + 1:
			var angle: float = _angle(index) + sector() * float(step) / float(ARC_POINTS)
			points.append(pivot_offset + Vector2.from_angle(angle) * RADIUS)
		draw_colored_polygon(points, COLOR_A if index % 2 == 0 else COLOR_B)


func sector() -> float:
	return TAU / float(_texts.size())


## Rotation qui amène cette case sous le pointeur (en haut), après quelques tours complets.
func target_rotation(index: int, from_rotation: float, turns: int) -> float:
	var target: float = -(float(index) + 0.5) * sector()
	return target + TAU * (ceilf((from_rotation - target) / TAU) + float(turns))


## Case sous le pointeur pour cette rotation.
func index_at_pointer(at_rotation: float) -> int:
	return int(fposmod(-at_rotation, TAU) / sector())


## Le secteur 0 commence sous le pointeur.
func _angle(index: int) -> float:
	return -PI * 0.5 + float(index) * sector()


func _make_label(index: int) -> Label:
	var label: Label = Label.new()
	label.text = _texts[index]
	label.size = LABEL_SIZE
	label.pivot_offset = LABEL_SIZE * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color.BLACK)
	var middle: float = _angle(index) + sector() * 0.5
	label.position = pivot_offset + Vector2.from_angle(middle) * LABEL_RADIUS - LABEL_SIZE * 0.5
	label.rotation = middle + PI * 0.5
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
