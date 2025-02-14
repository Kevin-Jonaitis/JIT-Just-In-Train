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
# var _connected_nodes: Dictionary


# All nodes are either entry/exit to a track in a junction, or are ON a track
var track: Track


# Array sorted in ascending order for points on the track that this node is on
func sort_stop_nodes(train: Train) -> Array[StopNode]:
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
		(sorted_dict[track_name] as Array).sort_custom(func(a: StopNode, b: StopNode) -> int: return a.track_pos < b.track_pos)
	
	var sorted_stop_nodes: Array[StopNode] = []
	if (sorted_dict.has(self.track.name)):
		sorted_stop_nodes.assign(sorted_dict[self.track.name] as Array[StopNode])
	if (sorted_stop_nodes.size() >= 2):
		assert(sorted_stop_nodes[0].track_pos <= sorted_stop_nodes[-1].track_pos, "These should be in ascending order")
	
	return sorted_stop_nodes
	

# These are "runtime" only nodes, so there's not part of the built graph
# We return the "next" stop node in point index order on the track from this node and the direction 
# the track is going in
func get_connected_nodes(train_: Train, fetch_junctions_only: bool = false) -> Array[Edge]:
	assert(false, "This should be implemented in the subclasses")
	return []

# func get_connected_nodes_including_reverse_start(train: Train, start_position: Stop.TrainPosition) -> Array[Edge]:
# 	var connected_nodes: Array[Edge] = get_connected_nodes(train)

# 	if (self.name == start_position.front_of_train.name):
# 		assert(start_position.back_of_train.is_reverse_node, "Back of train should be a reverse node!!")
# 		connected_nodes.append(Edge.new(start_position.back_of_train, Edge.COST_TO_REVERSE))
# 	return connected_nodes


static func calculate_distance_between_two_connectable_nodes(node_one: VirtualNode, node_two: VirtualNode) -> float:
	var same_juction: bool = false
	var same_track: bool = node_one.track.uuid == node_two.track.uuid

	if(are_nodes_are_at_same_position(node_one, node_two)):
		return 0

	assert(same_juction || same_track, "Can't compare nodes that arn't on the same track or junction!")
	var distance_one: float = node_one.get_distance_from_front_track()
	var distance_two: float = node_two.get_distance_from_front_track()
	return absf(distance_one - distance_two)

#TODO: Refactor these so they're simpiler
func erase_connected_node(node: VirtualNode) -> void:
	Graph.remove_edge(self.name, node.name)

func clear() -> void:
	Graph.remove_node(self)
	# _connected_nodes.clear()
	
func add_connected_node(node: VirtualNode, cost: float) -> void:
	Graph.add_edge(self, node, cost)
	# _connected_nodes[node.name] = Edge.new(node, cost)

# func add_connected_reverse_node(node: VirtualNode, edge: Edge) -> void:
# 	_connected_nodes[node.name] = edge


func get_track_position() -> float:
	assert(false, "This should be implemented in the subclasses")
	return 0

func create_node_in_opposite_direction() -> VirtualNode:
	assert(false, "This should be implemented in the subclasses")
	return null

func get_distance_from_front_track() -> float:
	assert(false, "This should be implemented in the subclasses")
	return 0

static func are_nodes_are_at_same_position(node_one: VirtualNode, node_two: VirtualNode) -> bool:
	if (node_one is StopNode and node_two is StopNode):
		return node_one.track.uuid == node_two.track.uuid && \
		Utils.is_equal_approx(node_one.get_track_position(),node_two.get_track_position())
	elif (node_one is JunctionNode and node_two is JunctionNode):
		return (node_one as JunctionNode).junction.name == (node_two as JunctionNode).junction.name
	else:
		return false
