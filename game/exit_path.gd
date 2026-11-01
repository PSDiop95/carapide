class_name ExitPath
extends RefCounted
## Trajet d'un véhicule : suit sa flèche jusqu'à l'anneau autour du plateau, longe le bord,
## puis monte à sa place. Coins arrondis en Bézier, jamais de retour au-dessus du plateau.

const RING_MARGIN: float = 0.6
## Couloir entre plateau et gare : les véhicules garés s'arrêtent avant.
const TOP_MARGIN: float = 0.5
const CORNER_RADIUS: float = 0.45
const HANDLE_RATIO: float = 0.55
const MIN_SEGMENT: float = 0.01
const STRAIGHT_DOT: float = 0.999
const BAKE_INTERVAL: float = 0.1


static func build(layout: LevelLayout, vehicle: LevelVehicle, slot: int) -> Curve3D:
	var points: PackedVector2Array = waypoints(layout, vehicle, slot)
	var world: PackedVector3Array = PackedVector3Array()
	for point: Vector2 in points:
		world.append(layout.board_to_world(point.x, point.y))
	return _rounded(world)


## Points de passage, en coordonnées plateau.
static func waypoints(layout: LevelLayout, vehicle: LevelVehicle, slot: int) -> PackedVector2Array:
	var start: Vector2 = Vector2(vehicle.pos_x, vehicle.pos_y)
	var ring: Rect2 = _ring(layout)
	var target: Vector2 = layout.world_to_board(layout.slot_world(slot))
	var gate: Vector2 = Vector2(target.x, ring.end.y)
	var exit: Vector2 = _ring_hit(start, vehicle.angle, ring)
	var points: Array[Vector2] = [start, exit]
	points.append_array(_along_ring(exit, gate, ring))
	points.append(gate)
	points.append(target)
	return _without_duplicates(points)


static func _ring(layout: LevelLayout) -> Rect2:
	var low: Vector2 = Vector2(-RING_MARGIN, -RING_MARGIN)
	var high: Vector2 = Vector2(layout.board_width + RING_MARGIN, layout.board_height + TOP_MARGIN)
	return Rect2(low, high - low)


static func _ring_hit(start: Vector2, angle_degrees: float, ring: Rect2) -> Vector2:
	var direction: Vector2 = Vector2.from_angle(deg_to_rad(angle_degrees))
	var travel: float = INF
	if absf(direction.x) > MIN_SEGMENT:
		var edge_x: float = ring.end.x if direction.x > 0.0 else ring.position.x
		travel = minf(travel, (edge_x - start.x) / direction.x)
	if absf(direction.y) > MIN_SEGMENT:
		var edge_y: float = ring.end.y if direction.y > 0.0 else ring.position.y
		travel = minf(travel, (edge_y - start.y) / direction.y)
	return start + direction * travel


## Coins de l'anneau à franchir pour aller de `from` au couloir du haut.
static func _along_ring(from: Vector2, gate: Vector2, ring: Rect2) -> Array[Vector2]:
	var left: float = ring.position.x
	var right: float = ring.end.x
	var top: float = ring.end.y
	var bottom: float = ring.position.y
	if is_equal_approx(from.y, top):
		return []
	if is_equal_approx(from.x, left):
		return [Vector2(left, top)]
	if is_equal_approx(from.x, right):
		return [Vector2(right, top)]
	var via_left: float = absf(from.x - left) + absf(gate.x - left)
	var via_right: float = absf(from.x - right) + absf(gate.x - right)
	var side: float = left if via_left <= via_right else right
	return [Vector2(side, bottom), Vector2(side, top)]


static func _without_duplicates(points: Array[Vector2]) -> PackedVector2Array:
	var kept: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		if kept.is_empty() or kept[-1].distance_to(point) > MIN_SEGMENT:
			kept.append(point)
	return kept


static func _rounded(points: PackedVector3Array) -> Curve3D:
	var curve: Curve3D = Curve3D.new()
	curve.bake_interval = BAKE_INTERVAL
	curve.add_point(points[0])
	for index: int in range(1, points.size() - 1):
		_add_corner(curve, points[index - 1], points[index], points[index + 1])
	curve.add_point(points[-1])
	return curve


static func _add_corner(curve: Curve3D, before: Vector3, corner: Vector3, after: Vector3) -> void:
	var incoming: Vector3 = before.direction_to(corner)
	var outgoing: Vector3 = corner.direction_to(after)
	if incoming.dot(outgoing) > STRAIGHT_DOT:
		curve.add_point(corner)
		return
	var radius: float = minf(CORNER_RADIUS, minf(before.distance_to(corner), corner.distance_to(after)) * 0.5)
	var handle: float = radius * HANDLE_RATIO
	curve.add_point(corner - incoming * radius, Vector3.ZERO, incoming * handle)
	curve.add_point(corner + outgoing * radius, -outgoing * handle, Vector3.ZERO)
