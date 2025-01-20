extends RefCounted

class_name VirtualNode

var name: String

# Map<connected_node_name NodeAndCost>
var connected_nodes: Dictionary


# nullable
# var temp_node_location: Vector2

static func new_virtual_node(junction: Junction, track: Track, is_entry: bool):
	var node = VirtualNode.new()
	node.name = generate_name(junction, track, is_entry)
	node.connected_nodes = {}
	return node

# I know, holding data in the string name is not the fastest or most secure, but string parsing is a well-explored area and makes the code simpiler/more flexible
func get_temp_node_point_index():
	assert(!name.begins_with("temp"), "This isn't a temp node, a bad call was made here")
	var split = name.split("-")
	return int(split[2])

func get_temp_track_name():
	assert(!name.begins_with("temp"), "This isn't a temp node, a bad call was made here")
	var split = name.split("-")
	return split[1]

	
static func new_temp_node(track: Track, point_index: int, direction: bool, train: Train):
	var node_name = generate_name_temp_node(track, point_index, direction, train)
	var node = VirtualNode.new()
	# node.temp_node_location = point
	node.name = node_name
	assert(false, "Not implemented yet")
	return node

# <junction_name>-<track-name>-<entry/exit/null>
static func generate_name(junction: Junction, track: Track, is_entry: bool):
	if (is_entry):
		return str(junction.name, "-", track.name, "-entry")
	else:
		return str(junction.name, "-", track.name, "-exit")

# <temp>-<track-name>-<index>-<train>-<direction>
static func generate_name_temp_node(track: Track, index: int, direction: bool, train: Train):
	var direction_str = "forward" if direction else "backward"
	return str("temp-", track.name, "-", index, "-", train.name, "-", direction_str)

func add_connected_node(node: VirtualNode, cost: float):
	connected_nodes[node.name] = NodeAndCost.new(node, cost)
