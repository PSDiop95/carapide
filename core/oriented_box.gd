class_name OrientedBox
extends RefCounted
## Boîte orientée 2D, testée par axes séparateurs (SAT). Calcul en float 64 bits.

const EPSILON: float = 1e-6
const QUARTER_TURN: float = 90.0
const FULL_TURN: float = 360.0
## cos et sin exacts des multiples de 90° : aucune dérive sur les voies droites.
const CARDINAL_DIRS: Array[Array] = [[1.0, 0.0], [0.0, 1.0], [-1.0, 0.0], [0.0, -1.0]]

var center_x: float
var center_y: float
var half_length: float
var half_width: float
var dir_x: float
var dir_y: float


func _init(x: float, y: float, length: float, width: float, angle: float) -> void:
	center_x = x
	center_y = y
	half_length = length * 0.5
	half_width = width * 0.5
	var normalized: float = fposmod(angle, FULL_TURN)
	var turns: float = normalized / QUARTER_TURN
	if is_equal_approx(turns, roundf(turns)):
		var direction: Array = CARDINAL_DIRS[int(roundf(turns)) % CARDINAL_DIRS.size()]
		dir_x = direction[0]
		dir_y = direction[1]
	else:
		dir_x = cos(deg_to_rad(normalized))
		dir_y = sin(deg_to_rad(normalized))


static func from_vehicle(vehicle: LevelVehicle) -> OrientedBox:
	return OrientedBox.new(vehicle.pos_x, vehicle.pos_y, vehicle.length, vehicle.width, vehicle.angle)


## Couloir balayé : part du centre et s'étend sur `reach` au-delà de l'avant.
func swept(reach: float) -> OrientedBox:
	var extended_half: float = half_length + reach * 0.5
	var offset: float = reach * 0.5
	var box: OrientedBox = OrientedBox.new(center_x + dir_x * offset, center_y + dir_y * offset, 0.0, half_width * 2.0, 0.0)
	box.half_length = extended_half
	box.dir_x = dir_x
	box.dir_y = dir_y
	return box


## Le contact exact n'est pas un chevauchement.
func overlaps(other: OrientedBox) -> bool:
	return (
		_axis_overlaps(other, dir_x, dir_y)
		and _axis_overlaps(other, -dir_y, dir_x)
		and _axis_overlaps(other, other.dir_x, other.dir_y)
		and _axis_overlaps(other, -other.dir_y, other.dir_x)
	)


func radius_on_axis(axis_x: float, axis_y: float) -> float:
	var along: float = absf(dir_x * axis_x + dir_y * axis_y)
	var across: float = absf(-dir_y * axis_x + dir_x * axis_y)
	return half_length * along + half_width * across


func center_on_axis(axis_x: float, axis_y: float) -> float:
	return center_x * axis_x + center_y * axis_y


func contains_point(x: float, y: float, tolerance: float) -> bool:
	var delta_x: float = x - center_x
	var delta_y: float = y - center_y
	var along: float = absf(delta_x * dir_x + delta_y * dir_y)
	var across: float = absf(-delta_x * dir_y + delta_y * dir_x)
	return along <= half_length + tolerance and across <= half_width + tolerance


func fits_in_board(board_width: float, board_height: float) -> bool:
	var radius_x: float = radius_on_axis(1.0, 0.0)
	var radius_y: float = radius_on_axis(0.0, 1.0)
	return (
		center_x - radius_x >= -EPSILON
		and center_x + radius_x <= board_width + EPSILON
		and center_y - radius_y >= -EPSILON
		and center_y + radius_y <= board_height + EPSILON
	)


func _axis_overlaps(other: OrientedBox, axis_x: float, axis_y: float) -> bool:
	var distance: float = absf(center_on_axis(axis_x, axis_y) - other.center_on_axis(axis_x, axis_y))
	return distance < radius_on_axis(axis_x, axis_y) + other.radius_on_axis(axis_x, axis_y) - EPSILON
