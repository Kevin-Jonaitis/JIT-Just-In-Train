extends RefCounted

class_name Progress


var position: Vector2
var rotation: float # Rotation in radians at position
var path_index: int = 0 # index in the schedule
var track_segment_index: int = 0
var track_segment_progress: float = 0

# var train_offset: float = 0
# var facing_forward: bool = true # Do we even need this?
var train: Train

func _init(train_: Train) -> void:
	self.train = train_
	position = Vector2.ZERO
	path_index = 0
	track_segment_index = 0
	track_segment_progress = 0
	# self.train = train
	# if (!train_.train_flipped_at_start):
	# 	train_offset = -train_.length / 2
	# else:
	# 	train_offset = train_.length / 2



static func copy(progress: Progress) -> Progress:
	var new_progress: Progress = Progress.new(progress.train)
	new_progress.position = progress.position
	new_progress.path_index = progress.path_index
	new_progress.track_segment_index = progress.track_segment_index
	new_progress.track_segment_progress = progress.track_segment_progress
	# new_progress.train_offset = progress.train_offset
	# new_progress.facing_forward = progress.facing_forward
	return new_progress


func reverse() -> void:
	# facing_forward = !facing_forward
	train.flip_front_car()