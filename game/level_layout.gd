class_name LevelLayout
extends RefCounted
## Placement à l'écran : file en haut, gare au milieu, bouchon en bas (GDD §2).
## Le monde est le plan XZ : +Y plateau = -Z monde, centré en X.

const SLOT_SPACING: float = 1.75
const STATION_Z: float = -3.0
const QUEUE_Z: float = -7.2
const QUEUE_CELL: float = 0.5
const QUEUE_ROWS: int = 4
const QUEUE_ROW_PITCH: float = 0.75
const HEAD_MARKER_OFFSET: float = 0.6
const SCENE_MARGIN: float = 1.0
const MIN_SCENE_WIDTH: float = 8.0
const ROOF_HEIGHT: float = 0.6
## Bande réservée en haut de scène aux libellés et pancartes de la file.
const HUD_RESERVED_Z: float = 3.2
## Bande réservée en bas de scène à la barre de boosters.
const BOOSTER_BAR_Z: float = 3.0

var board_width: float
var board_height: float
var slots: int
var coxeur_visible: bool
var booster_bar_visible: bool


func _init(level: LevelData, has_coxeur_slot: bool = false, has_booster_bar: bool = false) -> void:
	board_width = level.board_width
	board_height = level.board_height
	slots = level.slots
	coxeur_visible = has_coxeur_slot
	booster_bar_visible = has_booster_bar


func board_to_world(x: float, y: float) -> Vector3:
	return Vector3(x - board_width * 0.5, 0.0, board_height - y)


func world_to_board(point: Vector3) -> Vector2:
	return Vector2(point.x + board_width * 0.5, board_height - point.z)


func slot_world(slot: int) -> Vector3:
	return Vector3((float(slot) - float(_slot_columns() - 1) * 0.5) * SLOT_SPACING, 0.0, STATION_Z)


## Place Coxeur : juste à droite des places normales.
func coxeur_slot() -> int:
	return slots


func _slot_columns() -> int:
	return slots + 1 if coxeur_visible else slots


func scene_width() -> float:
	var station_width: float = float(_slot_columns()) * SLOT_SPACING
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
	return Vector3(x, 0.0, QUEUE_Z - float(row) * QUEUE_ROW_PITCH)


## Repère de tête de file, juste devant le premier passager, côté gare.
func head_marker_world() -> Vector3:
	return queue_world(0) + Vector3.BACK * HEAD_MARKER_OFFSET


func top_z() -> float:
	return QUEUE_Z - float(QUEUE_ROWS) * QUEUE_ROW_PITCH - SCENE_MARGIN - HUD_RESERVED_Z


func bottom_z() -> float:
	return board_height + SCENE_MARGIN + (BOOSTER_BAR_Z if booster_bar_visible else 0.0)
