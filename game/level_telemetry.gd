class_name LevelTelemetry
extends RefCounted
## Télémétrie de playtest d'une partie : compte les coups et transmet à l'analytics.
## Le temps est injecté, pour les tests.

var _analytics: AnalyticsService
var _level: int = 0
var _start_ms: int = 0
var _moves: int = 0
var _blocked: int = 0


func _init(analytics: AnalyticsService) -> void:
	_analytics = analytics


func level_started(level_id: int, now_ms: int) -> void:
	_level = level_id
	_start_ms = now_ms
	_moves = 0
	_blocked = 0
	_analytics.log_event("level_start", {"level": level_id})


func vehicle_moved() -> void:
	_moves += 1


func tap_blocked() -> void:
	_blocked += 1
	_analytics.log_event("tap_blocked", {"level": _level})


func level_won(now_ms: int) -> void:
	_analytics.log_event("level_win", _summary(now_ms))


func level_failed(occupied_slots: int, head_dest: String, now_ms: int) -> void:
	var params: Dictionary = _summary(now_ms)
	params["occupied_slots"] = occupied_slots
	params["head_dest"] = head_dest
	_analytics.log_event("level_fail", params)


func level_restarted() -> void:
	_analytics.log_event("level_restart", {"level": _level})


func _summary(now_ms: int) -> Dictionary:
	var seconds: float = float(now_ms - _start_ms) / 1000.0
	return {"level": _level, "moves": _moves, "blocked_taps": _blocked, "duration_s": snappedf(seconds, 0.1)}
