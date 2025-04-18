extends Node3D

class_name Train

const TRAIN_COLLISION_LAYER: int = 8
static var BOGIE_HEIGHT: float = 0.826
static var TRAIN_CAR_HEIGHT: float = 0.64
static var FRONT_BOOGIE_OFFSET: float = 2.229
static var BACK_BOOGIE_OFFSET: float = 2.331
static var TRAIN_HEIGHT_OFFSET: float = 0.666
@onready var track_intersection_searcher: TrackIntersectionSearcher3D = TrackIntersectionSearcher3D.new(self)

# Length of ALL cars end-to-end(including gaps)
var length : float = 5.35 #TODO: Set this to a a multipdle of the CAR_LENGTH the space between them
# Length of a single cart of the train
static var CAR_LENGTH : float = 5.35 #TODO: Set this to a a real value based on model; I just used a ruler to measure it
# const CAR_LENGTH : float = 80 #TODO: Set this to a a real value based on the train sprites

const num_of_cars : int = 1 #TODO: Set this to a a real value based on the train sprites

var path_line: Line3D = Line3D.new()

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


# Used by deferred queue to update the schedule maximum once per frame
var update_schedule_dirty: bool = false

# whether the train's "back"(the last-added car) is starting direction of travel or not
@onready var schedule_follower: ScheduleFollower = $ScheduleFollower
# @onready var front_offset: Node2D = $FrontOffset
#TODO: cleanup to use global directly
@onready var trains: Trains = get_tree().get_first_node_in_group("trains")
@onready var junctions: Junctions = get_tree().get_first_node_in_group("Junctions")



	# Make sure we grab the BACK of the car. 


# set the boogie rotation and the train position


func _ready() -> void:
	for callable: Callable in on_ready_callables:
		callable.call()
	
	schedule_follower.front_car = _cars[0]
	add_child(path_line)


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
		calculate_path_draw()
		# Graph.print_graph()

var colors: Array[Color] = [
	Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.CYAN, Color.MAGENTA, Color.ORANGE, Color.PURPLE, Color.PINK, Color.TEAL, Color.GRAY, Color.LIME, Color.AQUA, Color.OLIVE, Color.MAROON, Color.TEAL, Color.SILVER, Color.WHITE, Color.BLACK
]


func calculate_path_draw() -> void:
	path_line.clear()
	if not schedule:
		return
	var points : PackedVector2Array = PackedVector2Array()
	for path: Path in schedule.paths:
		for segment: Path.TrackSegment in path.track_segments:
			var start_pos: float = segment.start_track_pos
			var end_pos: float = segment.end_track_pos
			var step: int = 1 if start_pos < end_pos else -1 # 1 meter
			for i: int in range(start_pos, end_pos, step):
				points.append(segment.track.get_point_at_offset(i))
	set_line_attributes(path_line, points, 20, colors[randi() % colors.size()])


static func set_line_attributes(line: Line3D, points_2d: Array[Vector2], y_index: int, color: Color) -> void:
	var y_value: float = Utils.get_y_layer(y_index)
	var points: PackedVector3Array = PackedVector3Array()
	for point : Vector2 in points_2d:
		points.append(Vector3(point.x, y_value, point.y))
	line.points = points
	line.color = color
	line.width = 0.5
	line.billboard_mode = Line3D.BillboardMode.NONE
	line.curve_normals = calculate_normals_from_points(points)
	line.rebuild()


# # WE ASSUME THAT ALL POINTS LINE ON THE SAME FLAT(XZ) plane,
# # hence using Vector3 as our reference
static func calculate_normals_from_points(points: Array[Vector3]) -> PackedVector3Array:
	var normals: PackedVector3Array = PackedVector3Array()
	for i: int in range(points.size() - 1):
		var direction: Vector3 = points[i + 1] - points[i]
		direction.cross(Vector3.UP).normalized()
		var normal: Vector3 = Vector3(-direction.z, 0, direction.x).normalized()
		normals.append(normal)
	# Add the last normal
	if points.size() > 1:
		var last_direction: Vector3 = points[-1] - points[-2]
		last_direction.cross(Vector3.UP).normalized()
		#We should reverse the direction for the last normal
		var last_normal: Vector3 = Vector3(-last_direction.z, 0, last_direction.x).normalized()
		normals.append(last_normal)
	return normals
