extends Node2D

class_name ScheduleFollower

# How factorio does pathfinding:
# https://wiki.factorio.com/Railway/Train_path_finding

# Only true if the start and the end are the same

# Pixels per second
var velocity : float = 100

var _progress: Progress

@onready var train: Train = get_parent()

# func _init(train_: Train) -> void:
# 	self.train = train_

func _physics_process(delta: float) -> void:
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
	if (_progress.overshoot && !train.schedule.is_loop):
		return

	_progress = update_progress(_progress, schedule, position_change)
	# Check again incase we overshot the schedule
	if (_progress.overshoot && !train.schedule.is_loop): 
		return
	while (_progress.overshoot && train.schedule.is_loop):
		_progress = Progress.new(train)
		_progress = update_progress(_progress, schedule, _progress.overshoot)

	assert(_progress.overshoot == 0, "Overshoot should be 0")
	train.position = _progress.position

func update_progress(old_progress: Progress, schedule: Schedule, progress_px: float) -> Progress:
	var new_progress: Progress
	var current_path_index: int = old_progress.path_index
	var path: Path = schedule.paths[current_path_index]
	new_progress = path.update_progress(old_progress, progress_px, train.length)

	while (new_progress.path_overshoot):
		current_path_index += 1
		if (current_path_index == schedule.paths.size()): # We overshot the whole schedule
			new_progress = Progress.new(train)
			new_progress.set_overshoot(new_progress.overshoot)
			# overshoot_progress.set_overshoot(progress.overshoot)
			return
		path = schedule.paths[current_path_index]
		new_progress.path_index = current_path_index
		progress_px = new_progress.overshoot
		new_progress = path.update_progress(new_progress, progress_px, train.length)

	assert(new_progress.overshoot == 0, "Overshoot should be 0")
	return new_progress