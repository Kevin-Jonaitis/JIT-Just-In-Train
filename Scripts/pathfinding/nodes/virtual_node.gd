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

# Map<connected_node_name NodeAndCost>
var connected_nodes: Dictionary
# All nodes are either entry/exit to a track in a junction, or are ON a track
var track: Track

func erase_connected_node(node: VirtualNode):
	return connected_nodes.erase(node.name)
	
func add_connected_node(node: VirtualNode, cost: float):
	connected_nodes[node.name] = NodeAndCost.new(node, cost)