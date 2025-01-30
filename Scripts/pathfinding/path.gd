extends RefCounted


class_name Path


var nodes: Array[VirtualNode]  = []
var track_segments: Array[TrackSegment] = []

var uuid: String = Utils.generate_uuid()
var start_node: VirtualNode
var goal_node: VirtualNode

var length: float

func _init(new_nodes: Array[VirtualNode], new_length: float) -> void:
	assert(new_nodes[0] is StopNode, "The first node should always be a stop node")
	assert(new_nodes[-1] is StopNode, "The last node should always be a stop node")
	self.nodes = new_nodes
	self.length = new_length
	self.create_track_segments()

func get_first_stop() -> VirtualNode:
	if nodes.size() == 0:
		assert(false, "How did we get here")
	return nodes[0]

func get_last_stop() -> VirtualNode:
	if nodes.size() == 0:
		assert(false, "How did we get here")
	return nodes[-1]

class PathLocation:
	var position: Vector2
	var track_segment_index: int
	var track_segment_progress: float
	var overshoot: float

# func get_position_at_progress(progress: float) -> Progress:
# 	var total_length: float = 0
# 	for segment: TrackSegment in track_segments:
# 		var segment_length: float = segment.track.get_length()
# 		if total_length + segment_length >= progress:
# 			var progress_in_segment: float = progress - total_length
# 			var location: Progress = Progress.new()
# 			location.position = segment.track.get_position_at_progress(progress_in_segment)
# 			location.overshoot = 0
# 			return location
# 		total_length += segment_length

# 	assert(false, "We should have found the position by now")
# 	return Progress.new()

func get_new_position(track_segment_index: int, previous_track_segment_progress: float, new_progress: float) -> PathLocation:
	# var total_length: float = 0
	# for i: int in range(0, track_segment_index):
	# 	total_length += track_segments[i].track.get_length()

	var segment: TrackSegment = track_segments[track_segment_index]
	var segment_length: float = segment.get_length()
	while (previous_track_segment_progress + new_progress) > segment_length:
		track_segment_index += 1
		new_progress = new_progress - (segment_length - previous_track_segment_progress)
		previous_track_segment_progress = 0
		
		
		if track_segment_index == track_segments.size():
			# We've reached the end of the path
			var overshot_path: PathLocation = PathLocation.new()
			overshot_path.overshoot = new_progress
			return overshot_path
			
		segment = track_segments[track_segment_index]
		segment_length = segment.get_length()
	
	var new_progress_for_track_segment: float = new_progress + previous_track_segment_progress

	var location: PathLocation = PathLocation.new()
	location.position = segment.get_position_at_progress(new_progress_for_track_segment)
	location.track_segment_index = track_segment_index
	location.track_segment_progress = new_progress_for_track_segment
	return location


class TrackSegment:
	var track: Track
	var start_point_index: int
	var end_point_index: int
	var length: float
	var starting_progress: float
	
	func _init(track_: Track, start_point_index_: int, end_point_index_: int) -> void:
		self.track = track_
		self.start_point_index = start_point_index_
		self.end_point_index = end_point_index_
		self.length = calculate_length()
		self.starting_progress = track.get_distance_to_point(start_point_index)

	func get_position_at_progress(progress: float) -> Vector2:
		if (end_point_index < start_point_index):
			progress = -progress
		return track.get_point_at_offset(starting_progress + progress)
	
	func calculate_length() -> float:
		var start_point: float = track.get_distance_to_point(start_point_index)
		var end_point: float = track.get_distance_to_point(end_point_index)
		return abs(end_point - start_point)

	# TODO: make ABSOLUTE
	func get_length() -> float:
		return length


# Junction to Junction(still on the same track) # care
# Junction to Junction(different tracks) # don't care
# Junction to stop(same track) # care
# stop to junction(same track) # care
# stop to stop(same track)

# write a function in the path class that creates the TrackSegment from nodes.

# Assume as you iterate through the nodes, you will change from one track to another. Only create a TrackSegment for each track that the nodes go over.

# Make sure to set the correct start_index and end_index. These are the index of the points on the track. A junction node will either start at the beginning or end of the track, and a stop node
# will be somewhere in the middle of the track.
func create_track_segments() -> void:
	track_segments.clear()
	if nodes.size() < 2:
		return

	var current_track: Track = nodes[0].track
	var start_index: int = (nodes[0] as StopNode).get_point_index()

	for i: int in range(1, nodes.size()):
		var node: VirtualNode = nodes[i]
		if node.track != current_track:
			var end_index: int = nodes[i - 1].get_point_index()
			var segment: TrackSegment = TrackSegment.new(current_track, start_index, end_index)
			track_segments.append(segment)
			current_track = node.track
			start_index = node.get_point_index()

	# Add the last segment
	var last_end_index: int = nodes[nodes.size() - 1].get_point_index()
	var last_segment: TrackSegment = TrackSegment.new(current_track, start_index, last_end_index)
	track_segments.append(last_segment)
