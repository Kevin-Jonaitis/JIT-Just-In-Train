extends Node2D

class_name ScheduleFollower

# How factorio does pathfinding:
# https://wiki.factorio.com/Railway/Train_path_finding

# Only true if the start and the end are the same

# Pixels per second
var velocity : float = 100

var progress: Progress = Progress.new()

@onready var train: Train = get_parent()

# func _init(train_: Train) -> void:
# 	self.train = train_

func _physics_process(delta: float) -> void:
	update_train_position(delta)
	# train.queue_redraw()

func reset() -> void:
	progress = Progress.new()

func update_train_position(delta: float) -> void:
	var schedule: Schedule  = train.schedule
	var position_change : float = velocity * delta
	if (!schedule):
		return
	if (progress.overshoot && !train.schedule.is_loop):
		return

	progress = update_progress(schedule, progress, position_change)
	# Check again incase we overshot the schedule
	if (progress.overshoot && !train.schedule.is_loop): 
		return
	while (progress.overshoot && train.schedule.is_loop):
		progress = Progress.new()
		progress = update_progress(schedule, progress, progress.overshoot)

	assert(progress.overshoot == 0, "Overshoot should be 0")
	train.position = progress.position

func update_progress(schedule: Schedule, old_progress: Progress, progress_px: float) -> Progress:
	var new_progress: Progress = Progress.new()
	var current_path_index: int = old_progress.path_index
	var path: Path = schedule.paths[current_path_index]
	var results: Path.PathLocation = path.get_new_position(old_progress.track_segment_index, old_progress.track_segment_progress, progress_px)

	while (results.overshoot):
		current_path_index += 1
		if (current_path_index == schedule.paths.size()): # We overshot the whole schedule
			var overshoot_progress: Progress = Progress.new()
			overshoot_progress.set_overshoot(results.overshoot)
			return overshoot_progress
		path = schedule.paths[current_path_index]
		new_progress.path_index = current_path_index
		progress_px = results.overshoot
		results = path.get_new_position(new_progress.track_segment_index, new_progress.track_segment_progress, progress_px)

	assert(old_progress.overshoot == 0, "Overshoot should be 0")

	new_progress.position = results.position
	new_progress.path_index = current_path_index
	new_progress.track_segment_index = results.track_segment_index
	new_progress.track_segment_progress = results.track_segment_progress
	return new_progress
