class_name DiouleMixer
extends RefCounted
## Choisit le mélange du Dioulé : destinations permutées entre véhicules du bouchon de même capacité,
## ce qui garde sièges et passagers égaux par destination. Déterministe : budget en nœuds, jamais en temps.

const MAX_DRAWS: int = 20


## Seed dérivée de l'état. Vide si aucun tirage n'est gagnable avec les places actuelles.
static func mix(rules: GameRules, max_nodes: int) -> PackedStringArray:
	return mix_with_seed(rules, max_nodes, rules.state_key().hash())


## Garde le tirage gagnable qui laisse le plus de places libres ; à égalité, le premier tiré.
## Budget épuisé : garde le meilleur tirage déjà prouvé.
static func mix_with_seed(rules: GameRules, max_nodes: int, seed_value: int) -> PackedStringArray:
	var best: PackedStringArray = PackedStringArray()
	if not rules.can_use_dioule():
		return best
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var best_margin: int = -1
	var budget: Array[int] = [max_nodes]
	for _draw: int in MAX_DRAWS:
		var candidate: PackedStringArray = _draw_mix(rules, rng)
		if candidate == rules.destinations():
			continue
		var margin: int = _margin(rules.with_destinations(candidate), budget)
		if margin > best_margin:
			best = candidate
			best_margin = margin
		if budget[0] <= 0:
			break
	return best


## Places libres dont cette position peut se passer ; -1 si elle n'est pas prouvée gagnable.
static func _margin(rules: GameRules, budget: Array[int]) -> int:
	if not _wins(rules, budget):
		return -1
	var margin: int = 0
	while margin < rules.free_slot_count() - 1 and _wins(rules.with_reserved_slots(margin + 1), budget):
		margin += 1
	return margin


static func _wins(rules: GameRules, budget: Array[int]) -> bool:
	var solver: BoosterSolver = BoosterSolver.new(budget[0])
	var won: bool = solver.can_win_without_booster(rules)
	budget[0] -= solver.nodes_used()
	return won


static func _draw_mix(rules: GameRules, rng: RandomNumberGenerator) -> PackedStringArray:
	var mixed: PackedStringArray = rules.destinations().duplicate()
	var groups: Dictionary[int, PackedInt32Array] = {}
	for id: int in rules.board_vehicles():
		var capacity: int = rules.vehicle_capacity(id)
		if not groups.has(capacity):
			groups[capacity] = PackedInt32Array()
		groups[capacity].append(id)
	var capacities: Array[int] = groups.keys()
	capacities.sort()
	for capacity: int in capacities:
		_shuffle_group(mixed, groups[capacity], rng)
	return mixed


## Fisher-Yates : `shuffle()` de Godot n'accepte pas de seed injectée.
static func _shuffle_group(mixed: PackedStringArray, ids: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	for index: int in range(ids.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var kept: String = mixed[ids[index]]
		mixed[ids[index]] = mixed[ids[other]]
		mixed[ids[other]] = kept
