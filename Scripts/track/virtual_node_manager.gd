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



# Adds a temp node in the track at the point index, and returns the two new nodes
func add_temp_virtual_nodes(point_index: int, train: Train) -> Array[VirtualNode]:
	var point_info = track.get_point_info_at_index(point_index)
	var distance_to_start = track.get_distance_to_point(point_index)
	var length = track.dubins_path.shortest_path.length
	var distance_to_end = length - distance_to_start
	assert(distance_to_end > 0, "Somehow we have a negative distance to the end of the track!")
	var start_entry_node = track.start_junction.get_virtual_node(track, true)
	var start_exit_node: VirtualNode = track.start_junction.get_virtual_node(track, false)
	var end_entry_node = track.end_junction.get_virtual_node(track, true)
	var end_exit_node = track.end_junction.get_virtual_node(track, false)

	var temp_node_start_junc_end_junc = VirtualNode.new_temp_node(track, point_index, true, train)
	var temp_node_end_junc_start_junc = VirtualNode.new_temp_node(track, point_index, false, train)

	start_exit_node.connected_nodes.erase(end_entry_node.name)
	end_exit_node.connected_nodes.erase(start_entry_node.name)

	start_exit_node.add_connected_node(temp_node_start_junc_end_junc, distance_to_start)
	temp_node_start_junc_end_junc.add_connected_node(end_entry_node, distance_to_end)

	end_exit_node.add_connected_node(temp_node_end_junc_start_junc, distance_to_end)
	temp_node_end_junc_start_junc.add_connected_node(start_entry_node, distance_to_start)

	return [temp_node_end_junc_start_junc, temp_node_start_junc_end_junc]

# Remove a virtual node that's between a track's start and ending internal nodes
func remove_temp_virtual_node(point_index: int, train: Train):
	var start_entry_node = track.start_junction.get_virtual_node(track, true)
	var start_exit_node: VirtualNode = track.start_junction.get_virtual_node(track, false)
	var end_entry_node = track.end_junction.get_virtual_node(track, true)
	var end_exit_node = track.end_junction.get_virtual_node(track, false)

	var node_forward_name = VirtualNode.generate_name_temp_node(track, point_index, true, train)
	var node_backward_name  = VirtualNode.generate_name_temp_node(track, point_index, false, train)
	var node_forward = start_exit_node.connected_nodes[node_forward_name]
	assert(node_forward, "This should never fail if we're explicitly removing a node")
	var node_backwards = end_exit_node.connected_nodes[node_backward_name]
	assert(node_backwards, "This should never fail if we're explicitly removing a node")
	
	var forward_erased = start_exit_node.connected_nodes.erase(node_forward_name)
	assert(forward_erased, "We should have found this node")
	
	var backwards_erased = end_exit_node.connected_nodes.erase(node_backward_name)
	assert(backwards_erased, "We should have found this node")
	
	# There are still refernces from the forward and backward nodes to their next nodes,
	# but those _should_ be deleted becasuse we delete references to the forward/backwards node,
	# and that should cascade a deletion.
	# TODO: This assumption could be wrong though and there could be a memory leak

	# Reconnect two junctions together
	start_exit_node.add_connected_node(end_entry_node, 0)
	end_exit_node.add_connected_node(start_entry_node, 0)
