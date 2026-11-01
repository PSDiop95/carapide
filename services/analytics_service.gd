class_name AnalyticsService
extends RefCounted
## Interface d'analytics. Implémentation par défaut : mock qui mémorise les événements.

var logged_events: Array[String] = []


func log_event(event_name: String) -> void:
	logged_events.append(event_name)
