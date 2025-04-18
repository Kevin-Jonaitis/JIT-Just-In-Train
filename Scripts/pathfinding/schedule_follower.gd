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
	if (_progress.overshoot && !train.schedule.is_loop):
		return

	_progress = update_progress(_progress, schedule, position_change)
	# Check again incase we overshot the schedule
	if (_progress.overshoot && !train.schedule.is_loop): 
		return
	while (_progress.overshoot && train.schedule.is_loop):
		var new_progress : float = _progress.overshoot
		_progress = Progress.new(train)
		_progress = update_progress(_progress, schedule, new_progress)

	assert(_progress.overshoot == 0, "Overshoot should be 0")
	train.set_position_and_rotation(_progress.position, _progress.rotation) # Should we change this?

func update_progress(old_progress: Progress, schedule: Schedule, progress_px: float) -> Progress:
	var new_progress: Progress
	var current_path_index: int = old_progress.path_index
	var path: Path = schedule.paths[current_path_index]
	new_progress = path.update_progress(old_progress, progress_px, train)

	while (new_progress.path_overshoot != 0):
		current_path_index += 1
		if (current_path_index == schedule.paths.size()): # We overshot the whole schedule
			var path_overshoot: float = new_progress.path_overshoot
			new_progress = Progress.new(train)
			new_progress.set_overshoot(path_overshoot)
			return new_progress
		progress_px = new_progress.path_overshoot
		new_progress = Progress.new(train)
		new_progress.path_index = current_path_index
		path = schedule.paths[current_path_index]
		new_progress = path.update_progress(new_progress, progress_px, train)

	assert(new_progress.overshoot == 0, "Overshoot should be 0")
	assert(new_progress.path_overshoot == 0, "path overshoot should be 0")

	return new_progress
