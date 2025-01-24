extends RefCounted

class_name StopOption

# Should have a forward and backward node
var stop_option: Array[StopNode]

func _init(nodes: Array[StopNode]) -> void:
	assert(nodes.size() == 2, "We should have two nodes")
	self.stop_option = nodes

func get_forward_node() -> StopNode:
	for node: StopNode in stop_option:
		if node.is_forward():
			return node
	assert(false, "We should have a forward node")
	return null

func get_backward_node() -> StopNode:
	for node: StopNode in stop_option:
		if !node.is_forward():
			return node
	assert(false, "We should have a backward node")
	return null
