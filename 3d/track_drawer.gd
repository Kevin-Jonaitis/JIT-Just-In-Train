extends RefCounted

class_name TrackDrawer

static var RAIL_GLB_PATH: String = "res://Assets/imported/fixing_up_dont_change_y_flip_normals.glb"
static var RAIL_POLYGON_SAVE_PATH: String = "res://rail_ordered.res"
static var RAIL_POLYGON_VERTICIES: PackedVector2Array = load_vertex_resource(RAIL_POLYGON_SAVE_PATH)


static func load_vertex_resource(path: String) -> Array[Vector2]:
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


static func extrude_polygon_along_path(
	polygon_2d: Array[Vector2],
	path_points: Array[Vector3],
	immediate_mesh: ImmediateMesh
) -> ImmediateMesh:
	# Early exit if invalid input
	if polygon_2d.is_empty() or path_points.size() < 2:
		return

	# Precompute the UVs for the starting polygon.
	var polygon_uvs: Array[Vector2] = compute_polygon_uvs(polygon_2d)

	# Compute the total length of the path.
	var total_length: float = 0.0
	var cumulative_dist : Array[float] = [0]
	for i: int in range(1, path_points.size()):
		total_length += path_points[i - 1].distance_to(path_points[i])
		cumulative_dist.append(total_length)


	# 2) Create a Transform3D array for each segment of the path
	var transforms: Array[Transform3D] = []

	var points_count: int = path_points.size()
	for i: int in range(points_count):
		var face_transform: Transform3D = Transform3D()			
		if (i == 0):
			var direction: Vector3 = (path_points[1] - path_points[0])
			face_transform = face_transform.looking_at(direction, Vector3.UP, true)
			face_transform = face_transform.translated(path_points[i])
			transforms.append(face_transform)
		elif i < points_count - 1:
			var prev_dir: Vector3 = (path_points[i] - path_points[i - 1])
			var next_dir: Vector3 = (path_points[i + 1] - path_points[i])
			var direction: Vector3 = (prev_dir + next_dir)
			face_transform = face_transform.looking_at(direction, Vector3.UP, true)
			face_transform = face_transform.translated(path_points[i])
			transforms.append(face_transform)
		elif(i == points_count - 1):
			# For the last point, reuse orientation from the previous or just identity
			var direction: Vector3 = (path_points[i] - path_points[i - 1])
			face_transform = face_transform.looking_at(direction, Vector3.UP, true)
			face_transform = face_transform.translated(path_points[i])
			transforms.append(face_transform) 
		else:
			assert(false, "We should never get here")

	# 3) Build side walls between consecutive rings
	immediate_mesh.clear_surfaces()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	var prev_global_points: Array[Vector3] = []
	var current_global_points: Array[Vector3] = []
	# print("STARTING EXTRUSION")
	# print(" ")
	for i: int in range(transforms.size()):
		current_global_points.clear()

		var t: Transform3D = transforms[i]
		# Convert each 2D vertex to 3D for this ring
		for v2: Vector2 in polygon_2d:
			var v3: Vector3 = Vector3(v2.x, v2.y, 0.0) # WE ASSUME THE POLYGON IS 2D and "UPRIGHT" on the X AXIS
			current_global_points.append(t * v3)
			pass
		# Duplicate the first vertex so the ring is closed.
		# This is used to close the UV mapping
		current_global_points.append(current_global_points[0])

		# ********************************************************************************
		# ********************************************************************************
		# NOTE: ALL THESE TRIANGLES ARE IN CW WINDING ORDER(as required by godot).
		# The face normal points OUT of the side of the face that's wound in CW order.
		# Note this DOESNT seem to agree with the "right-hand" coordinate system of godot; 
		# so don't use that when determing the normal vector, only look at which side of the polygon 
		# causes the winding order to be CW, and know the normal points out in that direction
		# Then, for the code that calculates the _actual_ normal below, use the right-hand rule to determine
		# which way the normal should go. I know, it's confusing.
		# ALSO, we should feed in the 2d pologyons in CW order to have the expected outcome
		# ********************************************************************************
		# ********************************************************************************

		# If we have a previous ring, connect them with quads -> triangles
		if i > 0:
			var ring_size: int = polygon_2d.size() + 1  # note the extra vertex!
			for j: int in range(ring_size):  # use ring_size-1 since j_next wraps around #TODO: Is this true? it works without it
				var j_next: int = (j + 1) % ring_size

				
				var vA: Vector3 = prev_global_points[j]
				var vB: Vector3 = prev_global_points[j_next]
				var vC: Vector3 = current_global_points[j_next]
				var vD: Vector3 = current_global_points[j]
				
				var u_previous: float = cumulative_dist[i - 1]
				var u_next: float = cumulative_dist[i]
				var v_previous: Vector2 = polygon_uvs[j]
				var v_next: Vector2 = polygon_uvs[j_next]

				# Probably need to add an offset here so that the texture starts at the "beginning"
				# But it's not worth the effort to figure it out since these textures don't really have a start/end
				var vA_uv: Vector2 = Vector2(1 - u_previous, v_previous.y)
				var vB_uv: Vector2 = Vector2(1 - u_previous, v_next.y)
				var vC_uv: Vector2 = Vector2(1 - u_next, v_next.y)
				var vD_uv: Vector2 = Vector2(1 - u_next, v_previous.y)
				
				
				var normals: Array[Vector3] = calculate_normals(vA, vB, vC, vD)
				var normal1: Vector3 = normals[0]
				var normal2: Vector3 = normals[1]

				set_immediate_mesh_values(immediate_mesh, normal1, normal2, vA, vB, vC, vD, vA_uv, vB_uv, vC_uv, vD_uv)

				# immediate_mesh.surface_set_normal(normal1)
				# # immediate_mesh.surface_set_tangent(tangent1)
				# immediate_mesh.surface_set_uv(vA_uv)
				# immediate_mesh.surface_add_vertex(vA)
				# immediate_mesh.surface_set_normal(normal1)
				# # immediate_mesh.surface_set_tangent(tangent1)
				# immediate_mesh.surface_set_uv(vB_uv)
				# immediate_mesh.surface_add_vertex(vB)
				# immediate_mesh.surface_set_normal(normal1)
				# # immediate_mesh.surface_set_tangent(tangent1)
				# immediate_mesh.surface_set_uv(vC_uv)
				# immediate_mesh.surface_add_vertex(vC)


				# immediate_mesh.surface_set_normal(normal2)
				# # immediate_mesh.surface_set_tangent(tangent2)
				# immediate_mesh.surface_set_uv(vC_uv)
				# immediate_mesh.surface_add_vertex(vC)
				# immediate_mesh.surface_set_normal(normal2)
				# # immediate_mesh.surface_set_tangent(tangent2)
				# immediate_mesh.surface_set_uv(vD_uv)
				# immediate_mesh.surface_add_vertex(vD)
				# immediate_mesh.surface_set_normal(normal2)
				# # immediate_mesh.surface_set_tangent(tangent2)
				# immediate_mesh.surface_set_uv(vA_uv)
				# immediate_mesh.surface_add_vertex(vA)

		# Prepare for next iteration
		prev_global_points = current_global_points.duplicate(true)

	setup_end_caps(polygon_2d, path_points, immediate_mesh, transforms)

	
	# immediate_mesh.surface_end()
	SURFACE_END(immediate_mesh)


	return immediate_mesh

static func SURFACE_END(immediate_mesh: ImmediateMesh) -> void:
	immediate_mesh.surface_end()

static func calculate_normals(vA: Vector3, vB: Vector3, vC: Vector3, vD: Vector3) -> Array[Vector3]:
	var normal1: Vector3 = (vC - vA).cross(vB - vA).normalized()
	var normal2: Vector3 = (vA - vC).cross(vD - vC).normalized()
	return [normal1, normal2]

static func set_immediate_mesh_values(immediate_mesh: ImmediateMesh,
normal1: Vector3, normal2: Vector3, vA: Vector3, vB: Vector3, vC: Vector3, vD: Vector3,
vA_uv: Vector2, vB_uv: Vector2, vC_uv: Vector2, vD_uv: Vector2) -> void:
		immediate_mesh.surface_set_normal(normal1)
		# immediate_mesh.surface_set_tangent(tangent1)
		immediate_mesh.surface_set_uv(vA_uv)
		immediate_mesh.surface_add_vertex(vA)
		immediate_mesh.surface_set_normal(normal1)
		# immediate_mesh.surface_set_tangent(tangent1)
		immediate_mesh.surface_set_uv(vB_uv)
		immediate_mesh.surface_add_vertex(vB)
		immediate_mesh.surface_set_normal(normal1)
		# immediate_mesh.surface_set_tangent(tangent1)
		immediate_mesh.surface_set_uv(vC_uv)
		immediate_mesh.surface_add_vertex(vC)


		immediate_mesh.surface_set_normal(normal2)
		# immediate_mesh.surface_set_tangent(tangent2)
		immediate_mesh.surface_set_uv(vC_uv)
		immediate_mesh.surface_add_vertex(vC)
		immediate_mesh.surface_set_normal(normal2)
		# immediate_mesh.surface_set_tangent(tangent2)
		immediate_mesh.surface_set_uv(vD_uv)
		immediate_mesh.surface_add_vertex(vD)
		immediate_mesh.surface_set_normal(normal2)
		# immediate_mesh.surface_set_tangent(tangent2)
		immediate_mesh.surface_set_uv(vA_uv)
		immediate_mesh.surface_add_vertex(vA)


static func setup_end_caps(	polygon_2d: Array[Vector2],
	path_points: Array[Vector3],
	immediate_mesh: ImmediateMesh,
	transforms: Array[Transform3D]) -> void:
	
	# 4) Triangulate the polygon to make end caps
	# Front cap
	var polygon_indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon_2d)

	var front_transform: Transform3D = transforms[0]
	var front_vertices: Array[Vector3] = []
	for v2: Vector2 in polygon_2d:
		var v3: Vector3 = Vector3(v2.x, v2.y, 0.0)
		front_vertices.append(front_transform * v3)


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

	# Use the triangulation data from polygon_indices.
	for i: int  in range(0, polygon_indices.size(), 3):
		var idx0: int = polygon_indices[i]
		var idx1: int = polygon_indices[i + 1]
		var idx2: int = polygon_indices[i + 2]
		var vA: Vector3 = front_vertices[idx0]
		var vB: Vector3 = front_vertices[idx1]
		var vC: Vector3 = front_vertices[idx2]
		var normal: Vector3 = (vC - vA).cross(vB- vA).normalized()

		var vA_uv: Vector2 = face_uvs[idx0]
		var vB_uv: Vector2 = face_uvs[idx1]
		var vC_uv: Vector2 = face_uvs[idx2]
		# var tangent: Plane = compute_triangle_tangent(vA, vB, vC, vA_uv, vB_uv, vC_uv)
		immediate_mesh.surface_set_normal(normal)
		# immediate_mesh.surface_set_tangent(tangent)
		immediate_mesh.surface_set_uv(vA_uv)
		immediate_mesh.surface_add_vertex(vA)
		immediate_mesh.surface_set_normal(normal)
		# immediate_mesh.surface_set_tangent(tangent)
		immediate_mesh.surface_set_uv(vB_uv)
		immediate_mesh.surface_add_vertex(vB)
		immediate_mesh.surface_set_normal(normal)
		# immediate_mesh.surface_set_tangent(tangent)
		immediate_mesh.surface_set_uv(vC_uv)
		immediate_mesh.surface_add_vertex(vC)

	# Back cap (at the end)
	var back_transform: Transform3D = transforms[transforms.size() - 1]
	var back_vertices: Array[Vector3] = []
	for v2: Vector2 in polygon_2d:
		var v3: Vector3 = Vector3(v2.x, v2.y, 0.0)
		back_vertices.append(back_transform * v3)

	# Reverse the triangle winding so that the normal points outward.
	for i: int in range(0, polygon_indices.size(), 3):
		var idx0: int = polygon_indices[i]
		var idx1: int = polygon_indices[i + 1]
		var idx2: int = polygon_indices[i + 2]
		var vA: Vector3 = back_vertices[idx2]
		var vB: Vector3 = back_vertices[idx1]
		var vC: Vector3 = back_vertices[idx0]
		var vA_uv: Vector2 = face_uvs[idx2]
		var vB_uv: Vector2 = face_uvs[idx1]
		var vC_uv: Vector2 = face_uvs[idx0]
		var normal: Vector3 = (vC - vA).cross(vB - vA).normalized()
		# var tangent: Plane = compute_triangle_tangent(vA, vB, vC, vA_uv, vB_uv, vC_uv)
		immediate_mesh.surface_set_normal(normal)
		# immediate_mesh.surface_set_tangent(tangent)
		immediate_mesh.surface_set_uv(vA_uv)
		immediate_mesh.surface_add_vertex(vA)
		immediate_mesh.surface_set_normal(normal)
		# immediate_mesh.surface_set_tangent(tangent)
		immediate_mesh.surface_set_uv(vB_uv)
		immediate_mesh.surface_add_vertex(vB)
		immediate_mesh.surface_set_normal(normal)
		# immediate_mesh.surface_set_tangent(tangent)
		immediate_mesh.surface_set_uv(vC_uv)
		immediate_mesh.surface_add_vertex(vC)

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
static func add_triangle_indexed(
	vertex_array: PackedVector3Array,
	normal_array: PackedVector3Array,
	uv_array: PackedVector2Array,
	index_array: PackedInt32Array,
	vec_map: Dictionary[Vector3, int],
	v0: Vector3, n0: Vector3, uv0: Vector2,
	v1: Vector3, n1: Vector3, uv1: Vector2,
	v2: Vector3, n2: Vector3, uv2: Vector2
) -> void:

	# var idx_A: int = get_vertex_index(v0, n0, uv0, vec_map, vertex_array, normal_array, uv_array)
	# var idx_B: int = get_vertex_index(v1, n1, uv1, vec_map, vertex_array, normal_array, uv_array)
	# var idx_C: int = get_vertex_index(v2, n2, uv2, vec_map, vertex_array, normal_array, uv_array)
	# index_array.push_back(idx_A)
	# index_array.push_back(idx_B)
	# index_array.push_back(idx_C)



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
	vertex_map: Dictionary[Vector3, int]
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

		add_triangle_indexed(
			vertex_array, normal_array, uv_array, index_array,
			vertex_map,
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

		add_triangle_indexed(
			vertex_array, normal_array, uv_array, index_array,
			vertex_map,
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

	var vertex_map: Dictionary[Vector3, int] = {}

	# if polygon_2d.is_empty() or path_points.size() < 2:
	# 	return out_mesh

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
			var ring_size: int = polygon_2d.size() + 1
			for j: int in range(ring_size):
				var j_next: int = (j + 1) % ring_size

				vA = prev_global_points[j]
				vB = prev_global_points[j_next]
				vC = current_global_points[j_next]
				vD = current_global_points[j]

				# Example UV logic (u from cumulative_dist, v from polygon_uvs)
				var u_prev: float = cumulative_dist[ring_i - 1]
				var u_next: float = cumulative_dist[ring_i]
				var v_prev_uv: Vector2 = polygon_uvs[j]
				var v_next_uv: Vector2 = polygon_uvs[j_next]

				vA_uv = Vector2(1.0 - u_prev, v_prev_uv.y)
				vB_uv = Vector2(1.0 - u_prev, v_next_uv.y)
				vC_uv = Vector2(1.0 - u_next, v_next_uv.y)
				vD_uv = Vector2(1.0 - u_next, v_prev_uv.y)

				# Triangle 1: (vA, vB, vC)
				var normal1: Vector3 = (vC - vA).cross(vB - vA).normalized()
				add_triangle_indexed(
					vertex_array, normal_array, uv_array, index_array,
					vertex_map,
					vA, normal1, vA_uv,
					vB, normal1, vB_uv,
					vC, normal1, vC_uv
				)

				# Triangle 2: (vC, vD, vA)
				var normal2: Vector3 = (vA - vC).cross(vD - vC).normalized()
				add_triangle_indexed(
					vertex_array, normal_array, uv_array, index_array,
					vertex_map,
					vC, normal2, vC_uv,
					vD, normal2, vD_uv,
					vA, normal2, vA_uv
				)

		prev_global_points = current_global_points.duplicate(true)

	# Build end caps
	build_end_caps(polygon_2d, polygon_uvs, transforms,
		vertex_array, normal_array, uv_array, index_array,
		vertex_map
	)

	# Create the ArrayMesh from the final arrays
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_NORMAL] = normal_array
	arrays[Mesh.ARRAY_TEX_UV] = uv_array
	# arrays[Mesh.ARRAY_INDEX] = index_array
	# No index array => unindexed triangle list

	set_the_arrays(out_mesh, arrays)
	# out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# return out_mesh

static func get_vertex_index(
	pos: Vector3, norm: Vector3, uv: Vector2,
	vertex_map: Dictionary[Vector3, int],
	vertex_array: PackedVector3Array,
	normal_array: PackedVector3Array,
	uv_array: PackedVector2Array
) -> int:
	# Create a key for this vertex based on its attributes.
	# var key: String = str(pos.x, ",", pos.y, ",", pos.z, "|", norm.x, ",", norm.y, ",", norm.z, "|", uv.x, ",", uv.y)
	if vertex_map.has(pos):
		var index: int = vertex_map[pos]
		normal_array[index] = normal_array[index] * norm
		uv_array[index] = uv_array[index] * uv
		return vertex_map[pos]
	else:
		var new_index: int = vertex_array.size()
		vertex_array.push_back(pos)
		normal_array.push_back(norm)
		uv_array.push_back(uv)
		vertex_map[pos] = new_index
		return new_index

static func set_the_arrays(mesh: ArrayMesh, arrays: Array) -> void:
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
