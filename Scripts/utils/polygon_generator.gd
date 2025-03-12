extends Node3D

# This file is 95% chat-gpt generated, tweaked for my needs
class_name PolygonGenerator


# Export from blender to glb, then use this function to generate a polygon to extrude from the glb
static func generate_polygon_from_glb(glb_path: String, polygon_save_path: String) -> void:
	var scene: PackedScene = load(glb_path)
	var node: Node3D = scene.instantiate()

  # Find the first MeshInstance3D in the scene
	var mesh_instance: MeshInstance3D = find_mesh_instance(node)
	if not mesh_instance or not mesh_instance.mesh:
		print("No valid MeshInstance3D found in the .glb scene")
		return

	var scaled_mesh: ArrayMesh = mesh_instance.mesh.duplicate() as ArrayMesh  # Duplicate the original mesh
	load_build_save_boundary_vertices(scaled_mesh, polygon_save_path)

	

# Helper function to find the first MeshInstance3D in a scene
static func find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var mesh_instance: MeshInstance3D = find_mesh_instance(child)
		if mesh_instance:
			return mesh_instance
	return null

# Generates a unique key for an edge defined by two vertex indices (iA, iB).
# Sorting ensures (2,5) is the same as (5,2).
static func edge_key(iA: int, iB: int) -> String:
	if iA < iB:
		return str(iA, ":", iB)
	else:
		return str(iB, ":", iA)

# Counts an edge in our edge_count dictionary (used to track usage).
static func _count_edge(iA: int, iB: int, edge_count: Dictionary[String, int]) -> void:
	var key: String = edge_key(iA, iB)
	if not edge_count.has(key):
		edge_count[key] = 0
	edge_count[key] += 1

# Finds all edges that appear in exactly one triangle => boundary edges.
static func find_boundary_edges(
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> Dictionary[String, bool]:
	var edge_count : Dictionary[String, int] = {}  # Dictionary[String, int]

	var triangle_count: int = indices.size() / 3
	for t: int in range(triangle_count):
		var i0: int = indices[t * 3 + 0]
		var i1: int = indices[t * 3 + 1]
		var i2: int = indices[t * 3 + 2]

		_count_edge(i0, i1, edge_count)
		_count_edge(i1, i2, edge_count)
		_count_edge(i2, i0, edge_count)

	# boundary_edges store edges used by exactly one triangle
	var boundary_edges: Dictionary[String, bool] = {}
	for k: String in edge_count.keys():
		if edge_count[k] == 1:
			boundary_edges[k] = true

	return boundary_edges

# Builds a single boundary loop (in terms of vertex indices) by "walking" the edges.
# This assumes one continuous loop.
static func build_boundary_loop(
	boundary_edges: Dictionary[String, bool]
) -> Array[int]:
	var loop: Array[int] = []
	if boundary_edges.size() == 0:
		return loop

	# Pick any boundary edge
	var first_edge_key: String = boundary_edges.keys()[0]  # e.g. "2:5"
	var parts: PackedStringArray = first_edge_key.split(":")  # ["2", "5"]
	var iA: int = parts[0].to_int()
	var iB: int = parts[1].to_int()

	# Start from iA, next is iB
	loop.append(iA)
	var current: int = iA
	var nxt: int = iB

	while true:
		loop.append(nxt)

		# find the next boundary vertex that forms an edge with 'nxt'
		var found_next: bool = false
		for key: String in boundary_edges.keys():
			var eparts: PackedStringArray = key.split(":")
			var eA: int = eparts[0].to_int()
			var eB: int = eparts[1].to_int()

			if eA == nxt or eB == nxt:
				var candidate: int = eB if (eA == nxt) else eA
				# skip going back to 'current'
				if candidate != current:
					current = nxt
					nxt = candidate
					found_next = true
					break

		if not found_next:
			# can't continue
			break
		if nxt == iA:
			# we've looped back to the start
			break

	return loop

# Master function that:
# 1) extracts the first surface arrays,
# 2) finds boundary edges,
# 3) walks them to produce an ordered array of vertex positions (Vector3).
# 4) saves the polygon
static func load_build_save_boundary_vertices(mesh: ArrayMesh, polygon_save_path: String) -> PackedVector2Array:
	# 1) Load the glTF file (must be an ArrayMesh or Mesh).
	# var mesh: ArrayMesh = load(gltf_path) as ArrayMesh
	# if not mesh:
	# 	push_error("Failed to load mesh at: " + gltf_path)
	# 	return []

	if mesh.get_surface_count() == 0:
		push_error("Mesh has no surfaces.")
		return []

	# 2) Extract vertex & index arrays from the first surface.
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.size() == 0 or indices.size() == 0:
		push_error("No vertices or indices found in surface 0.")
		return []

	# 3) Find boundary edges.
	var boundary: Dictionary[String, bool] = find_boundary_edges(vertices, indices)
	if boundary.size() == 0:
		# Possibly means fully enclosed or no single boundary found
		push_warning("No boundary edges discovered.")
		return []

	# 4) Build the boundary loop in terms of vertex indices.
	var loop_indices: Array[int] = build_boundary_loop(boundary)
	if loop_indices.size() < 3:
		push_warning("Failed to build a complete boundary loop.")
		return []

	# Convert the loop of indices -> an array of positions (Vector3)
	var boundary_positions: Array[Vector3] = []
	for idx: int in loop_indices:
		boundary_positions.append(vertices[idx])

	var verticies_2d: PackedVector2Array = []
	for i: int in range(boundary_positions.size()):
		var new_vector: Vector2 = Vector2(boundary_positions[i].x, boundary_positions[i].y)
		verticies_2d.append(new_vector)

	# Get the Y height range of this polygon
	# var min_y: float = boundary_positions[0].y
	# var max_y: float = boundary_positions[0].y
	# for i: int in range(1, boundary_positions.size()):
	# 	var y: float = boundary_positions[i].y
	# 	if y < min_y:
	# 		min_y = y
	# 	if y > max_y:
	# 		max_y = y

	# var height: float = (max_y - min_y) / 2

	save_polygon_resource(verticies_2d, polygon_save_path)

	return verticies_2d

static func save_polygon_resource(polygon: Array[Vector2], path: String) -> void:
	var poly_res: VertexPolygon = VertexPolygon.new()
	poly_res.vertices = polygon
	# poly_res.height = height
	var err: int = ResourceSaver.save(poly_res, path)
	if err == OK:
		print("Polygon resource saved to ", path)
	else:
		push_error("Failed to save polygon resource: " + str(err))
