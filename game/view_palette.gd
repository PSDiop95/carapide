class_name ViewPalette
extends RefCounted
## Meshes et matériaux partagés, pour rester sous le budget de draw calls.

const ARROW_SHAFT_LENGTH: float = 0.6
const ARROW_SHAFT_HALF_WIDTH: float = 0.09
const ARROW_HEAD_LENGTH: float = 0.45
const ARROW_HEAD_HALF_WIDTH: float = 0.3
const HIGHLIGHT_COLOR: Color = Color(1.0, 1.0, 1.0)
const OUTLINE_LENGTH_GAP: float = 0.08

var arrow_mesh: ArrayMesh = _build_arrow_mesh()
var arrow_material: StandardMaterial3D = _flat_material(Color.WHITE)
var highlight_material: StandardMaterial3D = _flat_material(HIGHLIGHT_COLOR)

var _config: PresentationConfig
var _dest_materials: Dictionary[String, StandardMaterial3D] = {}
var _body_meshes: Dictionary[String, BoxMesh] = {}


func _init(config: PresentationConfig) -> void:
	_config = config


func dest_material(dest: String) -> StandardMaterial3D:
	if not _dest_materials.has(dest):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = _config.color_of(dest)
		_dest_materials[dest] = material
	return _dest_materials[dest]


func body_mesh(length: float, width: float) -> BoxMesh:
	var key: String = "%f:%f" % [length, width]
	if not _body_meshes.has(key):
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(length - OUTLINE_LENGTH_GAP, VehicleView.HEIGHT, width)
		_body_meshes[key] = mesh
	return _body_meshes[key]


static func _flat_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Flèche plate, pointe vers +X local.
static func _build_arrow_mesh() -> ArrayMesh:
	var shaft_end: float = ARROW_SHAFT_LENGTH * 0.5
	var tip: float = shaft_end + ARROW_HEAD_LENGTH
	var points: PackedVector3Array = PackedVector3Array([
		Vector3(-shaft_end, 0.0, -ARROW_SHAFT_HALF_WIDTH), Vector3(shaft_end, 0.0, -ARROW_SHAFT_HALF_WIDTH),
		Vector3(shaft_end, 0.0, ARROW_SHAFT_HALF_WIDTH), Vector3(-shaft_end, 0.0, -ARROW_SHAFT_HALF_WIDTH),
		Vector3(shaft_end, 0.0, ARROW_SHAFT_HALF_WIDTH), Vector3(-shaft_end, 0.0, ARROW_SHAFT_HALF_WIDTH),
		Vector3(shaft_end, 0.0, -ARROW_HEAD_HALF_WIDTH), Vector3(tip, 0.0, 0.0),
		Vector3(shaft_end, 0.0, ARROW_HEAD_HALF_WIDTH),
	])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
