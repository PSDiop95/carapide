class_name Solver
extends RefCounted
## DFS + mémo sur l'état. Le seul choix du joueur est le véhicule à sortir ;
## chargement et départs sont déterministes et reproduisent GameRules.
## Gare stockée en triplets (destination, capacité, chargés), du plus ancien au plus récent.

const DEFAULT_MAX_NODES: int = 2000000
const MAX_VEHICLES: int = 62
const FIELDS: int = 3
const FIELD_CAPACITY: int = 1
const FIELD_LOADED: int = 2

var _vehicle_dests: PackedInt32Array = PackedInt32Array()
var _vehicle_capacities: PackedInt32Array = PackedInt32Array()
var _blocker_masks: PackedInt64Array = PackedInt64Array()
var _block_dests: PackedInt32Array = PackedInt32Array()
var _block_counts: PackedInt32Array = PackedInt32Array()
var _dest_count: int = 0
var _failed_states: Dictionary[String, bool] = {}
var _path: PackedInt32Array = PackedInt32Array()
var _nodes: int = 0
var _max_nodes: int = 0
var _slots: int = 0
var _aborted: bool = false


static func solve(level: LevelData, slots: int, max_nodes: int = DEFAULT_MAX_NODES) -> SolverResult:
	assert(level.vehicles.size() <= MAX_VEHICLES)
	var solver: Solver = Solver.new(level, max_nodes)
	for candidate: int in range(1, slots + 1):
		if solver._solvable_with(candidate):
			return solver._result(true, slots - candidate, candidate)
		if solver._aborted:
			break
	return solver._result(false, -1, -1)


func _init(level: LevelData, max_nodes: int) -> void:
	_max_nodes = max_nodes
	var dest_ids: Dictionary[String, int] = {}
	var board: BoardLogic = BoardLogic.new(level)
	for vehicle: LevelVehicle in level.vehicles:
		_vehicle_dests.append(_dest_id(dest_ids, vehicle.dest))
		_vehicle_capacities.append(vehicle.capacity)
		var mask: int = 0
		for blocker: int in board.blockers_of(vehicle.id):
			mask |= 1 << blocker
		_blocker_masks.append(mask)
	for block: QueueBlock in level.queue:
		_block_dests.append(_dest_id(dest_ids, block.dest))
		_block_counts.append(block.count)
	_dest_count = dest_ids.size()


func _dest_id(dest_ids: Dictionary[String, int], dest: String) -> int:
	if not dest_ids.has(dest):
		dest_ids[dest] = dest_ids.size()
	return dest_ids[dest]


func _result(solvable: bool, margin: int, min_slots: int) -> SolverResult:
	var result: SolverResult = SolverResult.new()
	result.solvable = solvable
	result.min_margin = margin
	result.min_slots = min_slots
	result.nodes_explored = _nodes
	result.aborted = _aborted
	if solvable:
		result.solution = _path
	return result


func _solvable_with(slots: int) -> bool:
	_slots = slots
	_failed_states.clear()
	_path = PackedInt32Array()
	var all_vehicles: int = (1 << _vehicle_dests.size()) - 1
	var first_count: int = _block_counts[0] if not _block_counts.is_empty() else 0
	return _search(all_vehicles, 0, first_count, PackedInt32Array())


func _search(mask: int, block_index: int, block_left: int, parked: PackedInt32Array) -> bool:
	if block_index >= _block_dests.size():
		return true
	if parked.size() >= _slots * FIELDS:
		return false
	var key: String = _state_key(mask, block_index, block_left, parked)
	if _failed_states.has(key):
		return false
	_failed_states[key] = true
	_nodes += 1
	if _nodes > _max_nodes:
		_aborted = true
		return false
	for vehicle_id: int in _candidates(mask, _block_dests[block_index]):
		_path.append(vehicle_id)
		if _try_vehicle(vehicle_id, mask, block_index, block_left, parked):
			return true
		_path.resize(_path.size() - 1)
		if _aborted:
			return false
	return false


## Véhicules libres, ceux de la destination en tête d'abord.
func _candidates(mask: int, head_dest: int) -> PackedInt32Array:
	var matching: PackedInt32Array = PackedInt32Array()
	var others: PackedInt32Array = PackedInt32Array()
	for vehicle_id: int in _vehicle_dests.size():
		if mask & (1 << vehicle_id) == 0 or mask & _blocker_masks[vehicle_id] != 0:
			continue
		if _vehicle_dests[vehicle_id] == head_dest:
			matching.append(vehicle_id)
		else:
			others.append(vehicle_id)
	matching.append_array(others)
	return matching


func _try_vehicle(vehicle_id: int, mask: int, block_index: int, block_left: int, parked: PackedInt32Array) -> bool:
	var next: PackedInt32Array = parked.duplicate()
	next.append(_vehicle_dests[vehicle_id])
	next.append(_vehicle_capacities[vehicle_id])
	next.append(0)
	var index: int = block_index
	var left: int = block_left
	while index < _block_dests.size():
		var at: int = _oldest_for(next, _block_dests[index])
		if at < 0:
			break
		var amount: int = mini(left, next[at + FIELD_CAPACITY] - next[at + FIELD_LOADED])
		next[at + FIELD_LOADED] += amount
		left -= amount
		if next[at + FIELD_LOADED] == next[at + FIELD_CAPACITY]:
			next = next.slice(0, at) + next.slice(at + FIELDS)
		if left == 0:
			index += 1
			left = _block_counts[index] if index < _block_counts.size() else 0
	return _search(mask & ~(1 << vehicle_id), index, left, next)


func _oldest_for(parked: PackedInt32Array, dest: int) -> int:
	for at: int in range(0, parked.size(), FIELDS):
		if parked[at] == dest:
			return at
	return -1


## L'ordre d'arrivée compte à l'intérieur d'une destination, pas entre destinations.
func _state_key(mask: int, block_index: int, block_left: int, parked: PackedInt32Array) -> String:
	var key: String = "%d:%d:%d" % [mask, block_index, block_left]
	for dest: int in _dest_count:
		for at: int in range(0, parked.size(), FIELDS):
			if parked[at] == dest:
				key += ":%d,%d,%d" % [dest, parked[at + FIELD_CAPACITY], parked[at + FIELD_LOADED]]
	return key
