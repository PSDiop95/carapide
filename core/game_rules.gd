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


## Sans `access` : aucun booster, une gare bloquée perd aussitôt.
func _init(level: LevelData, access: BoosterAccess = null, slots: int = level.slots) -> void:
	_level = level
	_access = access if access != null else BoosterAccess.new()
	_board = BoardLogic.new(level)
	_station = StationLogic.new(slots)
	_queue = QueueLogic.new(level.queue)


## Copie indépendante, pour explorer sans toucher à la partie.
func copy(access: BoosterAccess = _access) -> GameRules:
	var clone: GameRules = GameRules._blank(_level, access)
	clone.status = status
	clone._board = _board.copy()
	clone._station = _station.copy()
	clone._queue = _queue.copy()
	return clone


func state_key() -> String:
	return "%s|%s|%s" % [_board.state_key(), _station.state_key(), _queue.state_key()]


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
	var parked: ParkedVehicle = _station.park(vehicle_id, vehicle.dest, vehicle.capacity)
	events.append(GameEvent.moved(vehicle_id, parked.slot))
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
	var parked: ParkedVehicle = _station.park_coxeur(vehicle_id, vehicle.dest, vehicle.capacity)
	events.append(GameEvent.flew(vehicle_id, parked.slot))
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


## Lecture seule : véhicules encore dans le bouchon.
func board_vehicles() -> PackedInt32Array:
	return _board.remaining_vehicles()


## Lecture seule : véhicules de la destination en tête, dans le bouchon.
func head_vehicles() -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	for id: int in _board.remaining_vehicles():
		if _level.vehicles[id].dest == _queue.head_dest():
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


func _resolve_boarding(events: Array[GameEvent]) -> void:
	while not _queue.is_empty():
		var parked: ParkedVehicle = _station.oldest_for(_queue.head_dest())
		if parked == null:
			return
		var amount: int = _queue.take(parked.free_seats())
		parked.loaded += amount
		events.append(GameEvent.boarded(parked, amount))
		if parked.is_full():
			_station.depart(parked)
			events.append(GameEvent.departed(parked))


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
		var rescuable: bool = _coxeur_can_rescue() or _apprenti_can_rescue()
		status = Status.BLOCKED if rescuable else Status.LOST
		events.append(GameEvent.new(GameEvent.Type.RESCUE_NEEDED if rescuable else GameEvent.Type.LOST))


## Faire voler un véhicule d'une autre destination ne débloquerait rien.
func _coxeur_can_rescue() -> bool:
	return _access.can_obtain(BoosterAccess.Kind.COXEUR) and _station.is_coxeur_free() and not head_vehicles().is_empty()


func _apprenti_can_rescue() -> bool:
	return _access.can_obtain(BoosterAccess.Kind.APPRENTI) and _queue.would_reorder(_station.needs_by_slot())


static func _blank(level: LevelData, access: BoosterAccess) -> GameRules:
	var empty: LevelData = LevelData.new()
	empty.slots = 0
	var clone: GameRules = GameRules.new(empty, access)
	clone._level = level
	return clone
