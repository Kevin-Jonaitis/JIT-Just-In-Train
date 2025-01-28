extends RefCounted

class_name VirtualNodeManager
var track: Track

func _init(track_: Track) -> void:
	self.track = track_


# Nodes that connect across a track
func setup_interjunction_virtual_nodes() -> void:
	assert(track.start_junction and track.end_junction, "We should have junctions by now! Can't construct pathfinding nodes without them!")
	var start_entry_node: VirtualNode = track.start_junction.get_junction_node(track, true)
	var start_exit_node: VirtualNode = track.start_junction.get_junction_node(track, false)
	var end_entry_node: VirtualNode = track.end_junction.get_junction_node(track, true)
	var end_exit_node: VirtualNode = track.end_junction.get_junction_node(track, false)

	start_exit_node.add_connected_node(end_entry_node, track.get_length())
	end_exit_node.add_connected_node(start_entry_node, track.get_length())
	pass

# We need to do this, otherwise, we'll have a memory leak, because of cyclic references
func delete_interjunction_virtual_nodes() -> void:
	assert(track.start_junction and track.end_junction, "We should have both junctions! Something went wrong")
	track.start_junction.remove_virtual_nodes_and_references(track)
	track.end_junction.remove_virtual_nodes_and_references(track)

func add_stops_to_track(point_index: int, train: Train) -> Array[StopNode]:
	var start_entry_node: JunctionNode = track.start_junction.get_junction_node(track, true)
	var start_exit_node: JunctionNode = track.start_junction.get_junction_node(track, false)
	var end_entry_node: JunctionNode = track.end_junction.get_junction_node(track, true)
	var end_exit_node: JunctionNode = track.end_junction.get_junction_node(track, false)

	var temp_node_start_junc_end_junc: StopNode = StopNode.new(track, point_index, true, train)
	var temp_node_end_junc_start_junc: StopNode = StopNode.new(track, point_index, false, train)

	insert_stop_between_junctions(end_exit_node, start_entry_node, temp_node_end_junc_start_junc, train, Callable(self, "compare_backward"))
	insert_stop_between_junctions(start_exit_node, end_entry_node, temp_node_start_junc_end_junc, train, Callable(self, "compare_forward"))

	return [temp_node_end_junc_start_junc, temp_node_start_junc_end_junc]

func remove_stop_from_track(point_index: int, train: Train) -> void:
	var start_entry_node: JunctionNode = track.start_junction.get_junction_node(track, true)
	var start_exit_node: JunctionNode = track.start_junction.get_junction_node(track, false)
	var end_entry_node: JunctionNode = track.end_junction.get_junction_node(track, true)
	var end_exit_node: JunctionNode = track.end_junction.get_junction_node(track, false)

	var node_forward_name: String = StopNode.generate_name(track, point_index, true, train)
	var node_backward_name: String = StopNode.generate_name(track, point_index, false, train)


	delete_stop_between_junctions(start_exit_node, end_entry_node, node_forward_name, train)
	delete_stop_between_junctions(end_exit_node, start_entry_node, node_backward_name, train)

# These are used as comprators in insert_stop_between_junctions 
func compare_forward(
	current_node: VirtualNode, 
	next_node: StopNode, 
	start_node: VirtualNode, 
	node_of_interest: StopNode
) -> bool:
	if ((current_node == start_node or (current_node as StopNode).point_index <= node_of_interest.point_index) and
		next_node.point_index >= node_of_interest.point_index):
			return true
	return false

func compare_backward(
	current_node: VirtualNode, 
	next_node: StopNode, 
	start_node: VirtualNode, 
	node_of_interest: StopNode
) -> bool:
	if ((current_node == start_node or (current_node as StopNode).point_index >= node_of_interest.point_index) and
		next_node.point_index <= node_of_interest.point_index):
			return true
	return false

func insert_stop_between_junctions(
	start_node: JunctionNode, 
	end_node: JunctionNode, 
	node_of_interest: StopNode, 
	train: Train, 
	comparator: Callable
) -> void:
	var current_node: VirtualNode = start_node
	while current_node != end_node:
		var next_node: VirtualNode = current_node.get_stop_for_train_or_junction(train).virtual_node
		if (next_node == end_node):
				insert_stop_between_nodes(current_node, next_node, node_of_interest)
				return 
		assert(next_node is StopNode, "We should only have stop nodes in between")
		if (comparator.call(current_node, next_node, start_node, node_of_interest)):
			insert_stop_between_nodes(current_node, next_node, node_of_interest)
			return
		current_node = next_node

	assert(false, "We should have found the node spot and returned")

func delete_stop_between_junctions(
	start_node: JunctionNode, 
	end_node: JunctionNode, 
	stop_name: String, 
	train: Train
) -> void:
	var current_node: VirtualNode = start_node
	while current_node != end_node:
		var next_node: VirtualNode = current_node.get_stop_for_train_or_junction(train).virtual_node
		if (next_node.name == stop_name):
				remove_stop_after_this_node(current_node, train)
				return 
		current_node = next_node
	
	assert(false, "We should have found the node and returned")

# Always returns a positive value
static func cost_between_nodes(node1: VirtualNode, node2: VirtualNode) -> float:
	assert(node1.track.uuid == node2.track.uuid, "Nodes should always
	be on the same track. This code assumes we're not finding the cost
	between internal junction nodes within the same junction")
	if (node1 is JunctionNode and node2 is JunctionNode):
		return node1.track.get_length()
	elif (node1 is JunctionNode and node2 is StopNode):
		var node1_cast: JunctionNode = node1
		var node2_cast: StopNode = node2
		if (node1_cast.connected_at_start_of_track):
			return abs(node1_cast.track.get_distance_to_point(node2_cast.point_index))
		else:
			return abs(node1_cast.track.get_length() - node2_cast.track.get_distance_to_point(node2_cast.point_index))
	elif (node1 is StopNode and node2 is JunctionNode):
		var node1_cast: StopNode = node1
		var node2_cast: JunctionNode = node2
		if (node2_cast.connected_at_start_of_track):
			return abs(node1_cast.track.get_distance_to_point(node1_cast.point_index))
		else:
			return abs(node1_cast.track.get_length() - node1_cast.track.get_distance_to_point(node1_cast.point_index))
	elif (node1 is StopNode and node2 is StopNode):
		var node1_cast: StopNode = node1
		var node2_cast: StopNode = node2
		var distance_to_node_1: float = node1.track.get_distance_to_point(node1_cast.point_index)
		var distance_to_node_2: float = node2.track.get_distance_to_point(node2_cast.point_index)
		return abs(distance_to_node_2 - distance_to_node_1)
	else:
		assert(false, "We should never get here")
		return 0

static func insert_stop_between_nodes(
	node1: VirtualNode, 
	node2: VirtualNode, 
	new_node: StopNode
) -> void:
	var cost_1_to_new: float = cost_between_nodes(node1, new_node)
	var cost_new_to_2: float = cost_between_nodes(new_node, node2)

	node1.add_connected_node(new_node, cost_1_to_new)
	new_node.add_connected_node(node2, cost_new_to_2)
	
	# Do not erase pointers between junctions, this should always be a viable path
	if (node1 is JunctionNode and node2 is JunctionNode):
		return
	node1.erase_connected_node(node2.name)

static func remove_stop_after_this_node(
	node_before_delete: VirtualNode, 
	train: Train
) -> void:
	var node_to_delete: StopNode = node_before_delete.get_stop_for_train_or_junction(train).virtual_node
	node_before_delete.erase_connected_node(node_to_delete.name)
	var node_and_cost_after_node: NodeAndCost = node_to_delete.get_stop_for_train_or_junction(train)
	node_to_delete.clear()
	node_before_delete.add_connected_node(node_and_cost_after_node.virtual_node, node_and_cost_after_node.cost)
