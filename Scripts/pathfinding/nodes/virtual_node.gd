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

func get_node_and_cost(name_: String) -> Edge:
	return _connected_nodes[name_]

# Only get connected nodes on the same trainlines. This only applies to stop nodes
# This allows each train to "see" it's own graph
# Practically, this means that when we construct stops along a track, 
# each train will have it's own directed graph along that track
# and when we're pathfinding, we only see that path(by using this function)
func get_connected_nodes(train_uuid: String) -> Array[Edge]:
	var result: Array[Edge] = []
	# Workaround for https://github.com/godotengine/godot/issues/72566
	result.assign(_connected_nodes.values().filter(
		func(node: Edge) -> bool: 
			if node.virtual_node is StopNode && (node.virtual_node as StopNode).train.name != train_uuid:
				return false
			else:
				return true
			))
	return result


func get_connected_new(train_uuid: String) -> Array[Edge]:
	return _connected_nodes.values()




func get_connected_nodes_or_goal(train: Train, train_position: Stop.TrainPosition, end_node: StopNode) -> Array[Edge]:
	var this_point: int = get_point_index()
	var edges_to_return: Array[Edge] = _connected_nodes.values()

	# If we're at the start of pathfinding, we should be able to reverse the train
	if (self == train_position.front_of_train):
		assert(train_position.back_of_train.is_reverse_node, "Back of train should be a reverse node!!")
		edges_to_return.append(Edge.new(train_position.back_of_train, 0))

	var goal_point: int = end_node.get_point_index()
	
	if (track.uuid == end_node.track.uuid):
		for edge: Edge in _connected_nodes.values():
			if (track.uuid == edge.virtual_node.track.uuid): 
				var next_point: float = edge.virtual_node.get_point_index()
				if (next_point != this_point): # This means we are not on nodes in the same junction
					if (this_point < goal_point && goal_point < next_point) or (next_point < goal_point && goal_point < this_point):
						var cost: float = abs(goal_point - this_point)
						return [Edge.new(end_node, cost)]
	if (self is JunctionNode):
		edges_to_return.append_array((self as JunctionNode).get_reverse_edges(train))
	
	return edges_to_return

func get_connected_nodes_without_reverse_edge(train_uuid: String) -> Array[Edge]:
	return get_connected_nodes(train_uuid).filter(
		func(edge: Edge) -> bool: 
			return not edge.is_reverse_edge()
			)

func get_connected_nodes_and_reverse_edge(train: Train) -> Array[Edge]:
	var result: Array[Edge] = get_connected_nodes(train.name)
	if (self is JunctionNode):
		result.append_array((self as JunctionNode).get_reverse_edges(train))
	return result


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


func get_stop_for_train_or_junction(train: Train) -> Edge:
	var nodes: Array[Edge] = get_connected_nodes(train.name)
	assert(nodes.size() <= 2, "There should not be more than 2 connected nodes")
	# Prefer the stop node
	for node: Edge in nodes:
		if node.virtual_node is StopNode && (node.virtual_node as StopNode).train == train:
			return node

	# Go through again and return junction node
	for node: Edge in nodes:
		if node.virtual_node is JunctionNode:
			return node

	assert(false, "Should never get here")
	return null

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
