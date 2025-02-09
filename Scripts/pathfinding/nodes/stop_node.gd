extends VirtualNode

# A stop, which typically happens on a track
# Used for pathfinding
class_name StopNode

# index of point on the track
var point_index: int
var train: Train

# Train should reverse after reaching this node
var is_reverse_node: bool = false
# Which direction the stop faces on the TRACK(i.e. if a track index points increase from left to right, 
# and this stop goes from right to left, 
# then this would be considered backward)
var forward : bool

func _init(track_: Track, point_index_: int, forward_: bool, train_: Train, is_reverse_node: bool = false) -> void:
	self.name = generate_name(track_, point_index_, forward_, train_)
	self.track = track_
	self.point_index = point_index_
	self.train = train_
	self.forward = forward_
	self.is_reverse_node = is_reverse_node

# static func create_forward_and_backward_stops(track_: Track, point_index_: int, train_: Train) -> Array[StopNode]:
# 	var forward_stop: StopNode = StopNode.new(track_, point_index_, true, train_)
# 	var backward_stop: StopNode = StopNode.new(track_, point_index_, false, train_)
# 	return [forward_stop, backward_stop]

func get_position() -> Vector2:
	return track.dubins_path.shortest_path.get_point_at_index(point_index)

func get_angle_of_point() -> float:
	return track.dubins_path.shortest_path.get_angle_at_point_index(point_index)

func is_forward() -> bool:
	return forward

static func generate_name(track_: Track, index_: int, forward: bool, train_: Train) -> String:
	var direction_str: String = "forward" if forward else "backward"
	return str("stop-", track_.name, "-", index_, "-", train_.name, "-", direction_str)

# possible connected stop node
# possible connected junction node
func get_connected_nodes(train: Train, fetch_junctions_only: bool = false) -> Array[Edge]:
	var edges_to_return: Array[Edge] = []
	var sorted_stop_nodes: Array[StopNode] = sort_stop_nodes(train)

	# Get possible connected junctions
	var distance_to_stop_node: float = track.get_distance_to_point(point_index)
	if (is_forward()):
		var junction_node: JunctionNode = track.end_junction.get_junction_node(track, true)
		edges_to_return.append(Edge.new(junction_node, track.length - distance_to_stop_node))
	else:
		var junction_node: JunctionNode = track.start_junction.get_junction_node(track, true)
		edges_to_return.append(Edge.new(junction_node, distance_to_stop_node))

	if (fetch_junctions_only):
		return edges_to_return

	# Add all stop nodes that are in the same direction past this point
	var distance_to_self: float = self.track.get_distance_to_point(self.get_point_index())
	if is_forward():
		var forward_nodes : Array[StopNode] = sorted_stop_nodes.filter(func(node: StopNode) -> bool: return node.is_forward())
		for stopNode : StopNode in forward_nodes:
			if (stopNode.point_index > self.get_point_index()):
				var distance_to_stopNode: float = self.track.get_distance_to_point(stopNode.point_index)
				edges_to_return.append(Edge.new(stopNode, absf(distance_to_stopNode - distance_to_self)))
	else:
		var backward_nodes : Array[StopNode] = sorted_stop_nodes.filter(func(node: StopNode) -> bool: return !node.is_forward())
		for i: int in range(backward_nodes.size() - 1, -1, -1):
			if (backward_nodes[i].point_index < self.get_point_index()):
				var distance_to_stopNode: float = self.track.get_distance_to_point(backward_nodes[i].point_index)
				edges_to_return.append(Edge.new(backward_nodes[i], absf(distance_to_stopNode - distance_to_self)))

	
	return edges_to_return

func create_node_in_opposite_direction() -> StopNode:
	var opposite_node: StopNode = StopNode.new(track, point_index, not is_forward(), train)
	return opposite_node

# I know, holding data in the string name is not the fastest or most secure, 
# but string parsing is a well-explored area and makes the code simpiler/more flexible
func get_point_index() -> int:
	return point_index
	# assert(name.begins_with("temp"), "This isn't a temp node, a bad call was made here")
	# var split = name.split("-")
	# return int(split[2])

# <stop>-<track-name>-<index>-<train>-<direction>
func get_track_name() -> String:
	return track.name
	# assert(name.begins_with("stop"), "This isn't a temp node, a bad call was made here")
	# var split = name.split("-")
	# return split[1]


# Stop nodes should have only one connected node
func get_connected_edge() -> Edge:
	var distance_to_point: float = track.get_distance_to_point(get_point_index())
	var track_length: float = track.length
	
	if (is_forward()):
		return Edge.new(self.track.end_junction.get_junction_node(self.track, true), 
		track_length - distance_to_point)
	else:
		return Edge.new(self.track.start_junction.get_junction_node(self.track, true), 
		distance_to_point)

func get_distance_from_front_track() -> float:
	if (forward):
		return track.get_distance_to_point(point_index)
	else:
		return track.length - track.get_distance_to_point(point_index)
