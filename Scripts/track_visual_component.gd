@tool
extends Node2D

var crosstie_distance := 7


# We should use this visual building system:
# https://www.factorio.com/blog/post/fff-163

#@onready var _crosstie_mesh_instance : MeshInstance2D = $Sprite2D2
@onready var _crosstie_multimesh : MultiMeshInstance2D = $Crossties
#@onready var _curve_points_multimesh : MultiMeshInstance2D = $CurvePoints
#@onready var _circle_mesh_instance : MeshInstance2D = $Circle


@onready var parentTrack : Track = get_parent() as Track

@onready var backing: Line2D = $Backing
@onready var rail: Line2D = $Rail


var drawableFunctionsToCallLater: Array[Callable] = []

func _draw():
	pass
	# for function in drawableFunctionsToCallLater:
	# 	function.call()
	# drawableFunctionsToCallLater.clear()

# Need to update the bezier call here to actually pass in the tangets. Don't feel like doing the rewrite though.
func update_track_points(points_, length, get_coord_at_offset: Callable, startTangent: Vector2 = Vector2(0,0), endTangent: Vector2 = Vector2(0,0)) -> void:
	
	if (points_.size() < 2):
		print("WE HAVE A VERY TINY POINT ARRAY")
		return
	
	## We add 0.2 pixels to the start and the end of this segment(in the direction it was coming and going) 
	## so that there's better overlap with the next segment, and we don't get "sliver gaps" between the train paths
	var draw_points = points_.duplicate()	
	var last_point_value = points_[points_.size() - 1];
	draw_points.insert(0, points_[0] - (startTangent * 0.2))
	draw_points.append(last_point_value - (endTangent * 0.2))
	

	#set_points(draw_points)
	rail.set_points(draw_points)
	backing.set_points(draw_points)
	_update_crossties(length, get_coord_at_offset)
	for point in draw_points: 
		drawableFunctionsToCallLater.append(func(): draw_circle(point, 3, Color.BLACK))
	# drawableFunctionsToCallLater.append(func(): draw_circle(draw_points[-1], 3, Color.BLUE))
	queue_redraw()

func make_track_invisible():
	_crosstie_multimesh.multimesh.instance_count = 0


func _update_crossties(path_length, get_coord_at_offset: Callable) -> void:
	pass
	if !_crosstie_multimesh:
		return
	
	var crossties = _crosstie_multimesh.multimesh
	#crossties.mesh = _crosstie_mesh_instance.mesh
	
	# var curve_length = parentTrack.curve.get_baked_length()
	var crosstie_count = round(path_length / crosstie_distance) ## uses path length

	crossties.instance_count = crosstie_count
	
	for i in range(crosstie_count):
		var t = Transform2D()
		var crosstie_position = get_coord_at_offset.call((i * crosstie_distance) + crosstie_distance / 2.0)
		var next_position = get_coord_at_offset.call((i + 1) * crosstie_distance)
		t = t.rotated((next_position - crosstie_position).normalized().angle())
		t.origin = crosstie_position
		crossties.set_instance_transform_2d(i, t)
