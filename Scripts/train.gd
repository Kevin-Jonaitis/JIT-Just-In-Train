extends Node2D

class_name Train

const TRAIN_COLLISION_LAYER: int = 8


@onready var area2d : Area2D = $Area2D
var is_placed: bool = false
var _stop_options: Array[StopOption] = []
var schedule: Schedule
var on_ready_callables: Array[Callable]
var should_loop: bool = true
@onready var schedule_follower: ScheduleFollower = $ScheduleFollower

@onready var trains: Trains = get_parent()

func _ready() -> void:
	for callable: Callable in on_ready_callables:
		callable.call()

func set_name_user(name_: String) -> void:
	on_ready_callables.append(func() -> void:
		verify_name_unique(name_)
		name = name_
	)

func verify_name_unique(name_: String) -> void:
	for maybe_train: Node in get_parent().get_children():
		if maybe_train != self and maybe_train.name == name_:
			assert(false, "Train name must be unique!")

func create_stop_option(stop_point: TrackPointInfo) -> StopOption:
	var stop: StopOption = StopOption.new(stop_point.track.add_stops_to_track(stop_point.point_index, self))
	return stop

func add_stop_option(stop_point: TrackPointInfo) -> void:
	_stop_options.append(create_stop_option(stop_point))
	calculate_schedule()

func remove_stop_option(stop_index: int) -> void:
	var stop_option: StopOption = _stop_options[stop_index]
	var point_index: int = stop_option.stop_option[0].point_index
	stop_option.stop_option[0].track.remove_stop_from_track(point_index, self)
	_stop_options.remove_at(stop_index)
	calculate_schedule()

func get_stop_options() -> Array[StopOption]:
	return _stop_options

func calculate_schedule() -> void:
	schedule = Pathfinder.find_path_with_movement(self, true, true, true)
	schedule_follower.reset()
	calculate_path_draw()

var colors: Array[Color] = [
	Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.CYAN, Color.MAGENTA, Color.ORANGE, Color.PURPLE, Color.PINK, Color.TEAL, Color.GRAY, Color.LIME, Color.AQUA, Color.OLIVE, Color.MAROON, Color.TEAL, Color.SILVER, Color.WHITE, Color.BLACK
]

func calculate_path_draw() -> void:
	trains.queue_redraw()
	if not schedule:
		return
	for path: Path in schedule.paths:
		var color: Color = colors[randi() % colors.size()]
		for segment: Path.TrackSegment in path.track_segments:
			var start_index: int = segment.start_point_index
			var end_index: int = segment.end_point_index
			var step: int = 1 if start_index < end_index else -1
			for i: int in range(start_index, end_index, step):
				var point_a: Vector2 = segment.track.get_point_at_index(i)
				var point_b: Vector2 = segment.track.get_point_at_index(i + step)
				trains.drawableFunctionsToCallLater.append(func() -> void: trains.draw_line(point_a, point_b, color, 4))
