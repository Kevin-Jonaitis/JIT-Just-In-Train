extends Node2D

class_name Train



signal stops_changed(stops: Array[StopOption])

var uuid = Utils.generate_uuid()

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
	var stop = StopOption.new(stop_point.track.add_stops_to_track(stop_point.point_index, self))
	return stop

func add_stop(stop_point: TrackPointInfo) -> void:
	stops.append(create_stop_option(stop_point))
	emit_signal("stops_changed", stops)

func remove_stop(stop_index: int) -> void:
	var stop = stops[stop_index]
	var point_index = stop.forward_stop.point_index
	# This should remove both temp nodes
	# Kinda roundabout, but works
	stop.forward_stop.track.remove_stop_from_track(point_index, self)
	stops.remove_at(stop_index)
	emit_signal("stops_changed", stops)


var colors = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.CYAN, Color.MAGENTA, Color.ORANGE, Color.PURPLE, Color.PINK, Color.TEAL, Color.GRAY, Color.LIME, Color.AQUA, Color.OLIVE, Color.MAROON, Color.TEAL, Color.SILVER, Color.WHITE, Color.BLACK]

func _draw():
	if not schedule:
		return
	for path in schedule.stops_path:
		var color = colors[randi() % colors.size()]
		for segment in path.track_segments:
			var start_index = segment.start_point_index
			var end_index = segment.end_point_index
			var step = 1 if start_index < end_index else -1
			for i in range(start_index, end_index, step):
				var point_a = segment.track.get_point_at_index(i)
				var point_b = segment.track.get_point_at_index(i + step)
				draw_line(to_local(point_a), to_local(point_b), color, 4)
