class_name AnalyticsService
extends RefCounted
## Interface d'analytics. Implémentation par défaut : mock qui mémorise les événements.

var logged_events: Array[String] = []
var logged_params: Array[Dictionary] = []
## Numéro du testeur en cours, pour séparer les joueurs d'un même téléphone.
var tester: int = 1


func log_event(event_name: String, params: Dictionary = {}) -> void:
	logged_events.append(event_name)
	logged_params.append(params)


func csv_text() -> String:
	return ""


func row_count() -> int:
	return 0
