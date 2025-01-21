extends Sprite2D

class_name Train

signal stops_changed(stops: Array[StopOption])



@onready var area2d : Area2D = $Area2D

const TRAIN_COLLISION_LAYER = 8

# Used to differentiate from the "temp" train
var is_placed = false

#Could be tracks, could be Stations
var stops: Array[StopOption] = []:
	set(value):
		stops = value
		emit_signal("stops_changed", stops)

# Generated schedule from stops
var schedule: Schedule:
	set(value):
		schedule = value
		queue_redraw()


func create_stop_option(stop_point: TrackPointInfo) -> StopOption:
	var stop = StopOption.new(stop_point.track.add_temp_virtual_nodes(stop_point.point_index, self))
	return stop

func add_stop(stop_point: TrackPointInfo) -> void:
	stops.append(create_stop_option(stop_point))
	emit_signal("stops_changed", stops)

func remove_stop(stop_index: int) -> void:
	var stop = stops[stop_index]
	var point_index = stop.forward_stop.temp_node_index
	# This should remove both temp nodes
	# Kinda roundabout, but works
	stop.forward_stop.temp_node_track.remove_temp_virtual_node(point_index, self)
	stops.remove_at(stop_index)
	emit_signal("stops_changed", stops)


var colors = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.CYAN, Color.MAGENTA, Color.ORANGE, Color.PURPLE, Color.PINK, Color.TEAL, Color.GRAY, Color.LIME, Color.AQUA, Color.OLIVE, Color.MAROON, Color.TEAL, Color.SILVER, Color.WHITE, Color.BLACK]
func _draw():
	if (!schedule):
		return
	for path in schedule.segments:
		for track : Track in path.tracks:
			var color = colors[randi() % colors.size()]
			for point in track.get_points():
				draw_circle(point, 5, color)
			draw_line(track.start_point, track.end_point, Color(0, 0, 0), 2)
