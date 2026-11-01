class_name LevelPreloader
extends RefCounted
## Prépare le prochain niveau sur un fil de travail, depuis le hub. Jouer n'attend alors plus le disque.

const NO_TASK: int = -1

var _catalog: VehicleCatalog
var _task: int = NO_TASK
var _path: String = ""
var _result: LevelLoadResult = null


func _init(catalog: VehicleCatalog) -> void:
	_catalog = catalog


func start(path: String) -> void:
	_finish_task()
	_path = path
	_result = null
	_task = WorkerThreadPool.add_task(_load)


## Résultat préparé ; un autre chemin que celui préparé est lu tout de suite.
func take(path: String) -> LevelLoadResult:
	_finish_task()
	if path == _path and _result != null:
		return _result
	return LevelLoader.load_file(path, _catalog)


func _finish_task() -> void:
	if _task != NO_TASK:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = NO_TASK


func _load() -> void:
	_result = LevelLoader.load_file(_path, _catalog)
