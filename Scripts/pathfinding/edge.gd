extends RefCounted

# Exists as a value in a Dict on a current node
class_name Edge


static var COST_TO_REVERSE: float = 100
var virtual_node: VirtualNode
# The cost from the node that contains the Edge to this node
var cost: float

# Optional path if there are a couple of nodes to get to this node; this will
# happen for reverse nodes, where they _must_ take this path.
var intermediate_nodes: Array[VirtualNode] = []

func _init(node_: VirtualNode, cost_: float, intermediate_nodes_ : Array[VirtualNode] = []) -> void:
	virtual_node = node_
	cost = cost_
	self.intermediate_nodes = intermediate_nodes_

func is_reverse_edge() -> bool:
	return !intermediate_nodes.is_empty()
