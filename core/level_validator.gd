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
