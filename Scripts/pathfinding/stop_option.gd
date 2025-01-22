extends RefCounted

class_name StopOption

var forward_stop: StopNode
var backward_stop: StopNode

func _init(nodes: Array[StopNode]):
	for node in nodes:
		if "forward" in node.name:
			forward_stop = node
		elif "backward" in node.name:
			backward_stop = node
