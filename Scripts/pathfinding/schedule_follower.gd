extends Node2D

class_name ScheduleFollower

# How factorio does pathfinding:
# https://wiki.factorio.com/Railway/Train_path_finding

# Only true if the start and the end are the same

# Pixels per second
var velocity : float = 100

var progress: Progress

@onready var train: Train = get_parent()

# func _init(train_: Train) -> void:
# 	self.train = train_

func _physics_process(delta: float) -> void:
	update_train_position(delta)
	# train.queue_redraw()

func reset() -> void:
	progress = Progress.new(train)

func ready() -> void:
	progress = Progress.new(train)

func update_train_position(delta: float) -> void:
	var schedule: Schedule  = train.schedule
	var position_change : float = velocity * delta
	if (!schedule):
		return
	if (progress.overshoot && !train.schedule.is_loop):
		return

	update_progress(schedule, position_change)
	# Check again incase we overshot the schedule
	if (progress.overshoot && !train.schedule.is_loop): 
		return
	while (progress.overshoot && train.schedule.is_loop):
		progress = Progress.new(train)
		update_progress(schedule, progress.overshoot)

	assert(progress.overshoot == 0, "Overshoot should be 0")
	train.position = progress.position

func update_progress(schedule: Schedule, progress_px: float) -> void:
	# var new_progress: Progress = Progress.new(train)
	var current_path_index: int = progress.path_index
	var path: Path = schedule.paths[current_path_index]
	path.update_progress(progress, progress_px, train.length)

	while (progress.path_overshoot):
		current_path_index += 1
		if (current_path_index == schedule.paths.size()): # We overshot the whole schedule
			progress = Progress.new(train)
			progress.set_overshoot(progress.overshoot)
			# overshoot_progress.set_overshoot(progress.overshoot)
			return
		path = schedule.paths[current_path_index]
		progress.path_index = current_path_index
		progress_px = progress.overshoot
		path.update_progress(progress, progress_px, train.length)

	assert(progress.overshoot == 0, "Overshoot should be 0")

	# new_progress.position = results.position
	# new_progress.path_index = current_path_index
	# new_progress.track_segment_index = results.track_segment_index
	# new_progress.track_segment_progress = results.track_segment_progress
