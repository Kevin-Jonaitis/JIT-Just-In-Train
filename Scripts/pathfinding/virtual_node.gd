extends RefCounted

class_name VirtualNode

# This should be immutable once we 
var name: String: 
	set(value):
		# Make it immutable after inital set. Similar to java's "final". Prevents 
		# changes to the name without also updating values like junction/track
		# not perfect because a user could still set the value to "" and then change it, but good enough
		assert(name == "", "Name cannot be changed")
		name = value

# Map<connected_node_name NodeAndCost>
var connected_nodes: Dictionary
var junction: Junction


# nullable, Maybe unnecessary
var temp_node_location: Vector2
var temp_node_index: int
var temp_node_track: Track

static func new_virtual_node(junction: Junction, track: Track, is_entry: bool):
	var node = VirtualNode.new()
	node.name = generate_name(junction, track, is_entry)
	node.connected_nodes = {}
	node.junction = junction
	return node

# I know, holding data in the string name is not the fastest or most secure, but string parsing is a well-explored area and makes the code simpiler/more flexible
func get_temp_node_point_index():
	assert(name.begins_with("temp"), "This isn't a temp node, a bad call was made here")
	var split = name.split("-")
	return int(split[2])

func get_temp_track_name():
	assert(name.begins_with("temp"), "This isn't a temp node, a bad call was made here")
	var split = name.split("-")
	return split[1]

func erase_connected_node(node: VirtualNode):
	return connected_nodes.erase(node.name)
	
static func new_temp_node(track: Track, point_index: int, forward: bool, train: Train):
	var node_name = generate_name_temp_node(track, point_index, forward, train)
	var node = VirtualNode.new()
	node.temp_node_location = track.get_point_at_index(point_index)
	node.temp_node_index = point_index
	node.name = node_name
	node.temp_node_track = track
	return node

# <junction_name>-<track-name>-<entry/exit/null>
static func generate_name(junction: Junction, track: Track, is_entry: bool):
	if (is_entry):
		return str(junction.name, "-", track.name, "-entry")
	else:
		return str(junction.name, "-", track.name, "-exit")

# <temp>-<track-name>-<index>-<train>-<direction>
static func generate_name_temp_node(track: Track, index: int, forward: bool, train: Train):
	var direction_str = "forward" if forward else "backward"
	return str("temp-", track.name, "-", index, "-", train.name, "-", direction_str)

func add_connected_node(node: VirtualNode, cost: float):
	connected_nodes[node.name] = NodeAndCost.new(node, cost)


# Always returns a positive value
static func cost_between_temp_nodes(node1: VirtualNode, node2: VirtualNode) -> float:
	var distance_to_node_1 = node1.temp_node_track.get_distance_to_point(node1.temp_node_index)
	var distance_to_node_2 = node2.temp_node_track.get_distance_to_point(node2.temp_node_index)
	return abs(distance_to_node_2 - distance_to_node_1)

static func insert_node_between_temp_nodes(node1: VirtualNode, node2: VirtualNode, new_node: VirtualNode):
	assert(new_node.temp_node_index, "Was expecting a temp node!")
	if (node1.junction)
	var cost_1_to_new = VirtualNode.cost_between_temp_nodes(node1, new_node)
	var cost_new_to_2 = VirtualNode.cost_between_temp_nodes(new_node, node2)

	node1.add_connected_node(new_node, cost_1_to_new)
	new_node.add_connected_node(node2, cost_new_to_2)
	node1.erase_connected_node(node2)
