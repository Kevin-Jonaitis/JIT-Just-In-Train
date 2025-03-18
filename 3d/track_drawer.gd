extends RefCounted

class_name TrackDrawer

static var RAIL_GLB_PATH: String = "res://Assets/imported/fixing_up_dont_change_y_flip_normals.glb"
static var RAIL_POLYGON_SAVE_PATH: String = "res://rail_ordered.res"
static var RAIL_POLYGON_VERTICIES: PackedVector2Array = load_vertex_resource(RAIL_POLYGON_SAVE_PATH)


static func load_vertex_resource(path: String) -> Array[Vector2]:
	var test : GDExample = GDExample.new()
	test.amplitude = 40
	var res: Resource = load(path)
	if res == null:
		PolygonGenerator.generate_polygon_from_glb(RAIL_GLB_PATH, RAIL_POLYGON_SAVE_PATH)
	res = load(path)
	if res is VertexPolygon:
		var cast_res: VertexPolygon = res as VertexPolygon

		# Adjust every vertex by height!
		if cast_res.offset_height == 0:
			assert(false, "The height _probably_ shouldn't be 0, this is an error")
		for i: int in range(cast_res.vertices.size()):
			var v: Vector2 = cast_res.vertices[i]
			cast_res.vertices[i] = Vector2(v.x, v.y + cast_res.offset_height)
			

		return (res as VertexPolygon).vertices
	else:
		assert(false, "Failed to load vertex resource at: " + path)
		return []

static func set_line_attributes(line: Line3D, points_2d: Array[Vector2], y_index: int, color: Color, transparency: float) -> void:
	var y_value: float = Utils.get_y_layer(y_index)
	var points: PackedVector3Array = PackedVector3Array()
	for point : Vector2 in points_2d:
		points.append(Vector3(point.x, y_value, point.y))
	line.points = points
	line.color = color
	line.curve_normals = calculate_normals_from_points(points)
	# line.transparency = 0.1
	line.billboard_mode = Line3D.BillboardMode.NONE
	line.rebuild()
	

# WE ASSUME THAT ALL POINTS LINE ON THE SAME FLAT(XZ) plane,
# hence husing Vector3 as our reference
static func calculate_normals_from_points(points: Array[Vector3]) -> PackedVector3Array:
	var normals: PackedVector3Array = PackedVector3Array()
	for i: int in range(points.size() - 1):
		var direction: Vector3 = points[i + 1] - points[i]
		direction.cross(Vector3.UP).normalized()
		var normal: Vector3 = Vector3(-direction.z, 0, direction.x).normalized()
		normals.append(normal)
	# Add the last normal
	if points.size() > 1:
		var last_direction: Vector3 = points[-1] - points[-2]
		last_direction.cross(Vector3.UP).normalized()
		#We should reverse the direction for the last normal
		var last_normal: Vector3 = Vector3(-last_direction.z, 0, last_direction.x).normalized()
		normals.append(last_normal)
	return normals


# MAIN FUNCTION
# Build an ArrayMesh from extruding a 2D polygon along a path, unindexed geometry.
static func extrude_polygon_along_path_arraymesh(
	polygon_2d: Array[Vector2],
	path_points: Array[Vector3],
	out_mesh: ArrayMesh
) -> void:
	MeshGenerator.extrude_polygon_along_path_arraymesh(polygon_2d, path_points, out_mesh)
