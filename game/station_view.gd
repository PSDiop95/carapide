class_name StationView
extends Node3D
## Places de la gare : pictogramme de la destination garée. Le danger colore le fond, jamais les places :
## un véhicule rouge doit rester visible sur une gare rouge (GDD §2).

signal critical_entered

enum Danger { NORMAL, WARNING, CRITICAL }

const PAD_SIZE: Vector2 = Vector2(1.5, 5.3)
const PAD_GAP: float = 0.25
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
const COXEUR_PAD_COLOR: Color = Color(0.93, 0.78, 0.3)

var danger: Danger = Danger.NORMAL

var _backdrop_material: StandardMaterial3D = StandardMaterial3D.new()
var _pad_material: StandardMaterial3D = StandardMaterial3D.new()
var _coxeur_material: StandardMaterial3D = StandardMaterial3D.new()
var _config: PresentationConfig
var _palette: ViewPalette
var _slots: int = 0
var _occupied: int = 0
var _pictos: Array[MeshInstance3D] = []
var _layout: LevelLayout
var _built: Array[Node3D] = []
var _pulse: Tween = null


func setup(layout: LevelLayout, config: PresentationConfig, palette: ViewPalette) -> void:
	_config = config
	_palette = palette
	_layout = layout
	_pad_material.albedo_color = PAD_COLOR
	_coxeur_material.albedo_color = COXEUR_PAD_COLOR
	_backdrop_material.albedo_color = NORMAL_COLOR
	_build_pads()


## Le Garage a vidé la gare et ajouté une place : les places sont redessinées, resserrées.
func rebuild_after_garage(slot_count: int) -> void:
	_layout.set_slots(slot_count)
	_occupied = 0
	_build_pads()
	_update_danger()


func _build_pads() -> void:
	for node: Node3D in _built:
		node.queue_free()
	_built.clear()
	_pictos.clear()
	_slots = _layout.slots
	_add_backdrop(_layout)
	var pad: PlaneMesh = PlaneMesh.new()
	pad.size = Vector2(minf(PAD_SIZE.x, _layout.slot_spacing() - PAD_GAP), PAD_SIZE.y)
	for slot: int in _layout.slots:
		_add_pad(pad, _pad_material, _layout.slot_world(slot))
	if _layout.coxeur_visible:
		_add_pad(pad, _coxeur_material, _layout.slot_world(_layout.coxeur_slot()))


## Le niveau de danger selon les places libres.
static func danger_for(free_slots: int, warning_free: int, critical_free: int) -> Danger:
	if free_slots <= critical_free:
		return Danger.CRITICAL
	if free_slots <= warning_free:
		return Danger.WARNING
	return Danger.NORMAL


## La place Coxeur (dernière) ne compte pas dans le danger.
func vehicle_arrived(slot: int, dest: String) -> void:
	if slot < _slots:
		_occupied += 1
	_pictos[slot].mesh = _palette.picto_mesh(dest)
	_pictos[slot].visible = true
	_update_danger()


func vehicle_departed(slot: int) -> void:
	if slot < _slots:
		_occupied -= 1
	_pictos[slot].visible = false
	_update_danger()


func _add_pad(pad: PlaneMesh, material: StandardMaterial3D, slot_position: Vector3) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = pad
	instance.material_override = material
	instance.position = slot_position + Vector3(0.0, PAD_Y, PAD_CENTER_OFFSET_Z)
	add_child(instance)
	_built.append(instance)
	_pictos.append(_add_picto(slot_position))


func _add_backdrop(layout: LevelLayout) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(float(layout.slots) * layout.slot_spacing(), PAD_SIZE.y) + Vector2.ONE * BACKDROP_MARGIN
	var backdrop: MeshInstance3D = MeshInstance3D.new()
	backdrop.mesh = plane
	backdrop.material_override = _backdrop_material
	var center_x: float = (layout.slot_world(0).x + layout.slot_world(layout.slots - 1).x) * 0.5
	backdrop.position = Vector3(center_x, BACKDROP_Y, LevelLayout.STATION_Z + PAD_CENTER_OFFSET_Z)
	add_child(backdrop)
	_built.append(backdrop)


func _add_picto(slot_position: Vector3) -> MeshInstance3D:
	var picto: MeshInstance3D = MeshInstance3D.new()
	picto.material_override = _palette.picto_material
	picto.position = slot_position + Vector3(0.0, PICTO_Y, PICTO_OFFSET_Z)
	picto.scale = Vector3.ONE * PICTO_RADIUS
	picto.visible = false
	add_child(picto)
	_built.append(picto)
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
