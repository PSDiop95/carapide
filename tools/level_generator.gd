class_name LevelGenerator
extends RefCounted
## Génération hors ligne (GDD §4) : placement inverse, file dérivée, perturbée jusqu'à la marge visée.
## Déterministe : seed injectée. Jamais utilisé au runtime.

const PLACEMENT_TRIES: int = 4000
const PERTURBATION_TRIES: int = 400
const SPLIT_UNIT: int = 4
const DRAWN_MAX_NODES: int = 300000
## Niveaux tuto libres ; ensuite, plus d'un tiers des véhicules est bloqué au départ.
const FREE_LEVELS: int = 2
const MIN_BLOCKED_DIVISOR: int = 3

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _catalog: VehicleCatalog


func _init(catalog: VehicleCatalog, seed_value: int) -> void:
	_catalog = catalog
	_rng.seed = seed_value


## `spec` : id, board, types, angles, dests, vehicles, target_margin, slots.
## Renvoie le dictionnaire JSON du niveau, ou {} si la marge n'est pas atteinte.
func generate(spec: LevelSpec) -> Dictionary:
	var placed: Array[Dictionary] = _place_vehicles(spec)
	if placed.size() != spec.vehicles:
		return {}
	var queue: Array[Array] = _queue_from_exit_order(placed)
	if not _has_enough_dependencies(spec, _to_raw(spec, placed, queue)):
		return {}
	for _try: int in PERTURBATION_TRIES:
		var raw: Dictionary = _to_raw(spec, placed, queue)
		var result: SolverResult = _solve(raw, spec)
		if result != null and result.solvable and result.min_margin == spec.target_margin:
			return raw
		if result != null and result.solvable and result.min_margin > spec.target_margin:
			queue = _perturbed(queue)
		else:
			queue = _queue_from_exit_order(placed)
			queue = _perturbed(queue)
	return {}


func _has_enough_dependencies(spec: LevelSpec, raw: Dictionary) -> bool:
	if spec.id <= FREE_LEVELS:
		return true
	var level: LevelData = LevelLoader.parse_dict(raw, _catalog).level
	var board: BoardLogic = BoardLogic.new(level)
	var blocked: int = 0
	for vehicle: LevelVehicle in level.vehicles:
		if not board.can_exit(vehicle.id):
			blocked += 1
	return blocked * MIN_BLOCKED_DIVISOR > level.vehicles.size()


func _solve(raw: Dictionary, spec: LevelSpec) -> SolverResult:
	var loaded: LevelLoadResult = LevelLoader.parse_dict(raw, _catalog)
	if not loaded.is_ok():
		return null
	var result: SolverResult = Solver.solve(loaded.level, spec.slots, DRAWN_MAX_NODES)
	return null if result.aborted else result


## Chaque nouveau véhicule a une sortie à son ajout : l'ordre inverse vide le bouchon.
func _place_vehicles(spec: LevelSpec) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	var boxes: Array[OrientedBox] = []
	var reach: float = spec.board.x + spec.board.y
	for _try: int in PLACEMENT_TRIES:
		if placed.size() == spec.vehicles:
			break
		var entry: Dictionary = _random_entry(spec, placed.size())
		var box: OrientedBox = _box_of(entry)
		if box.fits_in_board(spec.board.x, spec.board.y) and _is_free(box, boxes, reach):
			placed.append(entry)
			boxes.append(box)
	return placed


func _is_free(box: OrientedBox, boxes: Array[OrientedBox], reach: float) -> bool:
	var corridor: OrientedBox = box.swept(reach)
	for other: OrientedBox in boxes:
		if box.overlaps(other) or corridor.overlaps(other):
			return false
	return true


func _random_entry(spec: LevelSpec, index: int) -> Dictionary:
	var type_name: String = spec.types[_rng.randi_range(0, spec.types.size() - 1)]
	var angle: float = spec.angles[_rng.randi_range(0, spec.angles.size() - 1)]
	var x: float = float(_rng.randi_range(1, int(spec.board.x * 2.0) - 1)) * 0.5
	var y: float = float(_rng.randi_range(1, int(spec.board.y * 2.0) - 1)) * 0.5
	return {"type": type_name, "dest": spec.dests[index % spec.dests.size()], "pos": [x, y], "angle": angle}


func _box_of(entry: Dictionary) -> OrientedBox:
	var type_name: String = entry["type"]
	var spec: VehicleSpec = _catalog.get_spec(type_name)
	var pos: Array = entry["pos"]
	var x: float = pos[0]
	var y: float = pos[1]
	var angle: float = entry["angle"]
	return OrientedBox.new(x, y, spec.length, spec.width, angle)


## File servie exactement dans l'ordre de sortie : marge maximale.
func _queue_from_exit_order(placed: Array[Dictionary]) -> Array[Array]:
	var queue: Array[Array] = []
	for index: int in range(placed.size() - 1, -1, -1):
		var entry: Dictionary = placed[index]
		var type_name: String = entry["type"]
		var dest: String = entry["dest"]
		queue.append([dest, _catalog.get_spec(type_name).capacity])
	return queue


## Permutation de deux blocs voisins, ou découpe d'un bloc en deux (fragmentation).
func _perturbed(queue: Array[Array]) -> Array[Array]:
	var next: Array[Array] = queue.duplicate(true)
	var index: int = _rng.randi_range(0, next.size() - 2)
	var count: int = next[index][1]
	if count > SPLIT_UNIT and _rng.randf() < 0.5:
		var dest: String = next[index][0]
		next[index] = [dest, count - SPLIT_UNIT]
		next.insert(_rng.randi_range(index + 1, next.size()), [dest, SPLIT_UNIT])
	else:
		var held: Array = next[index]
		next[index] = next[index + 1]
		next[index + 1] = held
	return next


func _to_raw(spec: LevelSpec, placed: Array[Dictionary], queue: Array[Array]) -> Dictionary:
	var blocks: Array = []
	for block: Array in _merged(queue):
		blocks.append({"dest": block[0], "count": block[1]})
	return {
		"id": spec.id, "slots": spec.slots, "board": [spec.board.x, spec.board.y],
		"vehicles": placed, "queue": blocks,
	}


func _merged(queue: Array[Array]) -> Array[Array]:
	var merged: Array[Array] = []
	for block: Array in queue:
		if not merged.is_empty() and merged[-1][0] == block[0]:
			var total: int = merged[-1][1]
			var added: int = block[1]
			merged[-1] = [block[0], total + added]
		else:
			merged.append(block.duplicate())
	return merged
