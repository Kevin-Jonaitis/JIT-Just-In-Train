extends Node3D

class_name Train

const TRAIN_COLLISION_LAYER: int = 8
var BOGIE_HEIGHT: float = 0.826
var TRAIN_CAR_HEIGHT: float = 0.64
@onready var track_intersection_searcher: TrackIntersectionSearcher3D = TrackIntersectionSearcher3D.new(self)

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
var can_reverse: bool = true

var front_car : TrainCar

# Used by deferred queue to update the schedule maximum once per frame
var update_schedule_dirty: bool = false

# whether the train's "back"(the last-added car) is starting direction of travel or not
var _use_last_car_as_front: bool = false
@onready var schedule_follower: ScheduleFollower = $ScheduleFollower
# @onready var front_offset: Node2D = $FrontOffset
#TODO: cleanup to use global directly
@onready var trains: Trains = get_tree().get_first_node_in_group("trains")
@onready var junctions: Junctions = get_tree().get_first_node_in_group("Junctions")


func flip_front_car() -> void:
	if (_use_last_car_as_front):
		_use_last_car_as_front = false
		front_car = _cars[0]
	else:
		_use_last_car_as_front = true
		front_car = _cars[_cars.size() - 1]

# set the boogie rotation and the train position
func set_position_on_track(pointInfo: TrackPointInfo) -> void:
	var car_center: Vector2 = pointInfo.get_point()
	front_car.position = Vector3(car_center.x, TRAIN_CAR_HEIGHT, car_center.y)
	front_car.rotation = Vector3(0, - pointInfo.angle - 3 * PI / 2, 0)

	var front_car_position : Transform3D = front_car.global_transform
	var front_boogie_global_position : Vector3 = front_car_position.origin + front_car.global_transform.basis * Vector3(0, 0.826, 2.229)
	var back_boogie_global_position : Vector3 = front_car_position.origin + front_car.global_transform.basis * Vector3(0, 0.826, -2.331)


	# Has to be searched the front car position is set since the boogies are locally offset from the car
	var front_boogie_point_info: TrackPointInfo = track_intersection_searcher.check_for_overlaps_at_position(Utils.convert_to_2d(front_boogie_global_position))
	var back_boogie_point_info: TrackPointInfo = track_intersection_searcher.check_for_overlaps_at_position(Utils.convert_to_2d(back_boogie_global_position))
	
	if !(front_boogie_point_info && back_boogie_point_info):
		return

	front_car.boogie_front.global_position = Vector3(front_boogie_point_info.get_point().x, 
	front_car.position.y + BOGIE_HEIGHT, front_boogie_point_info.get_point().y)
	
	front_car.boogie_back.global_position = Vector3(back_boogie_point_info.get_point().x,
	front_car.position.y + BOGIE_HEIGHT, back_boogie_point_info.get_point().y)

	front_car.boogie_front.global_rotation = Vector3(0, set_train_rotation(front_boogie_point_info.angle), 0)
	front_car.boogie_back.global_rotation = Vector3(0, set_train_rotation(back_boogie_point_info.angle), 0)

func set_train_rotation(radians: float) -> float:
	return - radians - 3 * PI / 2

func set_boogie_rotation(car_center_angle: float, radians: float) -> float:
	return car_center_angle - radians

func set_position_and_rotation(position_: Vector2, rotation_: float) -> void:
	front_car.position = Vector3(position_.x, 0, position_.y)
	front_car.rotation = Vector3(0, - rotation_ - 3 * PI / 2, 0)
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
	DeferredQueue.queue_update_schedule(self)

func replace_stop_at_index(stop: Stop, index: int) -> void:
	$Stops.get_children()[index].replace_by(stop)
	DeferredQueue.queue_update_schedule(self)


func remove_stop(stop_index: int) -> void:
	# var stop: Stop = _stops[stop_index]
	# var point_index: int = stop.stop_option[0].point_index
	_stops[stop_index].free()
	# _stops.remove_at(stop_index)
	DeferredQueue.queue_update_schedule(self)

func get_stops() -> Array[Stop]:
	return _stops

func calculate_schedule() -> void:
	if update_schedule_dirty:
		print("NODE SIZE", Graph._nodes.size())
		print("EDGES SIZE", Graph.get_num_of_edges())
		update_schedule_dirty = false
		# Graph.debug_verify_astar_vs_graph()
		schedule = Pathfinder.find_path_with_movement(self)
		# if (schedule):
		# 	schedule.debug_print_schedule()
		#print_schedule()
		schedule_follower.reset()
		# calculate_path_draw()
		#queue_redraw() # TODO: 3D fix
		# Graph.print_graph()

var colors: Array[Color] = [
	Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.CYAN, Color.MAGENTA, Color.ORANGE, Color.PURPLE, Color.PINK, Color.TEAL, Color.GRAY, Color.LIME, Color.AQUA, Color.OLIVE, Color.MAROON, Color.TEAL, Color.SILVER, Color.WHITE, Color.BLACK
]

# func calculate_path_draw() -> void:
# 	if not schedule:
# 		return
# 	trains.queue_redraw()
# 	for path: Path in schedule.paths:
# 		var color: Color = colors[randi() % colors.size()]
# 		for segment: Path.TrackSegment in path.track_segments:
# 			var start_pos: float = segment.start_track_pos
# 			var end_pos: float = segment.end_track_pos
# 			var step: int = 5 if start_pos < end_pos else -5 # 5 px
# 			for i: int in range(start_pos, end_pos, step):
# 				var point_a: Vector2 = segment.track.get_point_at_offset(i)
# 				var point_b: Vector2 = segment.track.get_point_at_offset(i + step)
# 				trains.drawableFunctionsToCallLater.append(func() -> void: trains.draw_line(point_a, point_b, color, 4))

# func _draw() -> void:
# 	for stop: Stop in _stops:
# 		for stop_option: Stop.TrainPosition in stop.stop_option:
# 			var front_stop: StopNode = stop_option.front_of_train
# 			var end_stop: StopNode = stop_option.back_of_train
# 			var offset_vector: Vector2 = Vector2(5, 5)

# 			draw_circle(front_stop.get_vector_pos(), 3, Color.WHITE, true)
# 			draw_circle(end_stop.get_vector_pos(), 3, Color.RED, true)
# 			draw_line(front_stop.get_vector_pos() + offset_vector, end_stop.get_vector_pos() + offset_vector, Color.BLACK, 4)
