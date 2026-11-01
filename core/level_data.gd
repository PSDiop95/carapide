class_name LevelData
extends Resource
## Données immuables d'un niveau.

var id: int = 0
var slots: int = 0
var board_width: float = 0.0
var board_height: float = 0.0
var vehicles: Array[LevelVehicle] = []
var queue: Array[QueueBlock] = []
var mechanics: Array[String] = []


func passengers_by_dest() -> Dictionary[String, int]:
	var totals: Dictionary[String, int] = {}
	for block: QueueBlock in queue:
		var current: int = totals.get(block.dest, 0)
		totals[block.dest] = current + block.count
	return totals


func capacity_by_dest() -> Dictionary[String, int]:
	var totals: Dictionary[String, int] = {}
	for vehicle: LevelVehicle in vehicles:
		var current: int = totals.get(vehicle.dest, 0)
		totals[vehicle.dest] = current + vehicle.capacity
	return totals


func total_passengers() -> int:
	var total: int = 0
	for block: QueueBlock in queue:
		total += block.count
	return total
