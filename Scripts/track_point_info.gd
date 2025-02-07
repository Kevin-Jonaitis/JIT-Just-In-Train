extends RefCounted

class_name TrackPointInfo

var track: Track
var point_index: int
var angle: float # radians

func _init(p_track: Track, p_point_index: int, p_angle: float) -> void:
	track = p_track
	point_index = p_point_index
	angle = p_angle

func get_point() -> Vector2:
	if (track.dubins_path):
		return track.dubins_path.shortest_path._points[point_index]
	else:
		assert(false, "Unimplemented code path!")
		return Vector2.ZERO

# Could go in either direction
# func get_offset_from_point(length: float) -> Vector2:
# 	if (track.dubins_path):
# 		track.get_point_at_offset(
# 		track.dubins_path.shortest_path.off
# 		return track.dubins_path.shortest_path.get_point_at_offset(
# 	else:
# 		assert(false, "Unimplemented code path!")
# 		return Vector2.ZERO