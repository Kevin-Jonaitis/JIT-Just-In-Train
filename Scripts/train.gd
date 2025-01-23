extends Node2D

class_name Train



signal stops_changed(stops: Array[StopOption])

var uuid = Utils.generate_uuid()

@onready var area2d : Area2D = $Area2D

const TRAIN_COLLISION_LAYER = 8

# Used to differentiate from the "temp" train
var is_placed = false

# Could be tracks, could be Stations
# Nested Arrays don't work, so this is the best we can do
var _stop_options: Array[StopOption] = []

# Generated schedule from stops
var schedule: Schedule
	

func create_stop_option(stop_point: TrackPointInfo) -> StopOption:
	var stop = StopOption.new(stop_point.track.add_stops_to_track(stop_point.point_index, self))
	return stop

func add_stop_option(stop_point: TrackPointInfo) -> void:
	_stop_options.append(create_stop_option(stop_point))
	calculate_schedule()

func remove_stop_option(stop_index: int) -> void:
	var stop_option = _stop_options[stop_index]
	var point_index = stop_option.stop_option[0].point_index
	# This should remove both temp nodes
	# Kinda roundabout, but works
	stop_option.stop_option[0].track.remove_stop_from_track(point_index, self)
	_stop_options.remove_at(stop_index)
	calculate_schedule()

func get_stop_options() -> Array[StopOption]:
	return _stop_options

func calculate_schedule():
	schedule = Pathfinder.find_path_with_movement(self, true, true, false)
	queue_redraw()


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
