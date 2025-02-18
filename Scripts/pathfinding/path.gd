extends RefCounted


class_name Path


var nodes: Array[VirtualNode]  = []
var track_segments: Array[TrackSegment] = []

var uuid: String = Utils.generate_unique_id()

var length: float

var reverse_nodes: Array[VirtualNode] = []

func _init(new_nodes: Array[VirtualNode]) -> void:
	# assert(new_nodes[0] is StopNode, "The first node should always be a stop node")
	#assert(new_nodes[-1] is StopNode, "The last node should always be a stop node")
	self.nodes = new_nodes
	self.length = calculate_length(nodes)
	self.create_track_segments()
	self.reverse_nodes = parse_reverse_nodes()


func parse_reverse_nodes() -> Array[VirtualNode]:
	var reversed_nodes: Array[VirtualNode] = []
	for node: VirtualNode in nodes:
		if (node is StopNode and (node as StopNode).is_reverse_node):
			reversed_nodes.append(node)
	return reversed_nodes


static func calculate_length(nodes_param: Array[VirtualNode]) -> float:
	var length_sum: float = 0
	for i: int in range(1, nodes_param.size()):
		var previous_node: VirtualNode = nodes_param[i - 1]
		var current_node: VirtualNode = nodes_param[i]
		var distance: float = VirtualNode.calculate_distance_between_two_connectable_nodes(previous_node, current_node)
		# var edge: Edge = Edge.new(current_node, distance)
		# assert(edge != null, "We should always have an edge between nodes_param in a path!")
		length_sum += distance
	return length_sum


static func join_seperate_path_arrays(path_one: Path, path_two: Path) -> Path:
	# assert(path_one.nodes[-1].name == path_two.nodes[0].name, "The last stop of the first path and first stop of the second path should be the same")
	path_one.nodes.pop_back()
	return Path.new(path_one.nodes + path_two.nodes)

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

func check_if_track_segment_starts_with_reverse_node(track_segment_index: int) -> bool:
	if (track_segment_index >= track_segments.size()):
		return false
	for node : StopNode in reverse_nodes:
		if (node.track.uuid == track_segments[track_segment_index].track.uuid
		&& Utils.is_equal_approx(node.get_track_position(), track_segments[track_segment_index].start_track_pos)):
			return true
	return false

func update_progress(old_progress: Progress, new_progress_px: float, train: Train) -> Progress:
	var new_progress: Progress = Progress.copy(old_progress)
	var track_segment_index: int = new_progress.track_segment_index
	var previous_track_segment_progress: float = new_progress.track_segment_progress
	var segment: TrackSegment = track_segments[track_segment_index]
	var segment_length: float = segment.get_length()

	while (previous_track_segment_progress + new_progress_px) > segment_length:
		track_segment_index += 1
		if(check_if_track_segment_starts_with_reverse_node(track_segment_index)):
			# When you flip around, the "train" advances by the amount of distance we shifit our
			# cart position
			new_progress_px = new_progress_px + train.cart_length * (train._cars.size() - 1)
			new_progress.reverse()

		new_progress_px = new_progress_px - (segment_length - previous_track_segment_progress)
		previous_track_segment_progress = 0
		
		
		if track_segment_index == track_segments.size():
			# We've reached the end of the path
			# var overshot_path: PathLocation = PathLocation.new()
			# overshot_path.overshoot = new_progress
			new_progress.path_overshoot = new_progress_px
			new_progress.track_segment_progress = 0
			return new_progress
			
		segment = track_segments[track_segment_index]
		segment_length = segment.get_length()
	
	var new_progress_for_track_segment: float = new_progress_px + previous_track_segment_progress

	# var location: PathLocation = PathLocation.new()
	new_progress.position = segment.get_position_at_progress(new_progress_for_track_segment)
	new_progress.track_segment_index = track_segment_index
	new_progress.track_segment_progress = new_progress_for_track_segment
	return new_progress


class TrackSegment:
	var track: Track
	#Distance too this point on the track(not the global vector2 position)
	var start_track_pos: float
	var end_track_pos: float
	var length: float
	var starting_progress: float #TODO: remove, this is redundant
	
	func _init(track_: Track, start_track_pos_: float, end_track_pos_: float) -> void:
		self.track = track_
		self.start_track_pos = start_track_pos_
		self.end_track_pos = end_track_pos_
		self.length = calculate_length()
		self.starting_progress = start_track_pos_

	func get_position_at_progress(progress: float) -> Vector2:
		if (end_track_pos < start_track_pos):
			progress = -progress
		return track.get_point_at_offset(starting_progress + progress)
	
	func calculate_length() -> float:
		return abs(end_track_pos - start_track_pos)

	# TODO: make ABSOLUTE
	func get_length() -> float:
		return length


# Junction to Junction(still on the same track) # care
# Junction to Junction(different tracks) # don't care
# Junction to stop(same track) # care
# stop to junction(same track) # care
# stop to stop(same track)



# Create track segments for each path of travel
# If we are "reversing", we should create two track segments: one from the junction to the reverse point
# And another from the reverse point back to the junction
func create_track_segments() -> void:
	track_segments.clear()
	if nodes.size() < 2:
		return

	var current_track: Track = nodes[0].track
	var start_pos: float = nodes[0].get_track_position()

	for i: int in range(1, nodes.size()):
		var node: VirtualNode = nodes[i]
		if node.track.uuid != current_track.uuid || (is_reverse_spot(nodes[i - 1], node)):
			var end_pos: float = nodes[i - 1].get_track_position()
			var segment: TrackSegment = TrackSegment.new(current_track, start_pos, end_pos)
			track_segments.append(segment)
			current_track = node.track
			start_pos = node.get_track_position()

	# Add the last segment
	var last_end_position: float = nodes[nodes.size() - 1].get_track_position()
	var last_segment: TrackSegment = TrackSegment.new(current_track, start_pos, last_end_position)
	track_segments.append(last_segment)

static func is_reverse_spot(node_one: VirtualNode, node_two: VirtualNode) -> bool:
	if (node_one is StopNode and node_two is StopNode && node_one.track.uuid == node_two.track.uuid &&
	(node_one as StopNode).forward != (node_two as StopNode).forward):
		return true
	return false
