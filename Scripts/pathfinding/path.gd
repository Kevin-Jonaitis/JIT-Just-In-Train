extends RefCounted


class_name Path

func _init(nodes: Array[VirtualNode], length: float):
	self.nodes = nodes
	self.length = length
	self.create_track_segments()
	

class TrackSegment:
	var track: Track
	var start_point_index: int
	var end_point_index: int
	
	func _init(track: Track, start_point_index: int, end_point_index: int):
		self.track = track
		self.start_point_index = start_point_index
		self.end_point_index = end_point_index


var nodes: Array[VirtualNode]  = []
var track_segments: Array[TrackSegment] = []

var start_node
var goal_node

var length: float

# Junction to Junction(still on the same track) # care
# Junction to Junction(different tracks) # don't care
# Junction to stop(same track) # care
# stop to junction(same track) # care
# stop to stop(same track)

#write a function in the path class that creates the track_segments from nodes. Note that there are 5 pairs of nodes that can occur in the nodes array:
#Junction to Junction(still on the same track) Junction to Junction(different tracks) Junction to stop(same track) stop to junction(same track) stop to stop(same track)
#keep track of the current track for the node. as you iterate over nodes, as soon as track changes, complete a segment for that track, starting at whatever the point index was for the first node on that track and ending on the current index for that track. add that track to the list of track segments.
func create_track_segments():
	track_segments.clear()
	var current_track = null
	var start_index = -1
	
	for i in range(nodes.size()):
		var node = nodes[i]
		if node.track.uuid != current_track.uuid:
			# close out previous segment
			if current_track != null and start_index != -1:
				var end_index = nodes[i - 1].virtual_node.get_point_index()
				var segment = TrackSegment.new(current_track, start_index, end_index)
				track_segments.append(segment)
			# start a new segment
			current_track = node.track
			start_index = node.virtual_node.get_point_index()

		# if we're at the last node, close out the segment
		if i == nodes.size() - 1:
			var segment = TrackSegment.new(current_track, start_index, node.virtual_node.get_point_index())
			track_segments.append(segment)
