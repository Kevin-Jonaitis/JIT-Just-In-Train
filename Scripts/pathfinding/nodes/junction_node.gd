extends VirtualNode

# Used for pathfinding
# Internal node used in a junction
class_name JunctionNode


var junction: Junction

func _init(junction: Junction, track: Track, is_entry: bool):
	self.name = generate_name(junction, track, is_entry)
	self.track = track
	self.junction = junction
	pass # Replace with function body.

#<junction_name>-<track-name>-<entry/exit/null>
static func generate_name(junction: Junction, track: Track, is_entry: bool):
	if (is_entry):
		return str(junction.name, "-", track.name, "-entry")
	else:
		return str(junction.name, "-", track.name, "-exit")