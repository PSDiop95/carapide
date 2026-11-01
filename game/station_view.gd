class_name StationView
extends Node3D
## Places de la gare. La couleur signale le danger selon les places restantes (GDD §2).

const PAD_SIZE: Vector2 = Vector2(1.5, 4.4)
const PAD_Y: float = 0.01
const NORMAL_COLOR: Color = Color(0.72, 0.72, 0.72)
const WARNING_COLOR: Color = Color(0.95, 0.6, 0.15)
const CRITICAL_COLOR: Color = Color(0.9, 0.2, 0.15)

var _material: StandardMaterial3D = StandardMaterial3D.new()
var _config: PresentationConfig
var _slots: int = 0
var _occupied: int = 0


func setup(layout: LevelLayout, config: PresentationConfig) -> void:
	_config = config
	_slots = layout.slots
	_material.albedo_color = NORMAL_COLOR
	var pad: PlaneMesh = PlaneMesh.new()
	pad.size = PAD_SIZE
	for slot: int in layout.slots:
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.mesh = pad
		instance.material_override = _material
		instance.position = layout.slot_world(slot) + Vector3.UP * PAD_Y
		add_child(instance)


func vehicle_arrived() -> void:
	_occupied += 1
	_update_danger()


func vehicle_departed() -> void:
	_occupied -= 1
	_update_danger()


func _update_danger() -> void:
	var free_slots: int = _slots - _occupied
	if free_slots <= _config.danger_critical_free_slots:
		_material.albedo_color = CRITICAL_COLOR
	elif free_slots <= _config.danger_warning_free_slots:
		_material.albedo_color = WARNING_COLOR
	else:
		_material.albedo_color = NORMAL_COLOR
