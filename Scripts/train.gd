extends Node2D

class_name Train

const TRAIN_COLLISION_LAYER: int = 8

# Length of ALL cars end-to-end(including gaps)
var length : float = 80 #TODO: Set this to a a real value based on the train sprites
# Length of a single cart of the train
const cart_length : float = 80 #TODO: Set this to a a real value based on the train sprites
const num_of_carts : int = 1 #TODO: Set this to a a real value based on the train sprites

var is_placed: bool = false
@onready var _stops: Array[Stop] :
	get:
		var stops_temp : Array[Stop] = []
		for stop: Stop in $Stops.get_children():
			stops_temp.append(stop)
		return stops_temp 
@onready var _cars: Array[TrainCar]:
	get:
		var cars_temp : Array[TrainCar] = []
		for car: TrainCar in $Cars.get_children():
			cars_temp.append(car)
		return cars_temp
var schedule: Schedule
var on_ready_callables: Array[Callable]
var should_loop: bool = true

var front_car : TrainCar

# whether the train's "back"(the last-added car) is starting direction of travel or not
var _use_last_car_as_front: bool = false
@onready var schedule_follower: ScheduleFollower = $ScheduleFollower
# @onready var front_offset: Node2D = $FrontOffset
#TODO: cleanup to use global directly
@onready var trains: Trains = Trains
@onready var junctions: Junctions = get_tree().get_first_node_in_group("Junctions")


func flip_front_car() -> void:
	if (_use_last_car_as_front):
		_use_last_car_as_front = false
		front_car = _cars[0]
	else:
		_use_last_car_as_front = true
		front_car = _cars[_cars.size() - 1]

func set_position_and_rotation(position_: Vector2, rotation_: float) -> void:
	front_car.position = position_
	front_car.rotation = rotation_
	#TODO: modify all the following cars

func _ready() -> void:
	for callable: Callable in on_ready_callables:
		callable.call()
	
	front_car = _cars[0]


func set_name_user(name_: String) -> void:
	on_ready_callables.append(func() -> void:
		verify_name_unique(name_)
		name = name_
	)

# func get_front_offset() -> Vector2:
# 	return front_offset.position

func verify_name_unique(name_: String) -> void:
	for maybe_train: Node in get_parent().get_children():
		if maybe_train != self and maybe_train.name == name_:
			assert(false, "Train name must be unique!")

func add_stop(stop: Stop) -> void:
	$Stops.add_child(stop)
	calculate_schedule()


func remove_stop(stop_index: int) -> void:
	# var stop: Stop = _stops[stop_index]
	# var point_index: int = stop.stop_option[0].point_index
	_stops[stop_index].free()
	# _stops.remove_at(stop_index)
	calculate_schedule()

func get_stops() -> Array[Stop]:
	return _stops

func calculate_schedule() -> void:
	schedule = Pathfinder.find_path_with_movement(self, true, true, false)
	schedule_follower.reset()
	calculate_path_draw()
	queue_redraw()

var colors: Array[Color] = [
	Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.CYAN, Color.MAGENTA, Color.ORANGE, Color.PURPLE, Color.PINK, Color.TEAL, Color.GRAY, Color.LIME, Color.AQUA, Color.OLIVE, Color.MAROON, Color.TEAL, Color.SILVER, Color.WHITE, Color.BLACK
]

func calculate_path_draw() -> void:
	if not schedule:
		return
	trains.queue_redraw()
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

func _draw() -> void:
	for stop: Stop in _stops:
		for stop_option: Stop.TrainPosition in stop.stop_option:
			var front_stop: StopNode = stop_option.front_of_train
			var end_stop: StopNode = stop_option.back_of_train
			var offset_vector: Vector2 = Vector2(5, 5)

			draw_circle(front_stop.get_position(), 3, Color.WHITE, true)
			draw_circle(end_stop.get_position(), 3, Color.RED, true)
			draw_line(front_stop.get_position() + offset_vector, end_stop.get_position() + offset_vector, Color.BLACK, 4)
