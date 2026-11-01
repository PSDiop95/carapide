class_name GameRules
extends RefCounted
## Règles du core loop. Une action résout toute la chaîne et renvoie les événements à rejouer.
## PLAYING -> BLOCKED -> (booster) PLAYING | (abandon) LOST.

enum Status { PLAYING, BLOCKED, WON, LOST }

var status: Status = Status.PLAYING

var _level: LevelData
var _board: BoardLogic
var _station: StationLogic
var _queue: QueueLogic
var _access: BoosterAccess
var _garage: GarageLogic = GarageLogic.new()
var _garage_uses: int = 0
## Destination courante de chaque véhicule : le Dioulé la remplace, jamais en place (les copies la partagent).
var _dests: PackedStringArray = PackedStringArray()
## Vide tant qu'aucun Dioulé n'a été joué : la clé d'état reste courte pour le solveur.
var _dest_key: String = ""


## Sans `access` : aucun booster, une gare bloquée perd aussitôt.
func _init(level: LevelData, access: BoosterAccess = null, slots: int = level.slots) -> void:
	_level = level
	_access = access if access != null else BoosterAccess.new()
	_board = BoardLogic.new(level)
	_station = StationLogic.new(slots)
	_queue = QueueLogic.new(level.queue)
	for vehicle: LevelVehicle in level.vehicles:
		_dests.append(vehicle.dest)


## Copie indépendante, pour explorer sans toucher à la partie.
func copy(access: BoosterAccess = _access) -> GameRules:
	var clone: GameRules = GameRules._blank(_level, access)
	clone.status = status
	clone._board = _board.copy()
	clone._station = _station.copy()
	clone._queue = _queue.copy()
	clone._garage = _garage.copy()
	clone._garage_uses = _garage_uses
	clone._dests = _dests
	clone._dest_key = _dest_key
	return clone


## Copie où les véhicules ont ces destinations, pour évaluer un Dioulé.
func with_destinations(dests: PackedStringArray) -> GameRules:
	var clone: GameRules = copy()
	clone._set_destinations(dests)
	return clone


## Copie privée de `count` places libres, pour mesurer la marge. Il doit en rester au moins une.
func with_reserved_slots(count: int) -> GameRules:
	var clone: GameRules = copy()
	clone._station.reserved_slots = count
	return clone


func state_key() -> String:
	return "%s|%s|%s|%s|%s" % [_board.state_key(), _station.state_key(), _queue.state_key(), _dest_key, _garage.state_key()]


func tap(vehicle_id: int) -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	if status != Status.PLAYING or not _board.has_vehicle(vehicle_id):
		return events
	var blocker: int = _board.first_blocker(vehicle_id)
	if blocker != BoardLogic.NO_VEHICLE:
		events.append(GameEvent.blocked(vehicle_id, blocker))
		return events
	var vehicle: LevelVehicle = _level.vehicles[vehicle_id]
	_board.remove(vehicle_id)
	var parked: ParkedVehicle = _station.park(vehicle_id, _dests[vehicle_id], vehicle.capacity)
	events.append(GameEvent.moved(vehicle_id, parked.slot, parked.dest))
	_resolve_boarding(events)
	_update_status(events)
	return events


## Le véhicule quitte le bouchon en ignorant les bloqueurs et se gare sur la place Coxeur.
func use_coxeur(vehicle_id: int) -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	if not can_use_coxeur(vehicle_id):
		return events
	var vehicle: LevelVehicle = _level.vehicles[vehicle_id]
	_board.remove(vehicle_id)
	var parked: ParkedVehicle = _station.park_coxeur(vehicle_id, _dests[vehicle_id], vehicle.capacity)
	events.append(GameEvent.flew(vehicle_id, parked.slot, parked.dest))
	_resume(events)
	return events


## Remonte en tête les passagers manquants des véhicules garés. Sans effet, ne fait rien.
func use_apprenti() -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	if not can_use_apprenti():
		return events
	_queue.prioritize(_station.needs_by_slot())
	events.append(GameEvent.queue_reordered(_queue.blocks()))
	_resume(events)
	return events


## Applique un mélange choisi par DiouleMixer. Véhicules garés et file ne bougent pas.
func use_dioule(dests: PackedStringArray) -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	if not can_use_dioule():
		return events
	_set_destinations(dests)
	var by_vehicle: Dictionary[int, String] = {}
	for id: int in _board.remaining_vehicles():
		by_vehicle[id] = _dests[id]
	events.append(GameEvent.destinations_changed(by_vehicle))
	return events


## Les véhicules garés rejoignent le Garage avec leurs passagers ; la gare gagne une place.
func use_garage() -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	if not can_use_garage():
		return events
	var ids: PackedInt32Array = PackedInt32Array()
	for parked: ParkedVehicle in _station.evacuate_and_grow():
		_garage.store(parked)
		ids.append(parked.vehicle_id)
	_garage_uses += 1
	events.append(GameEvent.garaged(ids, _station.total_slots()))
	_resume(events)
	return events


## Refus explicite des boosters.
func abandon() -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	if status == Status.BLOCKED:
		status = Status.LOST
		events.append(GameEvent.new(GameEvent.Type.LOST))
	return events


func can_use_coxeur(vehicle_id: int) -> bool:
	return _accepts_booster() and _board.has_vehicle(vehicle_id) and _station.is_coxeur_free()


func can_use_apprenti() -> bool:
	return _accepts_booster() and _queue.would_reorder(_station.needs_by_slot())


func can_use_garage() -> bool:
	return status == Status.BLOCKED and _garage_helps()


## Gare bloquée : le bouchon ne peut plus rien pour elle, mélanger ne sauverait pas la partie.
func can_use_dioule() -> bool:
	return status == Status.PLAYING and _board.remaining_count() >= 2


## Lecture seule : destinations courantes, indexées par véhicule.
func destinations() -> PackedStringArray:
	return _dests


func vehicle_capacity(vehicle_id: int) -> int:
	return _level.vehicles[vehicle_id].capacity


## Lecture seule : places libres de la gare, sans les places réservées.
func free_slot_count() -> int:
	return _station.free_slot_count()


## Lecture seule : sièges libres restants par destination, bouchon et gare. Égal à la file à tout instant.
func seats_left_by_dest() -> Dictionary[String, int]:
	var totals: Dictionary[String, int] = _station.free_seats_by_dest()
	_garage.add_free_seats_to(totals)
	for id: int in _board.remaining_vehicles():
		totals[_dests[id]] = totals.get(_dests[id], 0) + vehicle_capacity(id)
	return totals


## Lecture seule : passagers assis dans les véhicules encore là, gare et Garage.
func passengers_aboard() -> int:
	return _station.loaded_total() + _garage.loaded_total()


func garage_size() -> int:
	return _garage.size()


func slot_count() -> int:
	return _station.total_slots()


func passengers_left_by_dest() -> Dictionary[String, int]:
	return _queue.total_by_dest()


## Lecture seule : véhicules encore dans le bouchon.
func board_vehicles() -> PackedInt32Array:
	return _board.remaining_vehicles()


## Lecture seule : véhicules de la destination en tête, dans le bouchon.
func head_vehicles() -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	for id: int in _board.remaining_vehicles():
		if _dests[id] == _queue.head_dest():
			ids.append(id)
	return ids


## Lecture seule : véhicule montré par le tutoriel, de la tête et bloqué de préférence.
func tutorial_vehicle() -> int:
	var heads: PackedInt32Array = head_vehicles()
	if heads.is_empty():
		return BoardLogic.NO_VEHICLE
	for id: int in heads:
		if not _board.can_exit(id):
			return id
	return heads[0]


## Lecture seule, pour la détection du véhicule tapé.
func vehicle_at(x: float, y: float, tolerance: float) -> int:
	return _board.vehicle_at(x, y, tolerance)


## Lecture seule : destination en tête de file, vide si la file est vide.
func head_dest() -> String:
	return _queue.head_dest()


## Lecture seule : places occupées dans la gare.
func occupied_slots() -> int:
	return _station.parked_count()


## Lecture seule : véhicules du bouchon dont la voie est libre, par id croissant.
func free_vehicles() -> PackedInt32Array:
	return _board.free_vehicles()


func passengers_remaining() -> int:
	return _queue.total_remaining()


func _set_destinations(dests: PackedStringArray) -> void:
	_dests = dests
	_dest_key = "".join(dests)


func _resolve_boarding(events: Array[GameEvent]) -> void:
	while not _queue.is_empty():
		var parked: ParkedVehicle = _station.oldest_for(_queue.head_dest())
		if parked == null:
			parked = _recall_for_head(events)
		if parked == null:
			return
		var amount: int = _queue.take(parked.free_seats())
		parked.loaded += amount
		events.append(GameEvent.boarded(parked, amount))
		if parked.is_full():
			_station.depart(parked)
			events.append(GameEvent.departed(parked))


## Une place libre et un véhicule du Garage attendu en tête : le plus rempli revient.
func _recall_for_head(events: Array[GameEvent]) -> ParkedVehicle:
	if _station.is_full():
		return null
	var parked: ParkedVehicle = _garage.take_fullest(_queue.head_dest())
	if parked != null:
		_station.park_returning(parked)
		events.append(GameEvent.recalled(parked))
	return parked


func _resume(events: Array[GameEvent]) -> void:
	status = Status.PLAYING
	_resolve_boarding(events)
	_update_status(events)


func _accepts_booster() -> bool:
	return status == Status.PLAYING or status == Status.BLOCKED


func _update_status(events: Array[GameEvent]) -> void:
	if _queue.is_empty():
		status = Status.WON
		events.append(GameEvent.new(GameEvent.Type.WON))
	elif _station.is_full() or not _board.any_can_exit():
		var rescuable: bool = _coxeur_can_rescue() or _apprenti_can_rescue() or _garage_can_rescue()
		status = Status.BLOCKED if rescuable else Status.LOST
		events.append(GameEvent.new(GameEvent.Type.RESCUE_NEEDED if rescuable else GameEvent.Type.LOST))


## Faire voler un véhicule d'une autre destination ne débloquerait rien.
func _coxeur_can_rescue() -> bool:
	return _access.can_obtain(BoosterAccess.Kind.COXEUR) and _station.is_coxeur_free() and not head_vehicles().is_empty()


func _apprenti_can_rescue() -> bool:
	return _access.can_obtain(BoosterAccess.Kind.APPRENTI) and _queue.would_reorder(_station.needs_by_slot())


func _garage_can_rescue() -> bool:
	return _access.can_obtain(BoosterAccess.Kind.GARAGE) and _garage_helps()


## Gare vide après coup : utile seulement si un véhicule peut alors la rejoindre.
func _garage_helps() -> bool:
	if _garage_uses >= _access.garage_max_uses() or not _station.is_full():
		return false
	return _board.any_can_exit() or _garage.has_dest(_queue.head_dest())


static func _blank(level: LevelData, access: BoosterAccess) -> GameRules:
	var empty: LevelData = LevelData.new()
	empty.slots = 0
	var clone: GameRules = GameRules.new(empty, access)
	clone._level = level
	return clone
