extends RefCounted

class_name VirtualNodeManager
var track: Track

func _init(track_: Track):
	self.track = track_


# Nodes that connect across a track
func setup_interjunction_virtual_nodes():
	assert(track.start_junction && track.end_junction, "We should have junctions by now! Can't construct pathfinding nodes without them!")
	var start_entry_node = track.start_junction.get_virtual_node(track, true)
	var start_exit_node = track.start_junction.get_virtual_node(track, false)
	var end_entry_node = track.end_junction.get_virtual_node(track, true)
	var end_exit_node = track.end_junction.get_virtual_node(track, false)

	start_exit_node.add_connected_node(end_entry_node, track.length())
	end_exit_node.add_connected_node(start_entry_node, track.length())
	pass

# We need to do this, otherwise, we'll have a memory leak, because of cyclic references
func delete_interjunction_virtual_nodes():
	assert(track.start_junction && track.end_junction, "We should have both junctions! Something went wrong")
	track.start_junction.remove_virtual_nodes_and_references(track)
	track.end_junction.remove_virtual_nodes_and_references(track)

func add_stops_to_track(point_index: int, train: Train) -> Array[StopNode]:
	var start_entry_node: VirtualNode = track.start_junction.get_virtual_node(track, true)
	var start_exit_node: VirtualNode = track.start_junction.get_virtual_node(track, false)
	var end_entry_node: VirtualNode = track.end_junction.get_virtual_node(track, true)
	var end_exit_node: VirtualNode = track.end_junction.get_virtual_node(track, false)

	var temp_node_start_junc_end_junc = StopNode.new(track, point_index, true, train)
	var temp_node_end_junc_start_junc = StopNode.new(track, point_index, false, train)

	insert_stop_between_junctions(start_exit_node, end_entry_node, temp_node_start_junc_end_junc)
	insert_stop_between_junctions(end_exit_node, start_entry_node, temp_node_end_junc_start_junc)

	return [temp_node_end_junc_start_junc, temp_node_start_junc_end_junc]

func remove_stop_from_track(point_index: int, train: Train) -> void:
	var start_entry_node: VirtualNode = track.start_junction.get_virtual_node(track, true)
	var start_exit_node: VirtualNode = track.start_junction.get_virtual_node(track, false)
	var end_entry_node: VirtualNode = track.end_junction.get_virtual_node(track, true)
	var end_exit_node: VirtualNode = track.end_junction.get_virtual_node(track, false)

	var node_forward_name = StopNode.generate_name(track, point_index, true, train)
	var node_backward_name  = StopNode.generate_name(track, point_index, false, train)

	delete_stop_between_junctions(start_exit_node, end_entry_node, node_forward_name)
	delete_stop_between_junctions(end_exit_node, start_entry_node, node_backward_name)


func insert_stop_between_junctions(start_node: JunctionNode, end_node: JunctionNode, node_of_interest: StopNode) -> void:
	var current_node = start_node
	while current_node != end_node:
		assert(current_node.connected_nodes.values().size() == 1, "We should only have one connected node")
		var next_node: VirtualNode = current_node.connected_nodes.values()[0].virtual_node
		if (next_node == end_node):
				insert_stop_between_nodes(current_node, next_node, node_of_interest)
				return 
		assert(next_node is StopNode, "We should only have stop nodes in between")
		if (next_node.point_index < node_of_interest.point_index):
			insert_stop_between_nodes(current_node, next_node, node_of_interest)
			return
		current_node = next_node

	assert(false, "We should have found the node spot and returned")

func delete_stop_between_junctions(start_node: JunctionNode, end_node: JunctionNode, stop_name: String) -> void:
	var current_node = start_node
	while current_node != end_node:
		assert(current_node.connected_nodes.values().size() == 1, "We should only have one connected node")
		var next_node: VirtualNode = current_node.connected_nodes.values()[0].virtual_node
		if (next_node.name == stop_name):
				remove_stop_after_this_node(current_node)
				return 
		current_node = next_node
	
	assert(false, "We should have found the node and returned")

# Always returns a positive value
static func cost_between_nodes(node1: VirtualNode, node2: VirtualNode) -> float:
	if (node1 is JunctionNode and node2 is JunctionNode):
		assert(node1.track.uuid == node2.track.uuid, "Junction nodes should be on the same track")
		return node1.track.get_length()
	elif (node1 is JunctionNode and node2 is StopNode):
		return abs(node2.track.get_distance_to_point(node2.point_index))
	elif (node1 is StopNode and node2 is JunctionNode):
		return abs(node1.track.get_distance_to_point(node1.point_index))
	elif (node1 is StopNode and node2 is StopNode):
		var distance_to_node_1 = node1.temp_node_track.get_distance_to_point(node1.temp_node_index)
		var distance_to_node_2 = node2.temp_node_track.get_distance_to_point(node2.temp_node_index)
		return abs(distance_to_node_2 - distance_to_node_1)
	else:
		assert(false, "We should never get here")
		return 0

static func insert_stop_between_nodes(node1: VirtualNode, node2: VirtualNode, new_node: StopNode):
	var cost_1_to_new = cost_between_nodes(node1, new_node)
	var cost_new_to_2 = cost_between_nodes(new_node, node2)

	node1.add_connected_node(new_node, cost_1_to_new)
	new_node.add_connected_node(node2, cost_new_to_2)
	node1.erase_connected_node(node2)

static func remove_stop_after_this_node(node_before_delete: VirtualNode):
	assert(node_before_delete.connected_nodes.size() == 1, "Node 1 should only be connected to one node")
	var node_to_delete: StopNode = node_before_delete.connected_nodes.values()[0]
	node_before_delete.connected_nodes.clear()
	assert(node_to_delete.connected_nodes.size() == 1, "Node to delete should only be connected to one node")
	var node_after_node_to_remove = node_to_delete.connected_nodes.values()[0]
	node_to_delete.connected_nodes.clear()
	node_before_delete.connected_nodes[node_after_node_to_remove.name] = node_after_node_to_remove
