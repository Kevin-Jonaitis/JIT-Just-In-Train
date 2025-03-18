@tool
extends Node3D
class_name TrackVisualComponent3D

var crosstie_distance: float = 7


# We should use this visual building system:
# https://www.factorio.com/blog/post/fff-163

#@onready var _crosstie_mesh_instance : MeshInstance2D = $Sprite2D2
@onready var _crosstie_multimesh : MultiMeshInstance3D = $Crossties
#@onready var _curve_points_multimesh : MultiMeshInstance2D = $CurvePoints
#@onready var _circle_mesh_instance : MeshInstance2D = $Circle

# Rectangle
var my_polygon: Array[Vector2] = [
		Vector2(-0.5, -0.5), #Bottom Left
		Vector2(0.5,-0.5), #Bottom Right
		Vector2(0.5,0.5), #Top Right
		Vector2(-0.5,0.5)] #Top Left
	

@onready var rail_left : MeshInstance3D = $RailLeft
@onready var rail_right : MeshInstance3D = $RailRight

@onready var parentTrack : Track = get_parent() as Track

@onready var backing: Line2D = $Backing
# @onready var rail_left: Line2D = $Rail

func _ready() -> void:
	# _crosstie_multimesh.scale = Vector3(0.01, 0.01, 0.01) # make the crossties thinner
	# TODO: 3D FIX
	## VERY IMPORTANT: THIS RADIUS MUST BE BIGGER THAN 
	## THE WIDTH OF 1/2 of TRACK. If it's not, when the mouse gets close to a track
	## we might collide with the track before a junction, causing us not to see
	## the junction, which will mess up adding tracks to junctions
	# if (Junction_Collison_Shape.JUNCTION_RADIUS <= backing.width / 2 || \
	# Junction_Collison_Shape.JUNCTION_RADIUS <= backing.width / 2):
	# 	assert(false, "Son, you just made a grave mistake. Check the comment above your failure, and weep.")
	# 	pass
	pass


var drawableFunctionsToCallLater: Array[Callable] = []

# func _draw() -> void:
# 	pass
# 	# for function in drawableFunctionsToCallLater:
# 	# 	function.call()
# 	drawableFunctionsToCallLater.clear()

# Offset the path for use by the rails
func offset_paths(path: Array[Vector2], offset: float) -> Dictionary[String, PackedVector3Array]:
	var left_path: Array[Vector3] = []
	var right_path: Array[Vector3] = []
	var left_vector2: Vector2
	var right_vector2: Vector2
	var extra_start_point: Vector2
	var extra_end_point: Vector2
	var n: int = path.size()
	if n == 0:
		return {"left": left_path, "right": right_path}

	for i: int in range(n):
		var normal: Vector2 = Vector2.ZERO
		if i == 0:
			var dir: Vector2 = (path[1] - path[0]).normalized()
			normal = Vector2(-dir.y, dir.x)
			extra_start_point = path[i] - dir * 0.02
		elif i == n - 1:
			var dir: Vector2 = (path[i] - path[i - 1]).normalized()
			normal = Vector2(-dir.y, dir.x)
			extra_end_point = path[i] + dir * 0.02
		else:
			var dir1: Vector2 = (path[i] - path[i - 1]).normalized()
			var dir2: Vector2 = (path[i + 1] - path[i]).normalized()
			var normal1: Vector2 = Vector2(-dir1.y, dir1.x)
			var normal2: Vector2 = Vector2(-dir2.y, dir2.x)
			normal = (normal1 + normal2).normalized()

		# Add extra point to remove "gaps" bewteen rails		
		if (i == 0):
			left_vector2 = extra_start_point + (normal * offset)
			right_vector2 = extra_start_point - (normal * offset)
			left_path.append(Vector3(left_vector2.x, 0.001, left_vector2.y))
			right_path.append(Vector3(right_vector2.x, 0.001, right_vector2.y))
		
		left_vector2 = path[i] + normal * offset
		right_vector2 = path[i] - normal * offset
		left_path.append(Vector3(left_vector2.x, 0.001, left_vector2.y))
		right_path.append(Vector3(right_vector2.x, 0.001, right_vector2.y))
		
		# Add extra point to remove "gaps" bewteen rails
		if(i == n - 1):
			left_vector2 = extra_end_point + (normal * offset)
			right_vector2 = extra_end_point - (normal * offset)
			left_path.append(Vector3(left_vector2.x, 0.001, left_vector2.y))
			right_path.append(Vector3(right_vector2.x, 0.001, right_vector2.y))

	return {"left": left_path, "right": right_path}


# Need to update the bezier call here to actually pass in the tangets. Don't feel like doing the rewrite though.
func update_track_points(points_: Array[Vector2], length: float, get_coord_at_offset: Callable, startTangent: Vector2 = Vector2(0,0), endTangent: Vector2 = Vector2(0,0)) -> void:
	
	if (points_.size() < 2):
		print("WE HAVE A VERY TINY POINT ARRAY")
		return
	
	## We add 0.2 pixels to the start and the end of this segment(in the direction it was coming and going) 
	## so that there's better overlap with the next segment, and we don't get "sliver gaps" between the train paths
	var draw_points: Array[Vector2] = points_.duplicate()	

	var results: Dictionary[String, PackedVector3Array] = offset_paths(draw_points, 0.5) # This is just to get the size of the array, we don't need it
	# var vector_3_path: PackedVector3Array = []
	var vector_3_path_left: PackedVector3Array = results["left"]
	var vector_3_path_right: PackedVector3Array = results["right"]
	
	assert(rail_left.mesh is ArrayMesh, "Rail mesh must be an ImmediateMesh")
	assert(rail_right.mesh is ArrayMesh, "Rail mesh must be an ImmediateMesh")
	var mesh_left: ArrayMesh = rail_left.mesh as ArrayMesh
	var mesh_right: ArrayMesh = rail_right.mesh as ArrayMesh
	# assert(rail_left.mesh is ImmediateMesh, "Rail mesh must be an ImmediateMesh")
	# var mesh: ImmediateMesh = rail_left.mesh as ImmediateMesh

	# var debug_path: Array[Vector3] = [
	# 	Vector3(2, 0, 2),
	# 	Vector3(4, 0, 2),
	# 	Vector3(6, 0, 2),
	# 	Vector3(8, 0, 2),
	# ]
	

	#mesh.clear_blend_shapes()
	
	mesh_left.clear_surfaces()
	mesh_right.clear_surfaces()
	TrackDrawer.extrude_polygon_along_path_arraymesh(TrackDrawer.RAIL_POLYGON_VERTICIES, vector_3_path_left, mesh_left)
	TrackDrawer.extrude_polygon_along_path_arraymesh(TrackDrawer.RAIL_POLYGON_VERTICIES, vector_3_path_right, mesh_right)


	# TrackDrawer.extrude_polygon_along_path(TrackDrawer.RAIL_POLYGON_VERTICIES, vector_3_path, mesh)
	# var rid : RID = mesh.get_rid()
	# var array: Array = mesh.surface_get_arrays(0)
	# var surface: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	# var surface1: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	
	
	#TODO: DO TRACK DRAWING HERE

	#set_points(draw_points)
	# TODO: 3D fix
	# rail_left.set_points(draw_points)
	# backing.set_points(draw_points)
	_update_crossties(length, get_coord_at_offset)
	# for point: Vector2 in draw_points: 
	# 	drawableFunctionsToCallLater.append(func() -> void: draw_circle(point, 3, Color.BLACK))
	# # drawableFunctionsToCallLater.append(func(): draw_circle(draw_points[-1], 3, Color.BLUE))
	# queue_redraw()

func make_track_invisible() -> void:
	_crosstie_multimesh.multimesh.instance_count = 0
	pass


func _update_crossties(path_length: float, get_coord_at_offset: Callable) -> void:
	pass
	if !_crosstie_multimesh:
		return
	
	var crossties: MultiMesh = _crosstie_multimesh.multimesh
	#crossties.mesh = _crosstie_mesh_instance.mesh
	
	# var curve_length = parentTrack.curve.get_baked_length()
	var crosstie_count: int = round(path_length / crosstie_distance) ## uses path length

	crossties.instance_count = crosstie_count
	
	# for i: int in range(crosstie_count):
	# 	var t: Transform2D = Transform2D()
	# 	var crosstie_position: Vector2 = get_coord_at_offset.call((i * crosstie_distance) + crosstie_distance / 2.0)
	# 	var next_position: Vector2 = get_coord_at_offset.call((i + 1) * crosstie_distance)
	# 	t = t.rotated((next_position - crosstie_position).normalized().angle())
	# 	t.origin = crosstie_position
	# 	crossties.set_instance_transform_2d(i, t)

	for i: int in range(crosstie_count):
		var t: Transform3D = Transform3D()
		var crosstie_position: Vector2 = get_coord_at_offset.call((i * crosstie_distance) + crosstie_distance / 2.0)
		var next_position: Vector2 = get_coord_at_offset.call((i + 1) * crosstie_distance)
		print("POSITION:" + str(crosstie_position))
		# t = t.rotated(Vector3(next_position.x, 0, next_position.y) - Vector3(crosstie_position.x, 0, crosstie_position.y))
		# t.origin = 
		t.basis = Basis().scaled(Vector3(0.01, 0.01, 0.01)).rotated(Vector3(1, 0, 0), PI / 2)
		# .rotated(Vector3(0, 1, 0), (next_position - crosstie_position).normalized().angle())
		t.origin = Vector3(crosstie_position.x, 0 ,crosstie_position.y)

		# t = t.scaled(Vector3(0.01, 0.01, 0.01)) # make the crossties thiner
		# t.origin = Vector3(crosstie_position.x, 0 ,crosstie_position.y)
		# var transform: Transform3D = Transform3D(t, Vector3(crosstie_position.x, 0 ,crosstie_position.y))
		print("TRANSFORM:", t)
		crossties.set_instance_transform(i, t)
