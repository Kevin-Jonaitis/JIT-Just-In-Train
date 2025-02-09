extends RefCounted

class_name VirtualNode

# This should be immutable once we set it
var name: String: 
	set(value):
		# Make it immutable after inital set. Similar to java's "final". Prevents 
		# changes to the name without also updating values like junction/track
		# not perfect because a user could still set the value to "" and then change it, but good enough
		assert(name == "", "Name cannot be changed")
		name = value

# Map<connected_node_name Edge>!! (caused at least one bug because it wasn't typed :( )
# DO NOT USE DIRECTLY, use provided functions
var _connected_nodes: Dictionary
# All nodes are either entry/exit to a track in a junction, or are ON a track
var track: Track


func get_connected_nodes(train: Train, get_reverse_edges: bool = true) -> Array[Edge]:
	var edges_to_return: Array[Edge] = []

	var possible_stop_edge: Edge = get_possible_connected_stopnode(train)
	if (possible_stop_edge):
		assert (possible_stop_edge.virtual_node is StopNode, "This function assumes that the returned value is a StopNode")
		edges_to_return.append(possible_stop_edge)
	

	var possible_junction_edge: Edge = get_possible_connected_junction_from_stopnode()
	if (possible_junction_edge):
		edges_to_return.append(possible_junction_edge)
		

	if (self is JunctionNode):
		edges_to_return.assign(_connected_nodes.values() as Array[Edge]) # Regular connected nodes
		if (get_reverse_edges):
			edges_to_return.append_array((self as JunctionNode).get_reverse_edges(train))
	
	return edges_to_return

func get_possible_connected_junction_from_stopnode() -> Edge:
	if (self is StopNode):
		var stop_node: StopNode = (self as StopNode)
		var distance_to_stop_node: float = stop_node.track.get_distance_to_point(stop_node.point_index)
		if (stop_node.is_forward()):
			var junction_node: JunctionNode = track.end_junction.get_junction_node(track, true)
			return Edge.new(junction_node, track.length - distance_to_stop_node)
		else:
			var junction_node: JunctionNode = track.start_junction.get_junction_node(track, true)
			return Edge.new(junction_node, distance_to_stop_node)
	return null

func get_connected_nodes_including_reverse_start(train: Train, start_position: Stop.TrainPosition) -> Array[Edge]:
	var connected_nodes: Array[Edge] = get_connected_nodes(train)

	if (self.name == start_position.front_of_train.name):
		assert(start_position.back_of_train.is_reverse_node, "Back of train should be a reverse node!!")
		connected_nodes.append(Edge.new(start_position.back_of_train, Edge.COST_TO_REVERSE))
	return connected_nodes


# These are "runtime" only nodes, so there's not part of the built graph
# We return the "next" stop node in point index order on the track from this node and the direction 
# the track is going in


# We are a junction node
	# possible connected stop node
	# possible connected junction node
# We are a stop node
	# possible connected stop node
	# possible connected junction node
func get_possible_connected_stopnode(train: Train) -> Edge:
	#Dict should automatically de-dupe nodes that are the same
	var stop_nodes_dict: Dictionary = {}
	for stop: Stop in train._stops:
		for position: Stop.TrainPosition in stop.stop_option:
			stop_nodes_dict[position.front_of_train.name] = position.front_of_train
			stop_nodes_dict[position.back_of_train.name] = position.back_of_train
	
	#Map<Track.name, Array[StopNode]>
	var sorted_dict: Dictionary = {}
	for node : StopNode in stop_nodes_dict.values():
		if (sorted_dict.has(node.track.name)):
			(sorted_dict[node.track.name] as Array).append(node)
		else :
			sorted_dict[node.track.name] = [node]
	
	# sort the stop nodes by point index
	for track_name: String in sorted_dict.keys():
		(sorted_dict[track_name] as Array).sort_custom(func(a: StopNode, b: StopNode) -> int: return a.point_index < b.point_index)
	
	if (self is JunctionNode):
		var self_casted: JunctionNode = (self as JunctionNode)
		if self_casted.is_entry_node():
			return null
		elif self_casted.is_exit_node():
			var possible_stop_points: Array[StopNode]
			possible_stop_points.assign(sorted_dict[self_casted.track.name])
			if (possible_stop_points):
				assert(possible_stop_points[0].point_index <= possible_stop_points[-1].point_index, "These should be in ascending order")
				var distance_from_front: float  = get_distance_from_front_track()
				if (self_casted.is_connected_at_start()):
					var stop_of_interest: StopNode = possible_stop_points[0]
					return Edge.new(stop_of_interest, distance_from_front)
				else:
					var stop_of_interest: StopNode = possible_stop_points[-1]
					return Edge.new(stop_of_interest, track.length - distance_from_front)

			
	elif (self is StopNode):
		# Get first point in sorted_dict past this point
		var sorted_stop_nodes: Array[StopNode]
		sorted_stop_nodes.assign(sorted_dict[self.track.name] as Array[StopNode])
		var distance_to_self: float = self.track.get_distance_to_point(self.get_point_index())
		if (self as StopNode).is_forward():
			var forward_nodes : Array[StopNode] = sorted_stop_nodes.filter(func(node: StopNode) -> bool: return node.is_forward())
			for stopNode : StopNode in forward_nodes:
				if (stopNode.point_index > self.get_point_index()):
					var distance_to_stopNode: float = self.track.get_distance_to_point(stopNode.point_index)
					return Edge.new(stopNode, absf(distance_to_stopNode - distance_to_self))
		else:
			var backward_nodes : Array[StopNode] = sorted_stop_nodes.filter(func(node: StopNode) -> bool: return !node.is_forward())
			for i: int in range(backward_nodes.size() - 1, -1, -1):
				if (backward_nodes[i].point_index < self.get_point_index()):
					var distance_to_stopNode: float = self.track.get_distance_to_point(backward_nodes[i].point_index)
					return Edge.new(backward_nodes[i], absf(distance_to_stopNode - distance_to_self))
	else:
		assert(false, "What other options are there??")
	
	return null

# func get_connected_nodes_without_reverse_edge(train_name: String) -> Array[Edge]:
# 	return get_connected_nodes(train_name).filter(
# 		func(edge: Edge) -> bool: 
# 			return not edge.is_reverse_edge()
# 			)

# func get_connected_nodes_and_reverse_edge(train: Train) -> Array[Edge]:
# 	var result: Array[Edge] = get_connected_nodes(train.name)
# 	if (self is JunctionNode):
# 		result.append_array((self as JunctionNode).get_reverse_edges(train))
# 	return result


# func get_connected_nodes_not_reverse(train_uuid: String) -> Array[Edge]:
# 	var result: Array[Edge] = []
# 	# Workaround for https://github.com/godotengine/godot/issues/72566
# 	result.assign(_connected_nodes.values().filter(
# 		func(node: Edge) -> bool: 
# 			if node.virtual_node is StopNode && (node.virtual_node as StopNode).train.name != train_uuid:
# 				return false
# 			elsif()
# 				return true
# 			))
# 	return result


# func get_stop_for_train_or_junction(train: Train) -> Edge:
# 	var nodes: Array[Edge] = get_connected_nodes(train.name)
# 	assert(nodes.size() <= 2, "There should not be more than 2 connected nodes")
# 	# Prefer the stop node
# 	for node: Edge in nodes:
# 		if node.virtual_node is StopNode && (node.virtual_node as StopNode).train == train:
# 			return node

# 	# Go through again and return junction node
# 	for node: Edge in nodes:
# 		if node.virtual_node is JunctionNode:
# 			return node

# 	assert(false, "Should never get here")
# 	return null


static func calculate_distance_between_two_connectable_nodes(node_one: VirtualNode, node_two: VirtualNode) -> float:
	var same_juction: bool = false
	var same_track: bool = node_one.track.uuid == node_two.track.uuid
	if (node_one is JunctionNode && node_two is JunctionNode):
		same_juction = (node_one as JunctionNode).junction.name == (node_two as JunctionNode).junction.name
		return 0

	assert(same_juction || same_track, "Can't compare nodes that arn't on the same track or junction!")
		# assert(previous_node.track.uuid == current_node.track.uuid, "We should only have paths on the same track")
	var distance_one: float = node_one.get_distance_from_front_track()
	var distance_two: float = node_two.get_distance_from_front_track()
	return absf(distance_one - distance_two)

func erase_connected_node(name_: String) -> void:
	return _connected_nodes.erase(name_)


func clear() -> void:
	_connected_nodes.clear()
	
func add_connected_node(node: VirtualNode, cost: float) -> void:
	_connected_nodes[node.name] = Edge.new(node, cost)

func add_connected_reverse_node(node: VirtualNode, edge: Edge) -> void:
	_connected_nodes[node.name] = edge


func get_point_index() -> int:
	assert(false, "This should be implemented in the subclasses")
	return 0

func create_node_in_opposite_direction() -> VirtualNode:
	assert(false, "This should be implemented in the subclasses")
	return null

func get_distance_from_front_track() -> float:
	assert(false, "This should be implemented in the subclasses")
	return 0
