@tool
extends Node3D
class_name TrackVisualComponent3D

var crosstie_distance: float = 7


# We should use this visual building system:
# https://www.factorio.com/blog/post/fff-163

#@onready var _crosstie_mesh_instance : MeshInstance2D = $Sprite2D2
@onready var _crosstie_multimesh : MultiMeshInstance2D = $Crossties
#@onready var _curve_points_multimesh : MultiMeshInstance2D = $CurvePoints
#@onready var _circle_mesh_instance : MeshInstance2D = $Circle

# Rectangle
var my_polygon: Array[Vector2] = [
		Vector2(-0.5, -0.5), #Bottom Left
		Vector2(0.5,-0.5), #Bottom Right
		Vector2(0.5,0.5), #Top Right
		Vector2(-0.5,0.5)] #Top Left
	

@onready var rail : MeshInstance3D = $Rail

@onready var parentTrack : Track = get_parent() as Track

@onready var backing: Line2D = $Backing
# @onready var rail: Line2D = $Rail

func _ready() -> void:
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

# Need to update the bezier call here to actually pass in the tangets. Don't feel like doing the rewrite though.
func update_track_points(points_: Array[Vector2], length: float, get_coord_at_offset: Callable, startTangent: Vector2 = Vector2(0,0), endTangent: Vector2 = Vector2(0,0)) -> void:
	
	if (points_.size() < 2):
		print("WE HAVE A VERY TINY POINT ARRAY")
		return
	
	## We add 0.2 pixels to the start and the end of this segment(in the direction it was coming and going) 
	## so that there's better overlap with the next segment, and we don't get "sliver gaps" between the train paths
	var draw_points: Array[Vector2] = points_.duplicate()	
	var last_point_value: Vector2 = points_[points_.size() - 1]
	draw_points.insert(0, points_[0] - (startTangent * 0.2))
	draw_points.append(last_point_value - (endTangent * 0.2))

	var vector_3_path: PackedVector3Array = []
	for point: Vector2 in points_:
		vector_3_path.append(Vector3(point.x, 0.001, point.y))

	assert(rail.mesh is ArrayMesh, "Rail mesh must be an ImmediateMesh")
	var mesh: ArrayMesh = rail.mesh as ArrayMesh
	# assert(rail.mesh is ImmediateMesh, "Rail mesh must be an ImmediateMesh")
	# var mesh: ImmediateMesh = rail.mesh as ImmediateMesh

	# var debug_path: Array[Vector3] = [
	# 	Vector3(2, 0, 2),
	# 	Vector3(4, 0, 2),
	# 	Vector3(6, 0, 2),
	# 	Vector3(8, 0, 2),
	# ]
	

	#mesh.clear_blend_shapes()
	
	mesh.clear_surfaces()
	TrackDrawer.extrude_polygon_along_path_arraymesh(TrackDrawer.RAIL_POLYGON_VERTICIES, vector_3_path, mesh)


	# TrackDrawer.extrude_polygon_along_path(TrackDrawer.RAIL_POLYGON_VERTICIES, vector_3_path, mesh)
	# var rid : RID = mesh.get_rid()
	# var array: Array = mesh.surface_get_arrays(0)
	# var surface: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	# var surface1: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	
	
	#TODO: DO TRACK DRAWING HERE

	#set_points(draw_points)
	# TODO: 3D fix
	# rail.set_points(draw_points)
	# backing.set_points(draw_points)
	_update_crossties(length, get_coord_at_offset)
	# for point: Vector2 in draw_points: 
	# 	drawableFunctionsToCallLater.append(func() -> void: draw_circle(point, 3, Color.BLACK))
	# # drawableFunctionsToCallLater.append(func(): draw_circle(draw_points[-1], 3, Color.BLUE))
	# queue_redraw()

func make_track_invisible() -> void:
	# TODO: 3D FIX
	# _crosstie_multimesh.multimesh.instance_count = 0
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
	
	for i: int in range(crosstie_count):
		var t: Transform2D = Transform2D()
		var crosstie_position: Vector2 = get_coord_at_offset.call((i * crosstie_distance) + crosstie_distance / 2.0)
		var next_position: Vector2 = get_coord_at_offset.call((i + 1) * crosstie_distance)
		t = t.rotated((next_position - crosstie_position).normalized().angle())
		t.origin = crosstie_position
		crossties.set_instance_transform_2d(i, t)
