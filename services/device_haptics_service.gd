class_name DeviceHapticsService
extends HapticsService
## Vibration réelle du téléphone. Sur Android, exige la permission VIBRATE de l'export.


func vibrate(duration_ms: int) -> void:
	Input.vibrate_handheld(duration_ms)
