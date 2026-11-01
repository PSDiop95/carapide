extends SceneTree
## Mesure le solveur à 62, 70 et 80 véhicules : godot --headless -s res://tools/solver_benchmark.gd
## File rangée puis file entremêlée, seed fixe. Résultats à lire, pas de seuil bloquant.

const SIZES: Array[int] = [62, 70, 80]
const SEEDS: Array[int] = [1, 2, 3]
const DESTS: Array[String] = ["a", "b", "c", "d", "e", "f"]
const ROWS: int = 8
const CELL_X: float = 2.0
const CELL_Y: float = 5.0
const SLOTS: int = 4
const TAXI_CAPACITY: int = 4
const WINDOW: int = 3


func _init() -> void:
	for size: int in SIZES:
		for seed_value: int in SEEDS:
			for interleaved: bool in [false, true]:
				_measure(size, seed_value, interleaved)
	quit(0)


func _measure(size: int, seed_value: int, interleaved: bool) -> void:
	var level: LevelData = build_level(size, seed_value, interleaved)
	var start: int = Time.get_ticks_msec()
	var result: SolverResult = Solver.solve(level, SLOTS)
	var kind: String = "entremêlée" if interleaved else "rangée"
	print("%d véhicules, seed %d, file %s : soluble %s, plafond %s, marge %d, %d nœuds, %d ms" % [
		size, seed_value, kind, result.solvable, result.aborted, result.min_margin,
		result.nodes_explored, Time.get_ticks_msec() - start,
	])


## Grille de taxis : dans une colonne, le plus haut bloque ceux du dessous.
static func build_level(size: int, seed_value: int, interleaved: bool) -> LevelData:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var entries: Array = []
	for id: int in size:
		var column: int = id / ROWS
		var row: int = id % ROWS
		var pos: Array = [1.5 + float(column) * CELL_X, 3.0 + float(row) * CELL_Y]
		entries.append({"type": "taxi", "dest": DESTS[rng.randi_range(0, DESTS.size() - 1)], "pos": pos, "angle": 90})
	var columns: int = ceili(float(size) / float(ROWS))
	var raw: Dictionary = {
		"id": 1, "slots": SLOTS, "board": [float(columns) * CELL_X + 2.0, float(ROWS) * CELL_Y + 4.0],
		"vehicles": entries, "queue": _queue_for(_play_order(size, rng), entries, interleaved, rng),
	}
	var loaded: LevelLoadResult = LevelLoader.parse_dict(raw, VehicleCatalog.load_default())
	assert(loaded.is_ok(), "%s" % [loaded.errors])
	return loaded.level


## Ordre jouable : chaque colonne se vide du haut vers le bas.
static func _play_order(size: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var tops: Dictionary[int, int] = {}
	for id: int in size:
		tops[id / ROWS] = id
	var order: PackedInt32Array = PackedInt32Array()
	while not tops.is_empty():
		var columns: Array[int] = tops.keys()
		var column: int = columns[rng.randi_range(0, columns.size() - 1)]
		order.append(tops[column])
		tops[column] -= 1
		if tops[column] < column * ROWS:
			tops.erase(column)
	return order


static func _queue_for(order: PackedInt32Array, entries: Array, interleaved: bool, rng: RandomNumberGenerator) -> Array:
	var blocks: Array = []
	var half: int = TAXI_CAPACITY / 2
	var pending: Array = []
	for id: int in order:
		var entry: Dictionary = entries[id]
		var dest: String = entry["dest"]
		if not interleaved:
			blocks.append({"dest": dest, "count": TAXI_CAPACITY})
			continue
		blocks.append({"dest": dest, "count": half})
		pending.append({"dest": dest, "count": half})
		if pending.size() >= WINDOW:
			var at: int = rng.randi_range(0, pending.size() - 1)
			blocks.append(pending[at])
			pending.remove_at(at)
	blocks.append_array(pending)
	return blocks
