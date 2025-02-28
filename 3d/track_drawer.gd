extends RefCounted

class_name TrackDrawer

static func extrude_polygon_along_path(
	polygon_2d: Array[Vector2],
	path_points: Array[Vector3],
	immediate_mesh: ImmediateMesh
) -> ImmediateMesh:
	# Early exit if invalid input
	if polygon_2d.is_empty() or path_points.size() < 2:
		return

	# 2) Create a Transform3D array for each segment of the path
	var transforms: Array[Transform3D] = []

	var points_count: int = path_points.size()
	for i: int in range(points_count):
		var face_transform: Transform3D = Transform3D()			
		if (i == 0):
			var direction: Vector3 = (path_points[1] - path_points[0])
			face_transform = face_transform.looking_at(direction, Vector3.UP)
			face_transform = face_transform.translated(path_points[i])
			transforms.append(face_transform)
		elif i < points_count - 1:
			var prev_dir: Vector3 = (path_points[i] - path_points[i - 1])
			var next_dir: Vector3 = (path_points[i + 1] - path_points[i])
			var direction: Vector3 = (prev_dir + next_dir)
			face_transform = face_transform.looking_at(direction, Vector3.UP)
			face_transform = face_transform.translated(path_points[i])
			transforms.append(face_transform)
		elif(i == points_count - 1):
			# For the last point, reuse orientation from the previous or just identity
			var direction: Vector3 = (path_points[i] - path_points[i - 1])
			face_transform = face_transform.looking_at(direction, Vector3.UP)
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

		# print("CURRENT GLOBAL POINTS:")
		# print(current_global_points)

		# If we have a previous ring, connect them with quads -> triangles
		if i > 0:
			var ring_size: int = polygon_2d.size()
			for j: int in range(ring_size):
				var j_next: int = (j + 1) % ring_size

				var vA: Vector3 = prev_global_points[j]
				var vB: Vector3 = prev_global_points[j_next]
				var vC: Vector3 = current_global_points[j_next]
				var vD: Vector3 = current_global_points[j]
			
				immediate_mesh.surface_add_vertex(vA)
				immediate_mesh.surface_add_vertex(vB)
				immediate_mesh.surface_add_vertex(vC)

				immediate_mesh.surface_add_vertex(vC)
				immediate_mesh.surface_add_vertex(vD)
				immediate_mesh.surface_add_vertex(vA)

		# Prepare for next iteration
		prev_global_points = current_global_points.duplicate(true)


	# Add end caps here using polygon_indices for the first and/or last transform.
	# Front cap (at the beginning)
	# 1) Triangulate the polygon if you want to make end caps
	var polygon_indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon_2d)

	var front_transform: Transform3D = transforms[0]
	var front_vertices: Array[Vector3] = []
	for v2: Vector2 in polygon_2d:
		var v3: Vector3 = Vector3(v2.x, v2.y, 0.0)
		front_vertices.append(front_transform * v3)

	# Use the triangulation data from polygon_indices.
	for i: int  in range(0, polygon_indices.size(), 3):
		var idx0: int = polygon_indices[i]
		var idx1: int = polygon_indices[i + 1]
		var idx2: int = polygon_indices[i + 2]
		immediate_mesh.surface_add_vertex(front_vertices[idx2])
		immediate_mesh.surface_add_vertex(front_vertices[idx1])
		immediate_mesh.surface_add_vertex(front_vertices[idx0])

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
		immediate_mesh.surface_add_vertex(back_vertices[idx0])
		immediate_mesh.surface_add_vertex(back_vertices[idx1])
		immediate_mesh.surface_add_vertex(back_vertices[idx2])
		
	immediate_mesh.surface_end()

	return immediate_mesh


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
