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

# Only get connected nodes on the same trainlines. This only applies to stop nodes
# This allows each train to "see" it's own graph
# Practically, this means that when we construct stops along a track, 
# each train will have it's own directed graph along that track
# and when we're pathfinding, we only see that path(by using this function)
# func get_connected_nodes(train_name: String) -> Array[Edge]:
# 	var result: Array[Edge] = []
# 	# Workaround for https://github.com/godotengine/godot/issues/72566
# 	result.assign(_connected_nodes.values().filter(
# 		func(node: Edge) -> bool: 
# 			if node.virtual_node is StopNode && (node.virtual_node as StopNode).train.name != train_name:
# 				return false
# 			else:
# 				return true
# 			))
# 	return result



func get_connected_nodes(train: Train) -> Array[Edge]:
	var edges_to_return: Array[Edge] = []
	var possible_stop_edge: Edge = get_connected_stop_node_edge(train)
	if (possible_stop_edge):
		edges_to_return.append(possible_stop_edge)

	if (self is JunctionNode):
		edges_to_return.append_array((self as JunctionNode).get_reverse_edges(train))
	
	return edges_to_return


func get_connected_nodes_including_reverse_start(train: Train, start_position: Stop.TrainPosition, end_node: StopNode) -> Array[Edge]:
	var connected_nodes: Array[Edge] = get_connected_nodes(train)

	if (self.name == start_position.front_of_train.name):

		#TODO: Handled by stop node connected edge coe


		# assert(self is StopNode, "This should only be called on a stop node")
		# # If this node is the start position, we should connect the next nodes as well
		# var distance_to_node: float = abs(this_point - self.track.get_distance_to_point(self.get_point_index()))
		# var track_length: float = self.track.length
		# if ((self as StopNode).is_forward()):
		# 	edges_to_return.append(Edge.new(self.track.end_junction.get_junction_node(self.track, true), 
		# 	track_length - distance_to_node))
		# else:
		# 	edges_to_return.append(Edge.new(self.track.start_junction.get_junction_node(self.track, false), 
		# 	distance_to_node))

		# If we're at the start of pathfinding, we should be able to reverse the train for FREE
		assert(start_position.back_of_train.is_reverse_node, "Back of train should be a reverse node!!")
		connected_nodes.append(Edge.new(start_position.back_of_train, 0))

		# We should also add the end of the junction to this path

	# Handled by connected stop nodes		

	# # Add the goal stop node if its viable
	# var goal_point: int = end_node.get_point_index()
	# if (track.uuid == end_node.track.uuid):
	# 	for edge: Edge in _connected_nodes.values():
	# 		if (track.uuid == edge.virtual_node.track.uuid): 
	# 			var next_point: float = edge.virtual_node.get_point_index()
	# 			if (next_point != this_point): # This means we are comparing internal nodes in a junction
	# 				if (this_point < goal_point && goal_point < next_point) or (next_point < goal_point && goal_point < this_point):
	# 					var cost: float = abs(goal_point - this_point)
	# 					return [Edge.new(end_node, cost)]

	
	return connected_nodes


# func get_connected_nodes_new(train: Train) -> Array[Edge]:

# These are "runtime" only nodes, so there's not part of the built graph
# We return the "next" stop node in point index order on the track from this node and the direction 
# the track is going in
func get_connected_stop_node_edge(train: Train) -> Edge:
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
			var possible_stop_points: Array[StopNode] = sorted_dict[self_casted.track.name]
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
		sorted_stop_nodes.assign(sorted_dict[self.track.name])
		var distance_to_self: float = self.track.get_distance_to_point(self.get_point_index())
		if (self as StopNode).is_forward():
			for stopNode : StopNode in sorted_stop_nodes:
				if (stopNode.point_index > self.get_point_index()):
					var distance_to_stopNode: float = self.track.get_distance_to_point(stopNode.point_index)
					return Edge.new(stopNode, absf(distance_to_stopNode - distance_to_self))
		else:
			for i: int in range(sorted_stop_nodes.size() - 1, -1, -1):
				if (sorted_stop_nodes[i].point_index < self.get_point_index()):
					var distance_to_stopNode: float = self.track.get_distance_to_point(sorted_stop_nodes[i].point_index)
					return Edge.new(sorted_stop_nodes[i], absf(distance_to_stopNode - distance_to_self))
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
	var same_track: bool = node_one.track.uuid == node_two.track.uuid && same_juction
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
