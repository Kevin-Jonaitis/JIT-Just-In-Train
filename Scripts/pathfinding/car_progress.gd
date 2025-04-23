extends RefCounted

class_name CarProgress

var front_boogie: Progress
var back_boogie: Progress
var front: Progress
var center: Progress


func _init(schedule: Schedule, track_offset: float, car_length: float) -> void:
	front_boogie = Progress.new()
	back_boogie = Progress.new()
	front = Progress.new()
	center = Progress.new()
	front.track_segment_progress = - track_offset
	center.track_segment_progress = front.track_segment_progress - car_length / 2
	
	front_boogie.track_segment_progress = center.track_segment_progress + Train.FRONT_BOOGIE_OFFSET 
	back_boogie.track_segment_progress = center.track_segment_progress - Train.BACK_BOOGIE_OFFSET
	




# func calculate_movement_from_front(delta: float) -> void
