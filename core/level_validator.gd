class_name LevelValidator
extends RefCounted
## Règles de cohérence d'un niveau.

const PASSENGER_MULTIPLE: int = 2


static func validate(level: LevelData) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if level.slots <= 0:
		errors.append("Niveau %d : nombre de places invalide (%d)" % [level.id, level.slots])
	if level.board_width <= 0.0 or level.board_height <= 0.0:
		errors.append("Niveau %d : plateau invalide" % level.id)
	_check_blocks(level, errors)
	_check_balance(level, errors)
	_check_geometry(level, errors)
	return errors


static func _check_blocks(level: LevelData, errors: PackedStringArray) -> void:
	for block: QueueBlock in level.queue:
		if block.count <= 0:
			errors.append("Niveau %d : bloc vide pour %s" % [level.id, block.dest])


static func _check_balance(level: LevelData, errors: PackedStringArray) -> void:
	var passengers: Dictionary[String, int] = level.passengers_by_dest()
	var capacities: Dictionary[String, int] = level.capacity_by_dest()
	var dests: Dictionary[String, bool] = {}
	for dest: String in passengers:
		dests[dest] = true
	for dest: String in capacities:
		dests[dest] = true
	for dest: String in dests:
		var waiting: int = passengers.get(dest, 0)
		var seats: int = capacities.get(dest, 0)
		if waiting != seats:
			errors.append("Niveau %d : %s a %d passagers pour %d places" % [level.id, dest, waiting, seats])
		if waiting % PASSENGER_MULTIPLE != 0:
			errors.append("Niveau %d : %s a un nombre impair de passagers (%d)" % [level.id, dest, waiting])


static func _check_geometry(level: LevelData, errors: PackedStringArray) -> void:
	var boxes: Array[OrientedBox] = []
	for vehicle: LevelVehicle in level.vehicles:
		var box: OrientedBox = OrientedBox.from_vehicle(vehicle)
		if not box.fits_in_board(level.board_width, level.board_height):
			errors.append("Niveau %d : véhicule %d hors plateau" % [level.id, vehicle.id])
		for other_id: int in boxes.size():
			if box.overlaps(boxes[other_id]):
				errors.append("Niveau %d : véhicules %d et %d se chevauchent" % [level.id, other_id, vehicle.id])
		boxes.append(box)
	if errors.is_empty() and not _has_exit_order(level):
		errors.append("Niveau %d : aucun ordre de sortie ne vide le bouchon" % level.id)


## Une sortie ne fait que libérer de la place : le glouton suffit à conclure.
static func _has_exit_order(level: LevelData) -> bool:
	var board: BoardLogic = BoardLogic.new(level)
	var progressed: bool = true
	while progressed:
		progressed = false
		for vehicle: LevelVehicle in level.vehicles:
			if board.can_exit(vehicle.id):
				board.remove(vehicle.id)
				progressed = true
	return board.remaining_count() == 0
