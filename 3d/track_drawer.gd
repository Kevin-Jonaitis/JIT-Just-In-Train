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
				
				var normal1: Vector3 = (vC - vA).cross(vB - vA).normalized()
				var tangent1: Plane = compute_triangle_tangent(vA, vB, vC, vA_uv, vB_uv, vC_uv)

				immediate_mesh.surface_set_normal(normal1)
				immediate_mesh.surface_set_tangent(tangent1)
				immediate_mesh.surface_set_uv(vA_uv)
				immediate_mesh.surface_add_vertex(vA)
				immediate_mesh.surface_set_normal(normal1)
				immediate_mesh.surface_set_tangent(tangent1)
				immediate_mesh.surface_set_uv(vB_uv)
				immediate_mesh.surface_add_vertex(vB)
				immediate_mesh.surface_set_normal(normal1)
				immediate_mesh.surface_set_tangent(tangent1)
				immediate_mesh.surface_set_uv(vC_uv)
				immediate_mesh.surface_add_vertex(vC)

				var normal2: Vector3 = (vA - vC).cross(vD - vC).normalized()
				var tangent2: Plane = compute_triangle_tangent(vC, vD, vA, vC_uv, vD_uv, vA_uv)

				immediate_mesh.surface_set_normal(normal2)
				immediate_mesh.surface_set_tangent(tangent2)
				immediate_mesh.surface_set_uv(vC_uv)
				immediate_mesh.surface_add_vertex(vC)
				immediate_mesh.surface_set_normal(normal2)
				immediate_mesh.surface_set_tangent(tangent2)
				immediate_mesh.surface_set_uv(vD_uv)
				immediate_mesh.surface_add_vertex(vD)
				immediate_mesh.surface_set_normal(normal2)
				immediate_mesh.surface_set_tangent(tangent2)
				immediate_mesh.surface_set_uv(vA_uv)
				immediate_mesh.surface_add_vertex(vA)

		# Prepare for next iteration
		prev_global_points = current_global_points.duplicate(true)


	# 4) Triangulate the polygon  to make end caps
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
		var tangent: Plane = compute_triangle_tangent(vA, vB, vC, vA_uv, vB_uv, vC_uv)
		immediate_mesh.surface_set_normal(normal)
		immediate_mesh.surface_set_tangent(tangent)
		immediate_mesh.surface_set_uv(vA_uv)
		immediate_mesh.surface_add_vertex(vA)
		immediate_mesh.surface_set_normal(normal)
		immediate_mesh.surface_set_tangent(tangent)
		immediate_mesh.surface_set_uv(vB_uv)
		immediate_mesh.surface_add_vertex(vB)
		immediate_mesh.surface_set_normal(normal)
		immediate_mesh.surface_set_tangent(tangent)
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
		var tangent: Plane = compute_triangle_tangent(vA, vB, vC, vA_uv, vB_uv, vC_uv)
		immediate_mesh.surface_set_normal(normal)
		immediate_mesh.surface_set_tangent(tangent)
		immediate_mesh.surface_set_uv(vA_uv)
		immediate_mesh.surface_add_vertex(vA)
		immediate_mesh.surface_set_normal(normal)
		immediate_mesh.surface_set_tangent(tangent)
		immediate_mesh.surface_set_uv(vB_uv)
		immediate_mesh.surface_add_vertex(vB)
		immediate_mesh.surface_set_normal(normal)
		immediate_mesh.surface_set_tangent(tangent)
		immediate_mesh.surface_set_uv(vC_uv)
		immediate_mesh.surface_add_vertex(vC)
		
	immediate_mesh.surface_end()

	return immediate_mesh

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
	var points: PackedVector3Array = []
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
	var normals: PackedVector3Array = []
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
