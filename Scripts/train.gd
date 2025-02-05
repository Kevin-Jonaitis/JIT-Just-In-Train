extends Node2D

class_name Train

const TRAIN_COLLISION_LAYER: int = 8


var length : float = 109 #TODO: Set this to a a real value based on the train sprites
@onready var area2d : Area2D = $Area2D
var is_placed: bool = false
var _stops: Array[Stop] = []
var schedule: Schedule
var on_ready_callables: Array[Callable]
var should_loop: bool = true
@onready var schedule_follower: ScheduleFollower = $ScheduleFollower

@onready var trains: Trains = get_parent()
@onready var junctions: Junctions = $"../../Junctions"

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

func create_stop(stop_point: TrackPointInfo, train_placed_forward: bool) -> Stop:
	return Stop.create_stop_for_point(stop_point, self, train_placed_forward)

func add_stop_option(stop_point: TrackPointInfo, train_placed_forward: bool) -> void:
	_stops.append(create_stop(stop_point, train_placed_forward))
	calculate_schedule()

func remove_stop(stop_index: int) -> void:
	# var stop: Stop = _stops[stop_index]
	# var point_index: int = stop.stop_option[0].point_index
	_stops.remove_at(stop_index)
	calculate_schedule()

func get_stops() -> Array[Stop]:
	return _stops

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
