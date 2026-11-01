class_name BoardLogic
extends RefCounted
## Bouchon : véhicules restants et test de sortie. Plateau continu, pas de cases.
## La géométrie étant figée, les bloqueurs de chaque véhicule sont calculés une fois.

const NO_VEHICLE: int = -1

var _boxes: Array[OrientedBox] = []
## Pour chaque véhicule : ids dans son couloir, du plus proche au plus lointain.
var _blockers: Array[PackedInt32Array] = []
var _remaining: Array[bool] = []
var _remaining_count: int = 0


func _init(level: LevelData) -> void:
	for vehicle: LevelVehicle in level.vehicles:
		_boxes.append(OrientedBox.from_vehicle(vehicle))
		_remaining.append(true)
	_remaining_count = _boxes.size()
	var reach: float = level.board_width + level.board_height
	for id: int in _boxes.size():
		_blockers.append(_compute_blockers(id, reach))


func has_vehicle(vehicle_id: int) -> bool:
	return vehicle_id >= 0 and vehicle_id < _remaining.size() and _remaining[vehicle_id]


func remaining_count() -> int:
	return _remaining_count


func can_exit(vehicle_id: int) -> bool:
	return has_vehicle(vehicle_id) and first_blocker(vehicle_id) == NO_VEHICLE


func first_blocker(vehicle_id: int) -> int:
	for blocker_id: int in _blockers[vehicle_id]:
		if _remaining[blocker_id]:
			return blocker_id
	return NO_VEHICLE


func remove(vehicle_id: int) -> void:
	if has_vehicle(vehicle_id):
		_remaining[vehicle_id] = false
		_remaining_count -= 1


func any_can_exit() -> bool:
	for id: int in _boxes.size():
		if can_exit(id):
			return true
	return false


## Tous les bloqueurs géométriques d'un véhicule, utilisés par le solveur.
func blockers_of(vehicle_id: int) -> PackedInt32Array:
	return _blockers[vehicle_id]


## Véhicule restant sous un point du plateau ; `tolerance` élargit la zone tactile.
func vehicle_at(x: float, y: float, tolerance: float) -> int:
	var best_id: int = NO_VEHICLE
	var best_distance: float = INF
	for id: int in _boxes.size():
		var box: OrientedBox = _boxes[id]
		if not _remaining[id] or not box.contains_point(x, y, tolerance):
			continue
		var distance: float = Vector2(x - box.center_x, y - box.center_y).length_squared()
		if distance < best_distance:
			best_distance = distance
			best_id = id
	return best_id


func _compute_blockers(vehicle_id: int, reach: float) -> PackedInt32Array:
	var own: OrientedBox = _boxes[vehicle_id]
	var corridor: OrientedBox = own.swept(reach)
	var hits: Array[Array] = []
	for other_id: int in _boxes.size():
		if other_id != vehicle_id and corridor.overlaps(_boxes[other_id]):
			var other: OrientedBox = _boxes[other_id]
			var near: float = other.center_on_axis(own.dir_x, own.dir_y) - other.radius_on_axis(own.dir_x, own.dir_y)
			hits.append([near, other_id])
	hits.sort_custom(_is_closer)
	var ordered: PackedInt32Array = PackedInt32Array()
	for hit: Array in hits:
		var other_id: int = hit[1]
		ordered.append(other_id)
	return ordered


static func _is_closer(a: Array, b: Array) -> bool:
	var a_near: float = a[0]
	var b_near: float = b[0]
	if absf(a_near - b_near) > OrientedBox.EPSILON:
		return a_near < b_near
	var a_id: int = a[1]
	var b_id: int = b[1]
	return a_id < b_id
