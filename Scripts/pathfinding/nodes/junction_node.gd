extends VirtualNode

# Used for pathfinding
# Internal node used in a junction
class_name JunctionNode


var junction: Junction
# Wether this junction is connected at the start or end POINT INDEX of the track
var connected_at_start_of_track: bool
func _init(junction: Junction, track: Track, is_entry: bool, connected_at_start_: bool):
	self.name = generate_name(junction, track, is_entry)
	self.track = track
	self.junction = junction
	self.connected_at_start_of_track = connected_at_start_
	pass # Replace with function body.

#<junction_name>-<track-name>-<entry/exit/null>
static func generate_name(junction: Junction, track: Track, is_entry: bool):
	if (is_entry):
		return str(junction.name, "-", track.name, "-entry")
	else:
		return str(junction.name, "-", track.name, "-exit")


func get_point_index():
	if (connected_at_start_of_track):
		return 0
	else:
		return track.get_points().size() - 1

func is_connected_at_start_or_end() -> bool:
	return connected_at_start_of_track 

func is_entry_node() -> bool:
	return name.ends_with("-entry")

func is_exit_node() -> bool:
	return name.ends_with("-exit")
