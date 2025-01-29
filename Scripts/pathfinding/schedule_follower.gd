extends Node2D

class_name ScheduleFollower

# How factorio does pathfinding:
# https://wiki.factorio.com/Railway/Train_path_finding

var progress: float = 0.0
# Only true if the start and the end are the same

# Pixels per second
var velocity : float = 100

var location: Location = Location.new()

@onready var train: Train = get_parent()

func is_looped() -> bool:
	return train.schedule.get_start_node() == train.schedule.get_end_node()

# func _init(train_: Train) -> void:
# 	self.train = train_

func _process(delta: float) -> void:
	update_train_position(delta)
	# train.queue_redraw()

func reset() -> void:
	progress = 0.0
	location = Location.new()

# func get_initial_position() -> Vector2:
# 	return train.schedule.get_start_node().get_position()

func update_train_position(delta: float) -> void:
	if (location.overshoot): # Don't do anything
		return
	progress = velocity * delta
	var schedule: Schedule  = train.schedule
	if (schedule):
		location = schedule.get_new_location(location, progress)
		if (location.overshoot):
			return
		train.position = location.position
		print("TRAIN POSITION", train.position)
		print("TRAIN OVERALL PROGRESS", location.track_segment_progress)
