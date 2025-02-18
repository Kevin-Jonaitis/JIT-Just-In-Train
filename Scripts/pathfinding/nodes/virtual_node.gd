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

var identifier: int # A unique int identifier. 
# All nodes are either entry/exit to a track in a junction, or are ON a track
var track: Track


static func calculate_distance_between_two_connectable_nodes(node_one: VirtualNode, node_two: VirtualNode) -> float:
	var same_juction: bool = false
	var same_track: bool = node_one.track.uuid == node_two.track.uuid

	if(are_nodes_are_at_same_position(node_one, node_two)):
		return 0

	assert(same_juction || same_track, "Can't compare nodes that arn't on the same track or junction!")
	var distance_one: float = node_one.get_distance_from_front_track()
	var distance_two: float = node_two.get_distance_from_front_track()
	return absf(distance_one - distance_two)

func get_track_position() -> float:
	assert(false, "This should be implemented in the subclasses")
	return 0

func create_node_in_opposite_direction() -> VirtualNode:
	assert(false, "This should be implemented in the subclasses")
	return null

func get_distance_from_front_track() -> float:
	assert(false, "This should be implemented in the subclasses")
	return 0

func get_vector_pos() -> Vector2:
	assert(false, "This should be implemented in the subclasses")
	return Vector2()

static func are_nodes_are_at_same_position(node_one: VirtualNode, node_two: VirtualNode) -> bool:
	if (node_one is StopNode and node_two is StopNode):
		return node_one.track.uuid == node_two.track.uuid && \
		Utils.is_equal_approx(node_one.get_track_position(),node_two.get_track_position())
	elif (node_one is JunctionNode and node_two is JunctionNode):
		return (node_one as JunctionNode).junction.name == (node_two as JunctionNode).junction.name
	else:
		return false
