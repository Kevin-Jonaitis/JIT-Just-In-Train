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

func get_node_and_cost(name: String) -> NodeAndCost:
	return _connected_nodes[name]

# Only get connected nodes on the same trainlines. This only applies to stop nodes
# This allows each train to "see" it's own graph
# Practically, this means that when we construct stops along a track, 
# each train will have it's own directed graph along that track
# and when we're pathfinding, we only see that path(by using this function)
func get_connected_nodes(train: Train) -> Array[NodeAndCost]:
	return _connected_nodes.values().filter(
		func(node): 
			if node.virtual_node is StopNode && node.virtual_node.train.uuid != train.uuid:
				return false
			else:
				return true
			)

	# connected_nodes.values().filter(lambda x: x.virtual_node is StopNode && x.virtual_node.train == filter)

func erase_connected_node(node: VirtualNode):
	return _connected_nodes.erase(node.name)

func clear():
	_connected_nodes.clear()
	
func add_connected_node(node: VirtualNode, cost: float):
	_connected_nodes[node.name] = NodeAndCost.new(node, cost)
