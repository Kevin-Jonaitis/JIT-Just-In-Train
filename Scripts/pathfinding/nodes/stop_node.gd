extends VirtualNode

# A stop, which typically happens on a track
# Used for pathfinding
class_name StopNode

# position along the track from the front of the track
var track_pos: float
var train: Train

# Train should reverse after reaching this node
var is_reverse_node: bool = false
# Which direction the stop faces on the TRACK(i.e. if a track index points increase from left to right, 
# and this stop goes from right to left, 
# then this would be considered backward)
var forward : bool

func _init(track_: Track, track_pos_: float, forward_: bool, train_: Train, is_reverse_node_: bool = false) -> void:
	self.name = generate_name(track_, track_pos_, forward_, train_)
	self.track = track_
	self.track_pos = track_pos_
	self.train = train_
	self.forward = forward_
	self.is_reverse_node = is_reverse_node_

func get_position() -> Vector2:
	return track.dubins_path.shortest_path.get_point_at_offset(track_pos)

func get_angle_of_point() -> float:
	return track.dubins_path.shortest_path.get_angle_at_offset(track_pos)

func get_track_pos_name() -> String:
	return str(int(track_pos))

func is_forward() -> bool:
	return forward

static func generate_name(track_: Track, track_pos_: float, forward_: bool, train_: Train) -> String:
	
	var direction_str: String = "forward" if forward_ else "backward"
	var generated_name: String =  str("stop-", track_.name, "-", int(track_pos_), "-", train_.name, "-", direction_str)
	return generated_name

# possible connected stop node
# possible connected junction node 
func get_connected_nodes(train_: Train, fetch_junctions_only: bool = false) -> Array[Edge]:
	var edges_to_return: Array[Edge] = []
	var sorted_stop_nodes: Array[StopNode] = sort_stop_nodes(train_)

	# Get possible connected junctions
	var distance_to_stop_node: float = track_pos
	if (is_forward()):
		var junction_node: JunctionNode = track.end_junction.get_junction_node(track, true)
		edges_to_return.append(Edge.new(junction_node, track.length - distance_to_stop_node))
	else:
		var junction_node: JunctionNode = track.start_junction.get_junction_node(track, true)
		edges_to_return.append(Edge.new(junction_node, distance_to_stop_node))

	if (fetch_junctions_only):
		return edges_to_return

	# Add all stop nodes that are in the same direction past this point
	var distance_to_self: float  = track_pos
	if is_forward():
		var forward_nodes : Array[StopNode] = sorted_stop_nodes.filter(func(node: StopNode) -> bool: return node.is_forward())
		for stop_node : StopNode in forward_nodes:
			if (stop_node.track_pos > self.track_pos):
				var distance_to_stopNode: float = stop_node.track_pos
				edges_to_return.append(Edge.new(stop_node, absf(distance_to_stopNode - distance_to_self)))
	else:
		var backward_nodes : Array[StopNode] = sorted_stop_nodes.filter(func(node: StopNode) -> bool: return !node.is_forward())
		for i: int in range(backward_nodes.size() - 1, -1, -1):
			if (backward_nodes[i].track_pos < self.track_pos):
				var distance_to_stopNode: float = backward_nodes[i].track_pos
				edges_to_return.append(Edge.new(backward_nodes[i], absf(distance_to_stopNode - distance_to_self)))

	
	return edges_to_return

func create_node_in_opposite_direction() -> StopNode:
	var opposite_node: StopNode = StopNode.new(track, track_pos, not is_forward(), train)
	return opposite_node

# I know, holding data in the string name is not the fastest or most secure, 
# but string parsing is a well-explored area and makes the code simpiler/more flexible
func get_track_position() -> float:
	return track_pos
	# assert(name.begins_with("temp"), "This isn't a temp node, a bad call was made here")
	# var split = name.split("-")
	# return int(split[2])

# <stop>-<track-name>-<index>-<train>-<direction>
func get_track_name() -> String:
	return track.name
	# assert(name.begins_with("stop"), "This isn't a temp node, a bad call was made here")
	# var split = n	ame.split("-")
	# return split[1]


# Stop nodes should have only one connected node
func get_connected_edge() -> Edge:
	var distance_to_point: float = track_pos
	var track_length: float = track.length
	
	if (is_forward()):
		return Edge.new(self.track.end_junction.get_junction_node(self.track, true), 
		track_length - distance_to_point)
	else:
		return Edge.new(self.track.start_junction.get_junction_node(self.track, true), 
		distance_to_point)

func get_distance_from_front_track() -> float:
	return track_pos
