extends RefCounted

class_name Progress


var position: Vector2
var rotation: float # Rotation in radians at position
var overshoot: float # Total overshoot of whole schedule
var path_overshoot: float # How much we overshot a path(between two stops)
var path_index: int = 0 # index in the schedule
var track_segment_index: int = 0
var track_segment_progress: float = 0
var overshoot_set: bool = false

# var train_offset: float = 0
# var facing_forward: bool = true # Do we even need this?
var train: Train

func _init(train_: Train) -> void:
	self.train = train_
	position = Vector2.ZERO
	overshoot = 0
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
	new_progress.overshoot = progress.overshoot
	new_progress.path_overshoot = progress.path_overshoot
	new_progress.path_index = progress.path_index
	new_progress.track_segment_index = progress.track_segment_index
	new_progress.track_segment_progress = progress.track_segment_progress
	new_progress.overshoot_set = progress.overshoot_set
	# new_progress.train_offset = progress.train_offset
	# new_progress.facing_forward = progress.facing_forward
	return new_progress

# func from_progress(progress: Progress): Progress
# 	position = progress.position
# 	overshoot = progress.overshoot
# 	path_index = progress.path_index
# 	track_segment_index = progress.track_segment_index
# 	track_segment_progress = progress.track_segment_progress
# 	overshoot_set = progress.overshoot_set
# 	train_offset = progress.train_offset
# 	facing_forward = progress.facing_forward

func reverse() -> void:
	# facing_forward = !facing_forward
	train.flip_front_car()


func set_overshoot(overshoot_: float) -> void:
	overshoot = overshoot_
	overshoot_set = true
	
# func _init(location_builder: LocationBuilder) -> void:
# 	assert(location_builder.position_set, "Position should be set")
# 	assert(location_builder.overshoot_set, "Overshoot should be set")
# 	assert(location_builder.path_index_set, "Path index should be set")
# 	assert(location_builder.track_segment_index_set, "Track segment index should be set")
# 	assert(location_builder.stop_index_set, "Stop index should be set")
# 	self.position = location_builder.position
# 	self.overshoot = location_builder.overshoot
# 	self.path_index = location_builder.path_index
# 	self.track_segment_index = location_builder.track_segment_index
# 	self.stop_index = location_builder.stop_index

class LocationBuilder:
	var position: Vector2
	var overshoot: float
	var path_index: int
	var track_segment_index: int
	var position_set: bool = false
	var overshoot_set: bool = false
	var path_index_set: bool = false
	var track_segment_index_set: bool = false

	func set_position(position_: Vector2) -> LocationBuilder:
		self.position = position_
		self.position_set = true
		return self

	func set_overshoot(overshoot_: float) -> LocationBuilder:
		self.overshoot = overshoot_
		self.overshoot_set = true
		return self
	
	func set_path_index(path_index_: int) -> LocationBuilder:
		self.path_index = path_index_
		self.path_index_set = true
		return self
	
	func set_track_segment_index(track_segment_index_: int) -> LocationBuilder:
		self.track_segment_index = track_segment_index_
		self.track_segment_index_set = true
		return self
