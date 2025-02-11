extends RefCounted

class_name VirtualNodeManager
var track: Track

func _init(track_: Track) -> void:
	self.track = track_


# Nodes that connect across a track
func setup_interjunction_virtual_nodes() -> void:
	assert(track.start_junction and track.end_junction, "We should have junctions by now! Can't construct pathfinding nodes without them!")
	var start_exit_node: VirtualNode = track.start_junction.get_junction_node(track, false)
	var start_entry_node: VirtualNode = track.start_junction.get_junction_node(track, true)
	var end_entry_node: VirtualNode = track.end_junction.get_junction_node(track, true)
	var end_exit_node: VirtualNode = track.end_junction.get_junction_node(track, false)

	start_exit_node.add_connected_node(end_entry_node, track.get_length())
	end_exit_node.add_connected_node(start_entry_node, track.get_length())
	pass

# # We need to do this, otherwise, we'll have a memory leak, because of cyclic references
# func delete_interjunction_virtual_nodes() -> void:
# 	assert(track.start_junction and track.end_junction, "We should have both junctions! Something went wrong")
# 	track.start_junction.remove_virtual_nodes_and_references(track)
# 	track.end_junction.remove_virtual_nodes_and_references(track)

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
			return node2_cast.track_pos
		else:
			return abs(node1_cast.track.get_length() - node2_cast.track_pos)
	elif (node1 is StopNode and node2 is JunctionNode):
		var node1_cast: StopNode = node1
		var node2_cast: JunctionNode = node2
		if (node2_cast.connected_at_start_of_track):
			return abs(node1_cast.track_pos)
		else:
			return abs(node1_cast.track.get_length() - node1_cast.track_pos)
	elif (node1 is StopNode and node2 is StopNode):
		var node1_cast: StopNode = node1
		var node2_cast: StopNode = node2
		var distance_to_node_1: float = node1_cast.track_pos
		var distance_to_node_2: float = node2_cast.track_pos
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
