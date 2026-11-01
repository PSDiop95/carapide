class_name StationView
extends Node3D
## Places de la gare : pictogramme de la destination garée. Le danger colore le fond, jamais les places :
## un véhicule rouge doit rester visible sur une gare rouge (GDD §2).

signal critical_entered

enum Danger { NORMAL, WARNING, CRITICAL }

const PAD_SIZE: Vector2 = Vector2(1.5, 5.3)
const PAD_CENTER_OFFSET_Z: float = -0.45
const PAD_Y: float = 0.01
const PICTO_OFFSET_Z: float = -2.55
const PICTO_Y: float = 0.02
const PICTO_RADIUS: float = 0.32
const BACKDROP_MARGIN: float = 0.3
const BACKDROP_Y: float = 0.005
const PAD_COLOR: Color = Color(0.62, 0.62, 0.6)
const NORMAL_COLOR: Color = Color(0.5, 0.5, 0.5)
const WARNING_COLOR: Color = Color(0.95, 0.6, 0.15)
const CRITICAL_COLOR: Color = Color(0.9, 0.2, 0.15)

var danger: Danger = Danger.NORMAL

var _backdrop_material: StandardMaterial3D = StandardMaterial3D.new()
var _pad_material: StandardMaterial3D = StandardMaterial3D.new()
var _config: PresentationConfig
var _palette: ViewPalette
var _slots: int = 0
var _occupied: int = 0
var _pictos: Array[MeshInstance3D] = []
var _pulse: Tween = null


func setup(layout: LevelLayout, config: PresentationConfig, palette: ViewPalette) -> void:
	_config = config
	_palette = palette
	_slots = layout.slots
	_add_backdrop(layout)
	_pad_material.albedo_color = PAD_COLOR
	var pad: PlaneMesh = PlaneMesh.new()
	pad.size = PAD_SIZE
	for slot: int in layout.slots:
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.mesh = pad
		instance.material_override = _pad_material
		instance.position = layout.slot_world(slot) + Vector3(0.0, PAD_Y, PAD_CENTER_OFFSET_Z)
		add_child(instance)
		_pictos.append(_add_picto(layout.slot_world(slot)))


## Le niveau de danger selon les places libres.
static func danger_for(free_slots: int, warning_free: int, critical_free: int) -> Danger:
	if free_slots <= critical_free:
		return Danger.CRITICAL
	if free_slots <= warning_free:
		return Danger.WARNING
	return Danger.NORMAL


func vehicle_arrived(slot: int, dest: String) -> void:
	_occupied += 1
	_pictos[slot].mesh = _palette.picto_mesh(dest)
	_pictos[slot].visible = true
	_update_danger()


func vehicle_departed(slot: int) -> void:
	_occupied -= 1
	_pictos[slot].visible = false
	_update_danger()


func _add_backdrop(layout: LevelLayout) -> void:
	_backdrop_material.albedo_color = NORMAL_COLOR
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(float(layout.slots) * LevelLayout.SLOT_SPACING, PAD_SIZE.y) + Vector2.ONE * BACKDROP_MARGIN
	var backdrop: MeshInstance3D = MeshInstance3D.new()
	backdrop.mesh = plane
	backdrop.material_override = _backdrop_material
	backdrop.position = Vector3(0.0, BACKDROP_Y, LevelLayout.STATION_Z + PAD_CENTER_OFFSET_Z)
	add_child(backdrop)


func _add_picto(slot_position: Vector3) -> MeshInstance3D:
	var picto: MeshInstance3D = MeshInstance3D.new()
	picto.material_override = _palette.picto_material
	picto.position = slot_position + Vector3(0.0, PICTO_Y, PICTO_OFFSET_Z)
	picto.scale = Vector3.ONE * PICTO_RADIUS
	picto.visible = false
	add_child(picto)
	return picto


func _update_danger() -> void:
	var free_slots: int = _slots - _occupied
	var next: Danger = danger_for(free_slots, _config.danger_warning_free_slots, _config.danger_critical_free_slots)
	if next == danger:
		return
	danger = next
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	match danger:
		Danger.NORMAL:
			_backdrop_material.albedo_color = NORMAL_COLOR
		Danger.WARNING:
			_start_pulse()
		Danger.CRITICAL:
			_backdrop_material.albedo_color = CRITICAL_COLOR
			critical_entered.emit()


## Orange pulsé, une période aller-retour.
func _start_pulse() -> void:
	_backdrop_material.albedo_color = WARNING_COLOR
	var half: float = _config.danger_pulse_period * 0.5
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_backdrop_material, "albedo_color", NORMAL_COLOR, half)
	_pulse.tween_property(_backdrop_material, "albedo_color", WARNING_COLOR, half)
