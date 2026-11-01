class_name CsvAnalyticsService
extends AnalyticsService
## Télémétrie de playtest : une ligne par événement, écrite aussitôt (rien de perdu si le jeu est tué).

const HEADER: String = "tester,session,unix_time,event,level,occupied_slots,head_dest,moves,blocked_taps,duration_s,booster"
const PARAM_COLUMNS: Array[String] = ["level", "occupied_slots", "head_dest", "moves", "blocked_taps", "duration_s", "booster"]

var _path: String
var _session: int = int(Time.get_unix_time_from_system())


func _init(path: String) -> void:
	_path = path


func log_event(event_name: String, params: Dictionary = {}) -> void:
	super.log_event(event_name, params)
	var is_new: bool = not FileAccess.file_exists(_path)
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE if is_new else FileAccess.READ_WRITE)
	if file == null:
		push_error("Télémétrie impossible : %s" % _path)
		return
	file.seek_end()
	if is_new:
		file.store_line(HEADER)
	file.store_line(_row(event_name, params))


func csv_text() -> String:
	return FileAccess.get_file_as_string(_path) if FileAccess.file_exists(_path) else ""


## Lignes d'événements, sans l'en-tête.
func row_count() -> int:
	var lines: int = csv_text().count("\n")
	return maxi(lines - 1, 0)


func _row(event_name: String, params: Dictionary) -> String:
	var cells: PackedStringArray = PackedStringArray([str(tester), str(_session), str(int(Time.get_unix_time_from_system())), event_name])
	for column: String in PARAM_COLUMNS:
		cells.append(str(params.get(column, "")))
	return ",".join(cells)
