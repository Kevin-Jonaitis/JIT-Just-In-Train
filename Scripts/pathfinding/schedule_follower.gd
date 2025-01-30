extends Node2D

class_name ScheduleFollower

# How factorio does pathfinding:
# https://wiki.factorio.com/Railway/Train_path_finding

# Only true if the start and the end are the same

# Pixels per second
var velocity : float = 100

var progress: Progress = Progress.new()

@onready var train: Train = get_parent()

func is_looped() -> bool:
	return train.schedule.get_start_node() == train.schedule.get_end_node()

# func _init(train_: Train) -> void:
# 	self.train = train_

func _physics_process(delta: float) -> void:
	update_train_position(delta)
	train.queue_redraw()

func reset() -> void:
	progress = Progress.new()

# func get_initial_position() -> Vector2:
# 	return train.schedule.get_start_node().get_position()

func update_train_position(delta: float) -> void:
	if (progress.overshoot): # Don't do anything
		return
	var position_change : float = velocity * delta
	var schedule: Schedule  = train.schedule
	if (schedule):
		progress = schedule.get_updated_progress(progress, position_change)
		if (progress.overshoot):
			return
		train.position = progress.position
