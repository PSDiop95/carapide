class_name GameRules
extends RefCounted
## Règles du core loop. Un tap résout toute la chaîne et renvoie les événements à rejouer.

enum Status { PLAYING, WON, LOST }

var status: Status = Status.PLAYING

var _level: LevelData
var _board: BoardLogic
var _station: StationLogic
var _queue: QueueLogic


func _init(level: LevelData) -> void:
	_level = level
	_board = BoardLogic.new(level)
	_station = StationLogic.new(level.slots)
	_queue = QueueLogic.new(level.queue)


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


## Lecture seule, pour la détection du véhicule tapé.
func vehicle_at(x: float, y: float, tolerance: float) -> int:
	return _board.vehicle_at(x, y, tolerance)


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


func _update_status(events: Array[GameEvent]) -> void:
	if _queue.is_empty():
		status = Status.WON
		events.append(GameEvent.new(GameEvent.Type.WON))
	elif _station.is_full() or not _board.any_can_exit():
		status = Status.LOST
		events.append(GameEvent.new(GameEvent.Type.LOST))
