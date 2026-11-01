class_name LevelLayout
extends RefCounted
## Placement à l'écran : file en haut, gare au milieu, bouchon en bas (GDD §2).
## Le monde est le plan XZ : +Y plateau = -Z monde, centré en X.

const SLOT_SPACING: float = 1.75
const STATION_Z: float = -3.0
const QUEUE_Z: float = -6.0
const QUEUE_CELL: float = 0.5
const QUEUE_ROWS: int = 4
const SCENE_MARGIN: float = 1.0
const MIN_SCENE_WIDTH: float = 8.0
const ROOF_HEIGHT: float = 0.6

var board_width: float
var board_height: float
var slots: int


func _init(level: LevelData) -> void:
	board_width = level.board_width
	board_height = level.board_height
	slots = level.slots


func board_to_world(x: float, y: float) -> Vector3:
	return Vector3(x - board_width * 0.5, 0.0, board_height - y)


func world_to_board(point: Vector3) -> Vector2:
	return Vector2(point.x + board_width * 0.5, board_height - point.z)


func slot_world(slot: int) -> Vector3:
	return Vector3((float(slot) - float(slots - 1) * 0.5) * SLOT_SPACING, 0.0, STATION_Z)


func scene_width() -> float:
	var station_width: float = float(slots) * SLOT_SPACING
	return maxf(maxf(board_width, station_width), MIN_SCENE_WIDTH) + SCENE_MARGIN


func queue_columns() -> int:
	return floori((scene_width() - SCENE_MARGIN) / QUEUE_CELL)


func queue_capacity() -> int:
	return queue_columns() * QUEUE_ROWS


## Position du passager de rang `index` : file en serpentin, la tête près de la gare.
func queue_world(index: int) -> Vector3:
	var columns: int = queue_columns()
	var row: int = floori(float(index) / float(columns))
	var column: int = index - row * columns
	if row % 2 == 1:
		column = columns - 1 - column
	var x: float = (float(column) - float(columns - 1) * 0.5) * QUEUE_CELL
	return Vector3(x, 0.0, QUEUE_Z - float(row) * QUEUE_CELL)


func top_z() -> float:
	return QUEUE_Z - float(QUEUE_ROWS) * QUEUE_CELL - SCENE_MARGIN


func bottom_z() -> float:
	return board_height + SCENE_MARGIN


## Point du bord du plateau atteint en suivant la flèche, avant-train dehors.
func exit_point(vehicle: LevelVehicle) -> Vector3:
	var box: OrientedBox = OrientedBox.from_vehicle(vehicle)
	var to_edge: float = INF
	if not is_zero_approx(box.dir_x):
		var edge_x: float = board_width if box.dir_x > 0.0 else 0.0
		to_edge = minf(to_edge, (edge_x - vehicle.pos_x) / box.dir_x)
	if not is_zero_approx(box.dir_y):
		var edge_y: float = board_height if box.dir_y > 0.0 else 0.0
		to_edge = minf(to_edge, (edge_y - vehicle.pos_y) / box.dir_y)
	var travel: float = to_edge + vehicle.length * 0.5
	return board_to_world(vehicle.pos_x + box.dir_x * travel, vehicle.pos_y + box.dir_y * travel)
