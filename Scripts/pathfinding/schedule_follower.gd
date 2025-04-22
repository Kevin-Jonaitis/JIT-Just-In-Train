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

	# Reverse the cars if they're driving, so we can iterate over the 
	# progress correctly
	var cars_to_iterate: Array[TrainCar]
	if (!_use_last_car_as_front):
		cars_to_iterate = train._cars
	else:
		# reverse array
		cars_to_iterate = train._cars
		cars_to_iterate.reverse()
	
	var reversed : bool = 0
	var use_last_car_as_front_loop_consistent: bool = _use_last_car_as_front
	for i: int in range(cars_to_iterate.size()):
		var car_progress: CarProgress = cars_to_iterate[i].progress
		var front_progress: Progress
		var front_boogie_progress: Progress
		var back_boogie_progress : Progress
		var center_car_progress: Progress
		if (i == 0):
			# Also check if we're reversing based on this. 
			var front_progress_and_reverse: ProgressAndReverse = move_progress_with_reversing(car_progress.front, schedule, position_change, cars_to_iterate[i], true)
			front_progress = front_progress_and_reverse.progress
			if (front_progress_and_reverse.reversed):
				reversed = true
			else:
				reversed = false
		else:
			var offset_car_progress: CarProgress = cars_to_iterate[i - 1].progress
			# var reverse_distance : float = 0.0
			if (reversed):
				front_progress = move_progress(offset_car_progress.front, schedule, position_change + cars_to_iterate[i].get_car_length())
			else:
				front_progress = move_progress(offset_car_progress.front, schedule, position_change - cars_to_iterate[i -1].get_car_length())
				pass

				# reverse_distance = 
				# for j: int in range(i):
				# 	reverse_distance += cars_to_iterate[j].get_car_length() * 2
				# reverse_distance += cars_to_iterate[i].get_car_length()
				# print("REVERSE DISTANCE: ", reverse_distance)
			# front_progress = move_progress(offset_car_progress.front, schedule, position_change - cars_to_iterate[i].get_car_length() + reverse_distance)
			pass
		
		center_car_progress = move_progress(front_progress, schedule, - cars_to_iterate[i].get_car_length() / 2)

		if (cars_to_iterate[i].car_type == TrainCar.CarType.LOCOMOTIVE && reversed):
			print("AFTER REVERSED")

		if (!use_last_car_as_front_loop_consistent):
			front_boogie_progress = move_progress(center_car_progress, schedule, Train.FRONT_BOOGIE_OFFSET)
			back_boogie_progress = move_progress(center_car_progress, schedule, - Train.BACK_BOOGIE_OFFSET)
		else:
			front_boogie_progress = move_progress(center_car_progress, schedule, - Train.FRONT_BOOGIE_OFFSET)
			back_boogie_progress = move_progress(center_car_progress, schedule, Train.BACK_BOOGIE_OFFSET)

		car_progress.front = front_progress
		car_progress.center = center_car_progress
		car_progress.front_boogie = front_boogie_progress
		car_progress.back_boogie = back_boogie_progress
		if (cars_to_iterate[i].car_type == TrainCar.CarType.LOCOMOTIVE):
			print(car_progress.center.position)
		# 	cars_to_iterate[i].set_position_and_rotation(car_progress) # Should we change this?
		cars_to_iterate[i].set_position_and_rotation(car_progress) # Should we change this?


		#if (i == 1):
		# position_change = position_change - Train.CAR_LENGTH



	# get_car_progresses()[0].front_boogie = move_progress(get_car_progresses()[0].front_boogie, schedule, position_change)

	# _progress = update_progress(_progress, schedule, position_change)		
	# Check again incase we overshot the schedule
	if (!train.schedule.is_loop): 
		return

class ProgressAndReverse:
	var progress: Progress
	var reversed: bool

	func _init(progress_: Progress, reversed_: bool) -> void:
		progress = progress_
		reversed = reversed_


func move_progress(base: Progress,
		schedule: Schedule,
		delta_px: float) -> Progress:
	var result: ProgressAndReverse = move_progress_with_reversing(base, schedule, delta_px, null, false)
	return result.progress

func move_progress_with_reversing(
		base: Progress,
		schedule: Schedule,
		delta_px: float,
		train_car: TrainCar,
		allow_reversing: bool = false,
	) -> ProgressAndReverse:
	var reversed: bool = false

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
					dist_left += train_car.get_car_length() # 2x train - 1 current car
					reversed = true
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
			if (check_for_reverse(schedule, previous_path_index, path_idx, previous_segment_index, seg_idx)):
				dist_left += train_car.get_car_length() # 2x train - 1 current car
				reversed = true
		previous_path_index = path_idx
		previous_segment_index = seg_idx



	# ══ final world coords ════════════════════════════════════════════════
	var seg_final : Path.TrackSegment = schedule.paths[path_idx].track_segments[seg_idx]
	p.path_index             = path_idx
	p.track_segment_index    = seg_idx
	p.track_segment_progress = seg_pos
	p.position               = seg_final.get_position_at_progress(seg_pos)
	p.rotation               = seg_final.get_rotation_at_progress(seg_pos)

	return ProgressAndReverse.new(p, reversed)

# Check if a train is reversing at a stop(_NOT_ a reverse node which is different)
func check_for_reverse(schedule: Schedule, previous_path_index: int, next_path_index: int, previous_segment_index: int, segment_index: int) -> bool:
	var previous_segment: Path.TrackSegment = schedule.paths[previous_path_index].track_segments[previous_segment_index]
	var next_segment: Path.TrackSegment = schedule.paths[next_path_index].track_segments[segment_index]
	if (schedule.check_for_reverse(previous_segment, next_segment)):
		reverse()
		return true
	return false
