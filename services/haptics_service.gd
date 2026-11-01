class_name HapticsService
extends RefCounted
## Interface de vibration. Implémentation par défaut : mock pour le desktop et les tests.

var vibrations_ms: PackedInt32Array = PackedInt32Array()
## Réglage du joueur : le jeu appelle vibrate() sans le connaître.
var enabled: bool = true


func vibrate(duration_ms: int) -> void:
	if enabled:
		_vibrate(duration_ms)


func _vibrate(duration_ms: int) -> void:
	vibrations_ms.append(duration_ms)
