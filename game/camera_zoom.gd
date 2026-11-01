class_name CameraZoom
extends RefCounted
## Zoom et décalage de la caméra orthographique, en unités du plan caméra.
## À ×1 la vue est le cadrage du niveau ; plus on zoome, plus le centre peut aller aux bords du plateau.

const MIN_ZOOM: float = 1.0

var zoom: float = MIN_ZOOM
var pan: Vector2 = Vector2.ZERO

var _max_zoom: float
var _board_min: Vector2 = Vector2.ZERO
var _board_max: Vector2 = Vector2.ZERO


func _init(max_zoom: float) -> void:
	_max_zoom = max_zoom


## Plateau dans le plan caméra, relatif au centre du cadrage.
func set_board(board_min: Vector2, board_max: Vector2) -> void:
	_board_min = board_min
	_board_max = board_max
	_clamp_pan()


## `anchor` : point visé par rapport au centre de l'écran, en unités à ×1. Il reste sous le doigt.
func zoom_at(factor: float, anchor: Vector2) -> void:
	var target: Vector2 = pan + anchor / zoom
	zoom = clampf(zoom * factor, MIN_ZOOM, _max_zoom)
	pan = target - anchor / zoom
	_clamp_pan()


func pan_by(amount: Vector2) -> void:
	pan += amount
	_clamp_pan()


func _clamp_pan() -> void:
	var reach: float = (zoom - MIN_ZOOM) / (_max_zoom - MIN_ZOOM)
	pan.x = clampf(pan.x, minf(_board_min.x * reach, 0.0), maxf(_board_max.x * reach, 0.0))
	pan.y = clampf(pan.y, minf(_board_min.y * reach, 0.0), maxf(_board_max.y * reach, 0.0))
