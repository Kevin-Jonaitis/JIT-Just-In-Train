extends RefCounted


class_name Path


var nodes: Array[VirtualNode]  = []
var tracks: Array[Track] = []

var start_node
var goal_node

var length: float

# func _init(p_nodes: Array[VirtualNode], p_tracks: Array[Track]):
# 	nodes = p_nodes
# 	tracks = p_tracks
# 	start_node = nodes[0]
# 	goal_node = nodes[nodes.size() - 1]
