extends Node3D

class_name ScheduleFollower

# How factorio does pathfinding:
# https://wiki.factorio.com/Railway/Train_path_finding

# Pixels per second
var velocity : float = 12

var _progress: Progress

@onready var train: Train = get_parent()

# func _init(train_: Train) -> void:
# 	self.train = train_

func _process(delta: float) -> void:
	if (!train.is_placed): # Make's debugging easier, would be caught by no schedule
		return
	update_train_position(delta)
	# train.queue_redraw()

func reset() -> void:
	_progress = Progress.new(train)

func ready() -> void:
	_progress = Progress.new(train)

func update_train_position(delta: float) -> void:
	var schedule: Schedule  = train.schedule
	var position_change : float = velocity * delta
	if (!schedule):
		return
	if (!train.schedule.is_loop):
		return

	_progress = update_progress(_progress, schedule, position_change)
	# Check again incase we overshot the schedule
	if (!train.schedule.is_loop): 
		return

	train.set_position_and_rotation(_progress.position, _progress.rotation) # Should we change this?

func update_progress(old_progress: Progress, schedule: Schedule, progress_px: float) -> Progress:
	var new_progress: Progress
	var current_path_index: int = old_progress.path_index
	var path: Path = schedule.paths[current_path_index]

	new_progress = Progress.copy(old_progress)
	var track_segment_index: int = new_progress.track_segment_index
	var previous_track_segment_progress: float = new_progress.track_segment_progress
	var segment: Path.TrackSegment = path.track_segments[track_segment_index]
	var segment_length: float = segment.get_length()

	while (previous_track_segment_progress + progress_px) > segment_length:
		track_segment_index += 1
		if(path.check_if_track_segment_starts_with_reverse_node(track_segment_index)):
			# When you flip around, the "train" advances by the amount of distance we shifit our
			# cart position
			progress_px = progress_px + train.cart_length * (train._cars.size() - 1)
			new_progress.reverse()

		progress_px = progress_px - (segment_length - previous_track_segment_progress)
		previous_track_segment_progress = 0
		
		if track_segment_index == path.track_segments.size(): # We overshot the path(overshot the stop)
			current_path_index += 1
			track_segment_index = 0
		
		if (current_path_index == schedule.paths.size()): # We overshot the whole schedule
			if (schedule.is_loop):
				current_path_index = 0
				track_segment_index = 0
			else: # Stop aburptly, don't loop
				return new_progress

		path = schedule.paths[current_path_index]
		segment = path.track_segments[track_segment_index]
		segment_length = segment.get_length()
				
	
	var new_progress_for_track_segment: float = progress_px + previous_track_segment_progress

	new_progress.position = segment.get_position_at_progress(new_progress_for_track_segment)
	new_progress.rotation = segment.get_rotation_at_progress(new_progress_for_track_segment)
	new_progress.track_segment_index = track_segment_index
	new_progress.track_segment_progress = new_progress_for_track_segment
	new_progress.path_index = current_path_index

	return new_progress
