extends RefCounted

# Exists as a value in a Dict on a current node
class_name Edge


static var COST_TO_REVERSE: float = 100
var to_node: VirtualNode
# The cost from the node that contains the Edge to this node
var cost: float

# Optional path if there are a couple of nodes to get to this node; this will
var intermediate_nodes: Array[VirtualNode] = []
var intermediate_nodes_train: Train = null
# happen for reverse nodes, where they _must_ take this path.

var name: String


func _init(node_: VirtualNode, cost_: float, intermediate_nodes_ : Array[VirtualNode] = [], intermediate_nodes_train_: Train = null) -> void:
	to_node = node_
	cost = cost_
	self.intermediate_nodes = intermediate_nodes_
	self.intermediate_nodes_train = intermediate_nodes_train_
	self.name = Utils.generate_unique_id() # TODO: update with incoming edge name

func is_reverse_edge() -> bool:
	return !intermediate_nodes.is_empty()

# Generate the name from the start and end nodes
