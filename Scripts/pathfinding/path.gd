extends RefCounted


class_name Path


var nodes: Array[VirtualNode]  = []
var track_segments: Array[TrackSegment] = []

var uuid = Utils.generate_uuid()

var start_node
var goal_node

var length: float

func _init(nodes: Array[VirtualNode], length: float):
	self.nodes = nodes
	self.length = length
	self.create_track_segments()

func get_first_stop() -> VirtualNode:
	if nodes.size() == 0:
		assert(false, "How did we get here")
	return nodes[0]

func get_last_stop() -> VirtualNode:
	if nodes.size() == 0:
		assert(false, "How did we get here")
	return nodes[-1]

class TrackSegment:
	var track: Track
	var start_point_index: int
	var end_point_index: int
	
	func _init(track: Track, start_point_index: int, end_point_index: int):
		self.track = track
		self.start_point_index = start_point_index
		self.end_point_index = end_point_index



# Junction to Junction(still on the same track) # care
# Junction to Junction(different tracks) # don't care
# Junction to stop(same track) # care
# stop to junction(same track) # care
# stop to stop(same track)

# write a function in the path class that creates the TrackSegment from nodes.

# Assume as you iterate through the nodes, you will change from one track to another. Only create a TrackSegment for each track that the nodes go over.

# Make sure to set the correct start_index and end_index. These are the index of the points on the track. A junction node will either start at the beginning or end of the track, and a stop node
# will be somewhere in the middle of the track.
func create_track_segments():
	track_segments.clear()
	if nodes.size() < 2:
		return

	var current_track: Track = nodes[0].track
	var start_index: int = nodes[0].get_point_index()

	for i in range(1, nodes.size()):
		var node = nodes[i]
		if node.track != current_track:
			var end_index: int = nodes[i - 1].get_point_index()
			var segment = TrackSegment.new(current_track, start_index, end_index)
			track_segments.append(segment)
			current_track = node.track
			start_index = node.get_point_index()

	# Add the last segment
	var last_end_index: int = nodes[nodes.size() - 1].get_point_index()
	var last_segment = TrackSegment.new(current_track, start_index, last_end_index)
	track_segments.append(last_segment)
