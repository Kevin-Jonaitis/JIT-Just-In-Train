extends Node3D

class_name ScheduleFollower

# How factorio does pathfinding:
# https://wiki.factorio.com/Railway/Train_path_finding

# Pixels per second
var velocity : float = 12

@onready var train: Train = get_parent()

var front_car_index: int = 0

func get_car_progresses() -> Array[CarProgress]:
	var result: Array = train._cars.map(func(car: TrainCar) -> CarProgress: return car.progress)
	var cast_type: Array[CarProgress] = []
	cast_type.assign(result)
	return cast_type

func _process(delta: float) -> void:
	if (!train.is_placed): # Make's debugging easier, would be caught by no schedule
		return
	update_train_position(delta)
	# train.queue_redraw()

var _use_last_car_as_front: bool = false


var front_car : TrainCar

# Which car is moving "forward"
func is_trained_backwards() -> bool:
	return _use_last_car_as_front

func flip_front_car() -> void:
	if (_use_last_car_as_front):
		_use_last_car_as_front = false
		front_car = train._cars[0]
	else:
		_use_last_car_as_front = true
		front_car = train._cars[train._cars.size() - 1]

func reverse() -> void:
	flip_front_car()


func reset() -> void:
	for car: TrainCar in train._cars:
		# car_progresses.append(car_progress)
		car.progress = CarProgress.new()
	# _progress = Progress.new(train)

func ready() -> void:
	reset()


func set_position_on_track(pointInfo: TrackPointInfo) -> void:
	var car_center: Vector2 = pointInfo.get_point()
	front_car.position = Vector3(car_center.x, Train.TRAIN_CAR_HEIGHT, car_center.y)
	front_car.rotation = Vector3(0, - pointInfo.angle - 3 * PI / 2, 0)

	var front_car_position : Transform3D = front_car.global_transform
	var front_boogie_global_position : Vector3 = front_car_position.origin + front_car.global_transform.basis * Vector3(0, 0.826, Train.FRONT_BOOGIE_OFFSET)
	var back_boogie_global_position : Vector3 = front_car_position.origin + front_car.global_transform.basis * Vector3(0, 0.826, Train.BACK_BOOGIE_OFFSET)


	# Has to be searched the front car position is set since the boogies are locally offset from the car
	var front_boogie_point_info: TrackPointInfo = train.track_intersection_searcher.check_for_overlaps_at_position(Utils.convert_to_2d(front_boogie_global_position))
	var back_boogie_point_info: TrackPointInfo = train.track_intersection_searcher.check_for_overlaps_at_position(Utils.convert_to_2d(back_boogie_global_position))
	
	if !(front_boogie_point_info && back_boogie_point_info):
		return

	front_car.boogie_front.global_position = Vector3(front_boogie_point_info.get_point().x, 
	front_car.position.y + Train.BOGIE_HEIGHT, front_boogie_point_info.get_point().y)
	
	front_car.boogie_back.global_position = Vector3(back_boogie_point_info.get_point().x,
	front_car.position.y + Train.BOGIE_HEIGHT, back_boogie_point_info.get_point().y)

	front_car.boogie_front.global_rotation = Vector3(0, set_train_rotation(front_boogie_point_info.angle), 0)
	front_car.boogie_back.global_rotation = Vector3(0, set_train_rotation(back_boogie_point_info.angle), 0)

func set_train_rotation(radians: float) -> float:
	return - radians - 3 * PI / 2

func set_boogie_rotation(car_center_angle: float, radians: float) -> float:
	return car_center_angle - radians

func set_position_and_rotation(position_: Vector2, rotation_: float) -> void:
	front_car.position = Vector3(position_.x, 0.666, position_.y)
	front_car.rotation = Vector3(0, offset_rotation(rotation_), 0)
	#TODO: modify all the following cars

static func offset_rotation(angle: float) -> float:
	return - angle - 3 * PI / 2

func update_train_position(delta: float) -> void:
	var schedule: Schedule  = train.schedule
	var position_change : float = velocity * delta
	if (!schedule):
		return
	if (!train.schedule.is_loop):
		return
	for car: TrainCar in train._cars:
		var car_progress: CarProgress = car.progress
		var front_progress: Progress
		var front_boogie_progress: Progress
		var back_boogie_progress : Progress
		var center_car_progress: Progress
		front_progress = move_progress(car_progress.front, schedule, position_change, true)
		center_car_progress = move_progress(front_progress, schedule, - Train.CAR_LENGTH / 2)



		if (!_use_last_car_as_front):
			front_boogie_progress = move_progress(center_car_progress, schedule, Train.FRONT_BOOGIE_OFFSET)
			back_boogie_progress = move_progress(center_car_progress, schedule, - Train.BACK_BOOGIE_OFFSET)
		else:
			front_boogie_progress = move_progress(center_car_progress, schedule, - Train.FRONT_BOOGIE_OFFSET)
			back_boogie_progress = move_progress(center_car_progress, schedule, Train.BACK_BOOGIE_OFFSET)

		car_progress.front = front_progress
		car_progress.center = center_car_progress
		car_progress.front_boogie = front_boogie_progress
		car_progress.back_boogie = back_boogie_progress
		car.set_position_and_rotation(car_progress) # Should we change this?
		position_change = position_change - Train.CAR_LENGTH



	# get_car_progresses()[0].front_boogie = move_progress(get_car_progresses()[0].front_boogie, schedule, position_change)

	# _progress = update_progress(_progress, schedule, position_change)		
	# Check again incase we overshot the schedule
	if (!train.schedule.is_loop): 
		return

func move_progress(
		base: Progress,
		schedule: Schedule,
		delta_px: float,
		allow_reversing: bool = false,
	) -> Progress:

	var p : Progress = Progress.copy(base)

	var path_idx: int  = p.path_index
	var seg_idx : int  = p.track_segment_index
	var seg_pos : float = p.track_segment_progress   # distance into segment

	var dist_left : float = delta_px                        # signed

	var previous_path_index: int
	var previous_segment_index: int

	while dist_left != 0.0:
		var path : Path = schedule.paths[path_idx]
		var seg  : Path.TrackSegment = path.track_segments[seg_idx]
		var seg_len: float = seg.get_length()
		previous_path_index = path_idx
		previous_segment_index = seg_idx


		if dist_left > 0.0:
			# ── forward ────────────────────────────────────────────────
			var to_end : float = seg_len - seg_pos
			if dist_left <= to_end:
				seg_pos += dist_left
				dist_left = 0.0
			else:
				dist_left -= to_end
				seg_idx  += 1
				seg_pos   = 0.0

				if path.check_if_track_segment_starts_with_reverse_node(seg_idx):
					dist_left += train.CAR_LENGTH * (train._cars.size() - 1)
					reverse()

				if seg_idx >= path.track_segments.size():
					path_idx += 1
					seg_idx   = 0
					if path_idx >= schedule.paths.size():
						if schedule.is_loop:
							path_idx = 0
						else:
							dist_left = 0.0    # clamp at schedule end
		else:
			# ── backward ───────────────────────────────────────────────
			var to_start : float = seg_pos
			if -dist_left <= to_start:
				seg_pos += dist_left          # dist_left is negative
				dist_left = 0.0
			else:
				dist_left += to_start         # increase toward 0
				seg_idx  -= 1
				if seg_idx < 0:
					path_idx -= 1
					if path_idx < 0:
						if schedule.is_loop:
							path_idx = schedule.paths.size() - 1
						else:
							dist_left = 0.0    # clamp at schedule start
							seg_idx   = 0
					seg   = schedule.paths[path_idx].track_segments[-1]
					seg_idx = schedule.paths[path_idx].track_segments.size() - 1
				seg   = schedule.paths[path_idx].track_segments[seg_idx]
				seg_len = seg.get_length()
				seg_pos = seg_len
		if (allow_reversing):
			dist_left += check_for_reverse(schedule, previous_path_index, path_idx, previous_segment_index, seg_idx)
		previous_path_index = path_idx
		previous_segment_index = seg_idx



	# ══ final world coords ════════════════════════════════════════════════
	var seg_final : Path.TrackSegment = schedule.paths[path_idx].track_segments[seg_idx]
	p.path_index             = path_idx
	p.track_segment_index    = seg_idx
	p.track_segment_progress = seg_pos
	p.position               = seg_final.get_position_at_progress(seg_pos)
	p.rotation               = seg_final.get_rotation_at_progress(seg_pos)

	return p

# Check if a train is reversing at a stop(_NOT_ a reverse node which is different)
func check_for_reverse(schedule: Schedule, previous_path_index: int, next_path_index: int, previous_segment_index: int, segment_index: int) -> float:
	var previous_segment: Path.TrackSegment = schedule.paths[previous_path_index].track_segments[previous_segment_index]
	var next_segment: Path.TrackSegment = schedule.paths[next_path_index].track_segments[segment_index]
	if (schedule.check_for_reverse(previous_segment, next_segment)):
		reverse()
		return train.CAR_LENGTH * (train._cars.size())
	return 0
