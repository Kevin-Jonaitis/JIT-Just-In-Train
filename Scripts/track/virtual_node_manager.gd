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

	Graph.add_edge(start_exit_node, end_entry_node, track.get_length())
	Graph.add_edge(end_exit_node, start_entry_node, track.get_length())
	pass

# # We need to do this, otherwise, we'll have a memory leak, because of cyclic references
func delete_interjunction_virtual_nodes() -> void:
	assert(track.start_junction and track.end_junction, "We should have both junctions! Something went wrong")
	track.start_junction.remove_virtual_nodes_and_references(track)
	track.end_junction.remove_virtual_nodes_and_references(track)
