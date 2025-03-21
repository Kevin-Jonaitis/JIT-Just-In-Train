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

# Chat-gpt generated
static func compute_polygon_uvs(polygon: Array[Vector2]) -> Array[Vector2]:
	var uvs: Array[Vector2] = []
	var total_length: float = 0.0
	var count: int = polygon.size()
	for i: int in range(count):
		var next_i: int = (i + 1) % count
		total_length += polygon[i].distance_to(polygon[next_i])
	
	var cum_length: float = 0.0
	for i: int in range(count):
		if i > 0:
			cum_length += polygon[i - 1].distance_to(polygon[i])
		var v: float = cum_length
		uvs.append(Vector2(0.0, v))

	# Duplicate the first UV with v = 1.0 to close the loop.
	uvs.append(Vector2(0.0, total_length))
	return uvs

## TODO: Use this?
# Alterantive: use Surfacetool(we don't have to calculate the tagents OR normals ourselves(though the normals weren't too bad))
static func compute_triangle_tangent(v0: Vector3, v1: Vector3, v2: Vector3, uv0: Vector2, uv1: Vector2, uv2: Vector2) -> Plane:
	var edge1: Vector3 = v1 - v0
	var edge2: Vector3 = v2 - v0
	var deltaUV1: Vector2 = uv1 - uv0
	var deltaUV2: Vector2 = uv2 - uv0
	var det: float = deltaUV1.x * deltaUV2.y - deltaUV1.y * deltaUV2.x
	var r: float = 1.0 / det if (abs(det) > 0.0001) else  1.0
	var tangent: Vector3 = (edge1 * deltaUV2.y - edge2 * deltaUV1.y) * r
	tangent = tangent.normalized()
	# The tangent is stored as a Vector4, where the w component usually represents handedness.
	# For many cases, you can set w = 1.0 (or -1.0 if needed).
	return Plane(tangent, 1.0)

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

# Utility function to add a single triangle's data (unindexed) to the arrays.
# We store each triangle as 3 consecutive vertices, normals, and UVs.
static func add_triangle(
	vertex_array: PackedVector3Array,
	normal_array: PackedVector3Array,
	uv_array: PackedVector2Array,
	index_array: PackedInt32Array,
	v0: Vector3, n0: Vector3, uv0: Vector2,
	v1: Vector3, n1: Vector3, uv1: Vector2,
	v2: Vector3, n2: Vector3, uv2: Vector2
) -> void:

	# We'll just append these 3 new vertices to the end for now:
	var base_index: int = vertex_array.size()

	# Push the vertex data:
	vertex_array.push_back(v0)
	normal_array.push_back(n0)
	uv_array.push_back(uv0)

	vertex_array.push_back(v1)
	normal_array.push_back(n1)
	uv_array.push_back(uv1)

	vertex_array.push_back(v2)
	normal_array.push_back(n2)
	uv_array.push_back(uv2)

	# Now add the indices referencing them:
	index_array.push_back(base_index)
	index_array.push_back(base_index + 1)
	index_array.push_back(base_index + 2)

# Triangulate the polygon and apply front/back transforms for end caps.
# No nested functions here – everything top-level.
static func build_end_caps(
	polygon_2d: Array[Vector2],
	polygon_uvs: Array[Vector2],
	transforms: Array[Transform3D],
	vertex_array: PackedVector3Array,
	normal_array: PackedVector3Array,
	uv_array: PackedVector2Array,
	index_array: PackedInt32Array,
) -> void:
	var poly_indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon_2d)
	if poly_indices.size() < 3:
		return

	var min_x: float = polygon_2d[0].x
	var min_y: float = polygon_2d[0].y
	var max_x: float = polygon_2d[0].x
	var max_y: float = polygon_2d[0].y

	for pt: Vector2 in polygon_2d:
		min_x = min(min_x, pt.x)
		max_x = max(max_x, pt.x)
		min_y = min(min_y, pt.y)
		max_y = max(max_y, pt.y)
		
	# At beginning, start at 0 at the top, and start at top of range, and go down
	var face_uvs: Array[Vector2] = []
	for i: int in range(polygon_2d.size()):
		var pt: Vector2 = polygon_2d[i]
		#noramlize between range_x and range_y
		var u_offset: float = pt.x - max_x
		var v_offset: float = pt.y - max_y
		var u_normalized: float = u_offset
		var v_normalized: float = v_offset
		
		face_uvs.append(Vector2(u_normalized, v_normalized))

	# -- FRONT CAP --
	var front_transform: Transform3D = transforms[0]
	var front_vertices : Array[Vector3] = []
	for i: int in range(polygon_2d.size()):
		var v2: Vector2 = polygon_2d[i]
		front_vertices.append(front_transform * (Vector3(v2.x, v2.y, 0.0)))

	# Build each triangle in normal orientation (invert = false).
	for i: int in range(0, poly_indices.size(), 3):
		var idx0: int = poly_indices[i]
		var idx1: int = poly_indices[i + 1]
		var idx2: int = poly_indices[i + 2]
		var vA: Vector3 = front_vertices[idx0]
		var vB: Vector3 = front_vertices[idx1]
		var vC: Vector3 = front_vertices[idx2]
		var uvA: Vector2 = face_uvs[idx0]
		var uvB: Vector2 = face_uvs[idx1]
		var uvC: Vector2 = face_uvs[idx2]
		var normal: Vector3 = (vC - vA).cross(vB - vA).normalized()

		add_triangle(
			vertex_array, normal_array, uv_array, index_array,
			vA, normal, uvA,
			vB, normal, uvB,
			vC, normal, uvC
		)

	# -- BACK CAP (invert so normals face outward) --
	var back_transform: Transform3D = transforms[transforms.size() - 1]
	var back_vertices : Array[Vector3] = []
	for i: int in range(polygon_2d.size()):
		var v2b: Vector2 = polygon_2d[i]
		back_vertices.append(back_transform * Vector3(v2b.x, v2b.y, 0.0))

	for i: int in range(0, poly_indices.size(), 3):
		var idx0b: int = poly_indices[i]
		var idx1b: int = poly_indices[i + 1]
		var idx2b: int = poly_indices[i + 2]
		var vA_b: Vector3 = back_vertices[idx2b]
		var vB_b: Vector3 = back_vertices[idx1b]
		var vC_b: Vector3 = back_vertices[idx0b]
		var uvA_b: Vector2 = face_uvs[idx2b]
		var uvB_b: Vector2 = face_uvs[idx1b]
		var uvC_b: Vector2 = face_uvs[idx0b]
		var normal_b: Vector3 = (vC_b - vA_b).cross(vB_b - vA_b).normalized()

		add_triangle(
			vertex_array, normal_array, uv_array, index_array,
			vA_b, normal_b, uvA_b,
			vB_b, normal_b, uvB_b,
			vC_b, normal_b, uvC_b
		)

# Build ring transforms for each path point.
static func build_ring_transforms(path_points: Array[Vector3]) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	if path_points.size() < 2:
		return transforms

	for i: int in range(path_points.size()):
		var face_transform: Transform3D = Transform3D.IDENTITY
		if i == 0 and path_points.size() > 1:
			var direction: Vector3 = path_points[1] - path_points[0]
			face_transform = face_transform.looking_at(direction, Vector3.UP, true)
			face_transform = face_transform.translated(path_points[i])
		elif i < path_points.size() - 1:
			var prev_dir: Vector3 = path_points[i] - path_points[i - 1]
			var next_dir: Vector3 = path_points[i + 1] - path_points[i]
			var direction2: Vector3 = (prev_dir + next_dir)
			face_transform = face_transform.looking_at(direction2, Vector3.UP, true)
			face_transform = face_transform.translated(path_points[i])
		elif i == path_points.size() - 1:
			var direction_last: Vector3 = path_points[i] - path_points[i - 1]
			face_transform = face_transform.looking_at(direction_last, Vector3.UP, true)
			face_transform = face_transform.translated(path_points[i])
		transforms.append(face_transform)

	return transforms


# MAIN FUNCTION
# Build an ArrayMesh from extruding a 2D polygon along a path, unindexed geometry.
static func extrude_polygon_along_path_arraymesh(
	polygon_2d: Array[Vector2],
	path_points: Array[Vector3],
	out_mesh: ArrayMesh
) -> void:
	MeshGenerator.extrude_polygon_along_path_arraymesh(polygon_2d, path_points, out_mesh)
	# TrackArrayBuilder.PrintNodeName()
	var vertex_map: Dictionary[Vector3, Dictionary] = {}

	# 1) Precompute polygon UVs
	var polygon_uvs: Array[Vector2] = compute_polygon_uvs(polygon_2d)

	# 2) Compute cumulative distances (for potential UV logic)
	var total_length: float = 0.0
	var cumulative_dist: Array[float] = [0.0]
	for i: int in range(1, path_points.size()):
		total_length += path_points[i - 1].distance_to(path_points[i])
		cumulative_dist.append(total_length)

	# 3) Build ring transforms
	var transforms: Array[Transform3D] = build_ring_transforms(path_points)

	# 4) Prepare arrays (unindexed)
	var vertex_array: PackedVector3Array = PackedVector3Array()
	var normal_array: PackedVector3Array = PackedVector3Array()
	var uv_array: PackedVector2Array = PackedVector2Array()
	var index_array: PackedInt32Array = PackedInt32Array()

	var prev_global_points: Array[Vector3] = []
	var current_global_points: Array[Vector3] = []
	var vA: Vector3
	var vB: Vector3
	var vC: Vector3
	var vD: Vector3
	var vA_uv: Vector2
	var vB_uv: Vector2
	var vC_uv: Vector2
	var vD_uv: Vector2
	var previous_simplify_dir: Vector3 = Vector3.ZERO  # (declare this outside the loop)
	const ANGLE_DIFF : float = 0.0872665 # 5 degrees in radians
	var angle_simplify_dot: float = cos(ANGLE_DIFF) 
	var previous_ring_i: int = 0



	# Build side walls
	for ring_i: int in range(transforms.size()):
		current_global_points.clear()
		var t: Transform3D = transforms[ring_i]

		# Convert each 2D vertex
		for j: int in range(polygon_2d.size()):
			var v2: Vector2 = polygon_2d[j]
			current_global_points.append(t * Vector3(v2.x, v2.y, 0.0))
		# Duplicate first vertex
		current_global_points.append(current_global_points[0])

		if ring_i > 0:

			var prev_point: Vector3 = transforms[ring_i - 1].origin
			var curr_point: Vector3 = transforms[ring_i].origin
			var current_extrusion_dir: Vector3 = (curr_point - prev_point).normalized()
			#// If the turn is very slight (dot product near 1), then skip creating a new ring:
			if ANGLE_DIFF > 0.0 and ring_i > 1 and ring_i != transforms.size() - 1 and previous_simplify_dir.dot(current_extrusion_dir) > angle_simplify_dot:
				# You can either "skip" this ring completely or merge it with the previous one.
				# For example, simply skip adding faces for this ring:
				continue
			else:
				previous_simplify_dir = current_extrusion_dir


			var ring_size: int = polygon_2d.size() + 1
			for j: int in range(ring_size):
				var j_next: int = (j + 1) % ring_size

				vA = prev_global_points[j]
				vB = prev_global_points[j_next]
				vC = current_global_points[j_next]
				vD = current_global_points[j]

				# Example UV logic (u from cumulative_dist, v from polygon_uvs)
				var u_prev: float = cumulative_dist[previous_ring_i]
				var u_next: float = cumulative_dist[ring_i]
				var v_prev_uv: Vector2 = polygon_uvs[j]
				var v_next_uv: Vector2 = polygon_uvs[j_next]

				vA_uv = Vector2(1.0 - u_prev, v_prev_uv.y)
				vB_uv = Vector2(1.0 - u_prev, v_next_uv.y)
				vC_uv = Vector2(1.0 - u_next, v_next_uv.y)
				vD_uv = Vector2(1.0 - u_next, v_prev_uv.y)

				# Triangle 1: (vA, vB, vC)
				var normal1: Vector3 = (vC - vA).cross(vB - vA).normalized()
				add_triangle(
					vertex_array, normal_array, uv_array, index_array,
					vA, normal1, vA_uv,
					vB, normal1, vB_uv,
					vC, normal1, vC_uv
				)

				# Triangle 2: (vC, vD, vA)
				var normal2: Vector3 = (vA - vC).cross(vD - vC).normalized()
				add_triangle(
					vertex_array, normal_array, uv_array, index_array,
					vC, normal2, vC_uv,
					vD, normal2, vD_uv,
					vA, normal2, vA_uv
				)
			previous_ring_i = ring_i # Used so we know the previous value incase we skip over some due to our polygon simplification

		prev_global_points = current_global_points.duplicate(true)

	# Build end caps
	build_end_caps(polygon_2d, polygon_uvs, transforms,
		vertex_array, normal_array, uv_array, index_array
	)

	# Create the ArrayMesh from the final arrays
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_NORMAL] = normal_array
	arrays[Mesh.ARRAY_TEX_UV] = uv_array
	arrays[Mesh.ARRAY_INDEX] = index_array
	# No index array => unindexed triangle list

	set_the_arrays(out_mesh, arrays)
	# out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# return out_mesh

static func set_the_arrays(mesh: ArrayMesh, arrays: Array) -> void:
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
