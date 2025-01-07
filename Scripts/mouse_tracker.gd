extends Node2D

var trackBuilder: TrackBuilder;


func _ready():
	trackBuilder = TrackBuilder.new(get_tree().root.find_child("Tracks", true, false), self)


func _input(event: InputEvent) -> void:
	if  (not (event is InputEventMouseMotion || event.is_action_type())):
		return
	if (event is InputEventMouseMotion):
		trackBuilder.find_nearest_grid_and_tangents(event)
	# if (event is InputEventMouseMotion):
	if (event.is_action_pressed("left_click")):
		if (trackBuilder.trackStartingPosition == null):
			trackBuilder.intialize_and_set_start_point()
		elif (trackBuilder.trackStartingPosition != null && trackBuilder.validTrack):
				trackBuilder.solidifyTrack()
				return; # We don't want to call build track again
	elif (event.is_action_pressed("track_mode")):
		trackBuilder.track_mode_flag = !trackBuilder.track_mode_flag
	elif (event.is_action_pressed("curve_type")):
		trackBuilder.curve_type_flag = !trackBuilder.curve_type_flag
	elif (event.is_action_pressed("cancel")):
		trackBuilder.cancel_track()
	elif (event.is_action_pressed("flip_track_direction")):
		trackBuilder.flip_track_direction()
	elif(event.is_action("increase_size") && event.is_pressed()):
		trackBuilder.minAllowedRadius += 10
	elif(event.is_action("decrease_size") && event.is_pressed()):
		trackBuilder.minAllowedRadius -= 10

	## Always recompute the track on any inputEvent
	if (trackBuilder.trackStartingPosition):
		trackBuilder.build_track()
	queue_redraw()

	
func _draw():
	pass

	draw_circle((Vector2(-100,-100)), 10, Color.RED, false, 4)
	draw_line(trackBuilder.wallToHighlight[0], trackBuilder.wallToHighlight[1],trackBuilder.highlightColor, 3)
	draw_circle(trackBuilder.centerPointToHighlight, 4, trackBuilder.highlightColor, false, 4)
