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

func reverse() -> void:
	train.flip_front_car()


func reset() -> void:
	for car: TrainCar in train._cars:
		var car_progress: CarProgress = CarProgress.new()
		car_progress.front_boogie = Progress.new()
		car_progress.back_boogie = Progress.new()
		car.progress = car_progress
		# car_progresses.append(car_progress)
	# _progress = Progress.new(train)

func ready() -> void:
	reset()

func update_train_position(delta: float) -> void:
	var schedule: Schedule  = train.schedule
	var position_change : float = velocity * delta
	if (!schedule):
		return
	if (!train.schedule.is_loop):
		return
	for car: TrainCar in train._cars:
		var car_progress: CarProgress = car.progress
		car_progress.front_boogie = move_progress(car_progress.front_boogie, schedule, position_change + Train.FRONT_BOOGIE_OFFSET)
		car_progress.back_boogie = move_progress(car_progress.back_boogie, schedule, position_change + Train.BACK_BOOGIE_OFFSET)
		car.set_position_and_rotation(car_progress.front_boogie.position, car_progress.front_boogie.rotation) # Should we change this?
		car.set_position_and_rotation(car_progress.back_boogie.position, car_progress.back_boogie.rotation) # Should we change this?
		position_change = position_change - Train.CAR_LENGTH



	# get_car_progresses()[0].front_boogie = move_progress(get_car_progresses()[0].front_boogie, schedule, position_change)

	# _progress = update_progress(_progress, schedule, position_change)		
	# Check again incase we overshot the schedule
	if (!train.schedule.is_loop): 
		return


# func update_progress(old_progress: Progress, schedule: Schedule, progress_px: float) -> Progress:
# 	var new_progress: Progress
# 	var current_path_index: int = old_progress.path_index
# 	var path: Path = schedule.paths[current_path_index]

# 	new_progress = Progress.copy(old_progress)
# 	var track_segment_index: int = new_progress.track_segment_index
# 	var previous_track_segment_progress: float = new_progress.track_segment_progress
# 	var segment: Path.TrackSegment = path.track_segments[track_segment_index]
# 	var segment_length: float = segment.get_length()

# 	while (previous_track_segment_progress + progress_px) > segment_length:
# 		track_segment_index += 1
# 		if(path.check_if_track_segment_starts_with_reverse_node(track_segment_index)):
# 			# When you flip around, the "train" advances by the amount of distance we shifit our
# 			# cart position
# 			progress_px = progress_px + train.car_length * (train._cars.size() - 1)
# 			reverse()

# 		progress_px = progress_px - (segment_length - previous_track_segment_progress)
# 		previous_track_segment_progress = 0
		
# 		if track_segment_index == path.track_segments.size(): # We overshot the path(overshot the stop)
# 			current_path_index += 1
# 			track_segment_index = 0
		
# 		if (current_path_index == schedule.paths.size()): # We overshot the whole schedule
# 			if (schedule.is_loop):
# 				current_path_index = 0
# 				track_segment_index = 0
# 			else: # Stop aburptly, don't loop
# 				return new_progress

# 		path = schedule.paths[current_path_index]
# 		segment = path.track_segments[track_segment_index]
# 		segment_length = segment.get_length()
				
	
# 	var new_progress_for_track_segment: float = progress_px + previous_track_segment_progress

# 	new_progress.position = segment.get_position_at_progress(new_progress_for_track_segment)
# 	new_progress.rotation = segment.get_rotation_at_progress(new_progress_for_track_segment)
# 	new_progress.track_segment_index = track_segment_index
# 	new_progress.track_segment_progress = new_progress_for_track_segment
# 	new_progress.path_index = current_path_index

# 	return new_progress


func move_progress(
		base: Progress,
		schedule: Schedule,
		delta_px: float
	) -> Progress:

	var p : Progress = Progress.copy(base)

	var path_idx: int  = p.path_index
	var seg_idx : int  = p.track_segment_index
	var seg_pos : float = p.track_segment_progress   # distance into segment

	var dist_left : float = delta_px                        # signed

	while dist_left != 0.0:
		var path : Path = schedule.paths[path_idx]
		var seg  : Path.TrackSegment = path.track_segments[seg_idx]
		var seg_len: float = seg.get_length()

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

	# ══ final world coords ════════════════════════════════════════════════
	var seg_final : Path.TrackSegment = schedule.paths[path_idx].track_segments[seg_idx]
	p.path_index             = path_idx
	p.track_segment_index    = seg_idx
	p.track_segment_progress = seg_pos
	p.position               = seg_final.get_position_at_progress(seg_pos)
	p.rotation               = seg_final.get_rotation_at_progress(seg_pos)

	return p
