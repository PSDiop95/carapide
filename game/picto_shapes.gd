class_name PictoShapes
extends RefCounted
## Contours des pictogrammes de destination (GDD §3), centrés, rayon 1, sens trigonométrique.

const CIRCLE_POINTS: int = 24
const HEART_POINTS: int = 32
const STAR_POINTS: int = 10
const STAR_INNER_RADIUS: float = 0.45
const CROSS_HALF_WIDTH: float = 0.34
const SQUARE_HALF: float = 0.82
const HEART_SCALE: float = 1.0 / 17.0
const HEART_CENTER_Y: float = 1.5

const NAMES: Array[String] = ["circle", "square", "triangle", "star", "diamond", "cross", "heart", "hexagon"]


static func points(shape: String) -> PackedVector2Array:
	match shape:
		"circle":
			return _regular(CIRCLE_POINTS, 0.0)
		"square":
			return _scaled(_regular(4, PI * 0.25), SQUARE_HALF * sqrt(2.0))
		"triangle":
			return _regular(3, PI * 0.5)
		"star":
			return _star()
		"diamond":
			return _regular(4, 0.0)
		"cross":
			return _cross()
		"heart":
			return _heart()
		"hexagon":
			return _regular(6, 0.0)
	push_error("Pictogramme inconnu : %s" % shape)
	return _regular(CIRCLE_POINTS, 0.0)


static func _regular(count: int, start_angle: float) -> PackedVector2Array:
	var outline: PackedVector2Array = PackedVector2Array()
	for index: int in count:
		outline.append(Vector2.from_angle(start_angle + TAU * float(index) / float(count)))
	return outline


static func _scaled(outline: PackedVector2Array, factor: float) -> PackedVector2Array:
	var scaled: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in outline:
		scaled.append(point * factor)
	return scaled


static func _star() -> PackedVector2Array:
	var outline: PackedVector2Array = PackedVector2Array()
	for index: int in STAR_POINTS:
		var radius: float = 1.0 if index % 2 == 0 else STAR_INNER_RADIUS
		outline.append(Vector2.from_angle(PI * 0.5 + TAU * float(index) / float(STAR_POINTS)) * radius)
	return outline


static func _cross() -> PackedVector2Array:
	var w: float = CROSS_HALF_WIDTH
	return PackedVector2Array([
		Vector2(w, -1.0), Vector2(w, -w), Vector2(1.0, -w), Vector2(1.0, w), Vector2(w, w), Vector2(w, 1.0),
		Vector2(-w, 1.0), Vector2(-w, w), Vector2(-1.0, w), Vector2(-1.0, -w), Vector2(-w, -w), Vector2(-w, -1.0),
	])


## Courbe paramétrique classique du cœur, pointe en bas.
static func _heart() -> PackedVector2Array:
	var outline: PackedVector2Array = PackedVector2Array()
	for index: int in HEART_POINTS:
		var t: float = TAU * float(index) / float(HEART_POINTS)
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		outline.append(Vector2(-x, y) * HEART_SCALE + Vector2(0.0, HEART_CENTER_Y * HEART_SCALE))
	return outline
