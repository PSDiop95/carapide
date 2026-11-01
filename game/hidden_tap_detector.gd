class_name HiddenTapDetector
extends RefCounted
## Détecte N taps rapprochés. Le temps est injecté, pour les tests.

var _required: int
var _window_ms: int
var _times: PackedInt64Array = PackedInt64Array()


func _init(required: int, window_ms: int) -> void:
	_required = required
	_window_ms = window_ms


## Vrai quand ce tap complète la série ; la série repart alors de zéro.
func register(now_ms: int) -> bool:
	_times.append(now_ms)
	if _times.size() > _required:
		_times.remove_at(0)
	if _times.size() < _required or now_ms - _times[0] > _window_ms:
		return false
	_times.clear()
	return true
