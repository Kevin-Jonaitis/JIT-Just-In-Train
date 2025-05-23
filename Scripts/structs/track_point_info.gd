extends RefCounted

class_name TrackPointInfo

var track: Track3D
var point_index: int
var angle: float # radians

func _init(p_track: Track3D, p_point_index: int, p_angle: float) -> void:
	track = p_track
	point_index = p_point_index
	angle = p_angle

func get_point() -> Vector2:
	if (track.dubins_path):
		return track.dubins_path.shortest_path._points[point_index]
	else:
		assert(false, "Unimplemented code path!")
		return Vector2.ZERO
