extends RefCounted

class_name StopOption

var forward_stop: VirtualNode
var backward_stop: VirtualNode

func _init(nodes: Array[VirtualNode]):
	for node in nodes:
		if "forward" in node.name:
			forward_stop = node
		elif "backward" in node.name:
			backward_stop = node
