class_name BoosterSolver
extends RefCounted
## Recherche avec boosters, par approfondissement du nombre de boosters autorisés.
## Rejoue GameRules : plus lent que Solver, mais l'Apprenti y réordonne vraiment la file.

const DEFAULT_MAX_NODES: int = 200000
const DEFAULT_MAX_BOOSTERS: int = 3
const ADVICE_MAX_NODES: int = 4000
const ADVICE_MAX_FURTHER: int = 2

var _max_nodes: int
var _nodes: int = 0
var _failed: Dictionary[String, bool] = {}
var _everything: BoosterAccess = BoosterAccess.new(true)


func _init(max_nodes: int) -> void:
	_max_nodes = max_nodes


## 0 si le niveau se gagne sans booster à ce nombre de places.
static func boosters_needed_min(level: LevelData, slots: int, max_boosters: int = DEFAULT_MAX_BOOSTERS, max_nodes: int = DEFAULT_MAX_NODES) -> BoosterSolveResult:
	var solver: BoosterSolver = BoosterSolver.new(max_nodes)
	var start: GameRules = GameRules.new(level, solver._everything, slots)
	var result: BoosterSolveResult = BoosterSolveResult.new()
	for budget: int in max_boosters + 1:
		if solver._can_win(start, budget):
			result.needed_min = budget
			break
		if solver._aborted():
			result.aborted = true
			break
	result.nodes_explored = solver._nodes
	return result


## Booster le plus utile pour cette partie : celui qui laisse le moins de boosters à payer ensuite.
## À égalité : Coxeur sur la tête, puis Apprenti, puis Coxeur ailleurs. Null si rien n'est possible.
static func advise(rules: GameRules, access: BoosterAccess, max_nodes: int = ADVICE_MAX_NODES) -> BoosterAdvice:
	var options: Array[BoosterAdvice] = _options(rules, access)
	if options.is_empty():
		return null
	var solver: BoosterSolver = BoosterSolver.new(max_nodes)
	for further: int in ADVICE_MAX_FURTHER + 1:
		for option: BoosterAdvice in options:
			if solver._can_win(solver._applied(rules, option), further):
				option.further_boosters = further
				return option
			if solver._aborted():
				options[0].aborted = true
				return options[0]
	return options[0]


static func _options(rules: GameRules, access: BoosterAccess) -> Array[BoosterAdvice]:
	var options: Array[BoosterAdvice] = []
	var coxeur: bool = access.can_obtain(BoosterAccess.Kind.COXEUR)
	if coxeur:
		_add_coxeur_options(options, rules, rules.head_vehicles())
	if access.can_obtain(BoosterAccess.Kind.APPRENTI) and rules.can_use_apprenti():
		var apprenti: BoosterAdvice = BoosterAdvice.new()
		apprenti.kind = BoosterAccess.Kind.APPRENTI
		options.append(apprenti)
	if coxeur:
		_add_coxeur_options(options, rules, rules.board_vehicles())
	return options


static func _add_coxeur_options(options: Array[BoosterAdvice], rules: GameRules, ids: PackedInt32Array) -> void:
	for id: int in ids:
		if rules.can_use_coxeur(id) and not _has_vehicle(options, id):
			var advice: BoosterAdvice = BoosterAdvice.new()
			advice.vehicle_id = id
			options.append(advice)


static func _has_vehicle(options: Array[BoosterAdvice], id: int) -> bool:
	for option: BoosterAdvice in options:
		if option.vehicle_id == id:
			return true
	return false


func _applied(rules: GameRules, option: BoosterAdvice) -> GameRules:
	var clone: GameRules = rules.copy(_everything)
	if option.kind == BoosterAccess.Kind.APPRENTI:
		clone.use_apprenti()
	else:
		clone.use_coxeur(option.vehicle_id)
	return clone


func _aborted() -> bool:
	return _nodes > _max_nodes


func _can_win(rules: GameRules, budget: int) -> bool:
	if rules.status == GameRules.Status.WON:
		return true
	if rules.status == GameRules.Status.LOST:
		return false
	var key: String = "%d|%s" % [budget, rules.state_key()]
	if _failed.has(key):
		return false
	_failed[key] = true
	_nodes += 1
	if _aborted():
		return false
	return _tap_wins(rules, budget) or (budget > 0 and _booster_wins(rules, budget - 1))


## Une gare bloquée n'accepte plus de tap : la boucle ne trouve alors aucun véhicule utile.
func _tap_wins(rules: GameRules, budget: int) -> bool:
	if rules.status != GameRules.Status.PLAYING:
		return false
	for id: int in _head_first(rules, rules.free_vehicles()):
		var clone: GameRules = rules.copy()
		clone.tap(id)
		if _can_win(clone, budget):
			return true
		if _aborted():
			return false
	return false


func _booster_wins(rules: GameRules, budget: int) -> bool:
	if rules.can_use_apprenti():
		var with_apprenti: GameRules = rules.copy()
		with_apprenti.use_apprenti()
		if _can_win(with_apprenti, budget):
			return true
	for id: int in _head_first(rules, rules.board_vehicles()):
		if not rules.can_use_coxeur(id):
			return false
		var clone: GameRules = rules.copy()
		clone.use_coxeur(id)
		if _can_win(clone, budget):
			return true
		if _aborted():
			return false
	return false


func _head_first(rules: GameRules, ids: PackedInt32Array) -> PackedInt32Array:
	var heads: PackedInt32Array = rules.head_vehicles()
	var ordered: PackedInt32Array = PackedInt32Array()
	for id: int in ids:
		if heads.has(id):
			ordered.append(id)
	for id: int in ids:
		if not heads.has(id):
			ordered.append(id)
	return ordered
