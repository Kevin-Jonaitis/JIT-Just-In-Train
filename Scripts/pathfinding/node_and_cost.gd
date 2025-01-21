extends RefCounted

# Exists as a value in a Dict on a current node
class_name NodeAndCost

var virtual_node: VirtualNode
# The cost from the node that contains the NodeAndCost to this node
var cost: float

func _init(node, cost_):
	virtual_node = node
	cost = cost_
