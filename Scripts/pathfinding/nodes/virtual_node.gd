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

# Map<connected_node_name NodeAndCost>!! (caused at least one bug because it wasn't typed :( )
# DO NOT USE DIRECTLY, use provided functions
var _connected_nodes: Dictionary
# All nodes are either entry/exit to a track in a junction, or are ON a track
var track: Track

func get_node_and_cost(name_: String) -> NodeAndCost:
	return _connected_nodes[name_]

# Only get connected nodes on the same trainlines. This only applies to stop nodes
# This allows each train to "see" it's own graph
# Practically, this means that when we construct stops along a track, 
# each train will have it's own directed graph along that track
# and when we're pathfinding, we only see that path(by using this function)
func get_connected_nodes(train_uuid: String) -> Array[NodeAndCost]:
	var result: Array[NodeAndCost] = []
	# Workaround for https://github.com/godotengine/godot/issues/72566
	result.assign(_connected_nodes.values().filter(
		func(node: NodeAndCost) -> bool: 
			if node.virtual_node is StopNode && (node.virtual_node as StopNode).train.name != train_uuid:
				return false
			else:
				return true
			))
	return result

func get_stop_for_train_or_junction(train: Train) -> NodeAndCost:
	var nodes: Array[NodeAndCost] = get_connected_nodes(train.name)
	assert(nodes.size() <= 2, "There should not be more than 2 connected nodes")
	# Prefer the stop node
	for node: NodeAndCost in nodes:
		if node.virtual_node is StopNode && (node.virtual_node as StopNode).train == train:
			return node

	# Go through again and return junction node
	for node: NodeAndCost in nodes:
		if node.virtual_node is JunctionNode:
			return node

	assert(false, "Should never get here")
	return null

func erase_connected_node(name_: String) -> void:
	return _connected_nodes.erase(name_)


func clear() -> void:
	_connected_nodes.clear()
	
func add_connected_node(node: VirtualNode, cost: float) -> void:
	_connected_nodes[node.name] = NodeAndCost.new(node, cost)

func get_point_index() -> int:
	assert(false, "This should be implemented in the subclasses")
	return 0
