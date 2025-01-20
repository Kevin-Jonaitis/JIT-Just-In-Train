extends RefCounted

class_name NodeAndCost

var virtual_node: VirtualNode
var cost: float

func _init(node, cost_):
	virtual_node = node
	cost = cost_
