class_name LevelSpec
extends RefCounted
## Cahier des charges d'un niveau à générer.

var id: int
var board: Vector2
var types: Array[String]
var angles: Array[float]
var dests: Array[String]
var vehicles: int
var target_margin: int
var slots: int = 4


static func make(level_id: int, board_size: Vector2, level_types: Array[String], level_angles: Array[float], level_dests: Array[String], vehicle_count: int, margin: int) -> LevelSpec:
	var spec: LevelSpec = LevelSpec.new()
	spec.id = level_id
	spec.board = board_size
	spec.types = level_types
	spec.angles = level_angles
	spec.dests = level_dests
	spec.vehicles = vehicle_count
	spec.target_margin = margin
	return spec
