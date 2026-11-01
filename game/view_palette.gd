class_name ViewPalette
extends RefCounted
## Meshes et matériaux partagés, pour rester sous le budget de draw calls.

const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.35)
const ARROW_SHAFT_LENGTH: float = 0.6
const ARROW_SHAFT_HALF_WIDTH: float = 0.09
const ARROW_HEAD_LENGTH: float = 0.45
const ARROW_HEAD_HALF_WIDTH: float = 0.3
const HIGHLIGHT_COLOR: Color = Color(1.0, 1.0, 1.0)
const OUTLINE_LENGTH_GAP: float = 0.08
const PICTO_OUTLINE_SCALE: float = 1.3
const PICTO_OUTLINE_COLOR: Color = Color(0.05, 0.05, 0.05)
const PICTO_INNER_LIFT: float = 0.004

var arrow_mesh: ArrayMesh = _build_arrow_mesh()
var arrow_material: StandardMaterial3D = _flat_material(Color.WHITE)
var highlight_material: StandardMaterial3D = _flat_material(HIGHLIGHT_COLOR)
var picto_material: StandardMaterial3D = _picto_material()
var shadow_material: StandardMaterial3D = _shadow_material()

var _config: PresentationConfig
var _dest_materials: Dictionary[String, StandardMaterial3D] = {}
var _body_meshes: Dictionary[String, BoxMesh] = {}
var _picto_meshes: Dictionary[String, ArrayMesh] = {}


func _init(config: PresentationConfig) -> void:
	_config = config


static func _shadow_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = SHADOW_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


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


## Pictogramme de la destination : blanc cerné de sombre, à plat, rayon 1, une seule surface.
func picto_mesh(dest: String) -> ArrayMesh:
	var shape: String = _config.picto_of(dest)
	if not _picto_meshes.has(shape):
		_picto_meshes[shape] = _build_picto_mesh(PictoShapes.points(shape))
	return _picto_meshes[shape]


static func _picto_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = _flat_material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	return material


static func _build_picto_mesh(outline: PackedVector2Array) -> ArrayMesh:
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	var points: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	for index: int in triangles:
		points.append(Vector3(outline[index].x * PICTO_OUTLINE_SCALE, 0.0, -outline[index].y * PICTO_OUTLINE_SCALE))
		colors.append(PICTO_OUTLINE_COLOR)
	for index: int in triangles:
		points.append(Vector3(outline[index].x, PICTO_INNER_LIFT, -outline[index].y))
		colors.append(Color.WHITE)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


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
