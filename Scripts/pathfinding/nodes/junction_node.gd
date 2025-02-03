extends VirtualNode

# Used for pathfinding
# Internal node used in a junction
class_name JunctionNode


var junction: Junction
# Wether this junction is connected at the start or end POINT INDEX of the track
var connected_at_start_of_track: bool
func _init(junction_: Junction, track_: Track, is_entry: bool, connected_at_start_: bool) -> void:
	self.name = generate_name(junction_, track_, is_entry)
	self.track = track_
	self.junction = junction_
	self.connected_at_start_of_track = connected_at_start_

#<junction_name>-<track-name>-<entry/exit/null>
static func generate_name(junction_: Junction, track_: Track, is_entry: bool) -> String:
	if is_entry:
		return str(junction_.name, "-", track_.name, "-entry")
	else:
		return str(junction_.name, "-", track_.name, "-exit")

func create_node_in_opposite_direction() -> JunctionNode:
	var opposite_node: JunctionNode = JunctionNode.new(junction, track, not is_entry_node(), connected_at_start_of_track)
	return opposite_node

func get_point_index() -> int:
	if connected_at_start_of_track:
		return 0
	else:
		return track.get_points().size() - 1

func is_connected_at_start_or_end() -> bool:
	return connected_at_start_of_track 

func is_entry_node() -> bool:
	return name.ends_with("-entry")

func is_exit_node() -> bool:
	return name.ends_with("-exit")
