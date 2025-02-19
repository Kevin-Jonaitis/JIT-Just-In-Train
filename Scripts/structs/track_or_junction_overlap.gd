extends RefCounted


class_name TrackOrJunctionOverlap

var junction: Junction
var trackPointInfo: TrackPointInfo

func _init(junction_: Junction, interior_overlap_: TrackPointInfo) -> void:
	if (junction_ && interior_overlap_):
		assert(false, "We can't have both a junction and a middle overlap, pick one")
		return
	assert(junction_ || interior_overlap_, "We need to have either a junction or a middle overlap")
	self.junction = junction_
	self.trackPointInfo = interior_overlap_
