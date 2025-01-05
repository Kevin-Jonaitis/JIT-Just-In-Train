extends Resource

#TODO:
	
# find the smallest viable path type
# size it up until it gets to the next path type, or until it's 4x the distance between the points, whatever comes first?

## We store points for drawing, but we use formulas to determine the position along the curve
## Because of this, arcs will have many points, while the straight line segments will only have 2(start and end)
class_name DubinPath

var name: String
var length: float
var segments: Array
## Points to draw the path. Note that they are evenly spaced on
## arcs, but there are only 2 points for straight lines. So this should be used
## in drawing functions only, not for progress capture. To get progress, use
## get_point_at_offset

# Define a small epsilon value for tolerance
# Vector2.angle() uses (I believe) floats, while atan2() uses doubles percison
# to account for this, don't be very percise when looking at total length for a segment
const EPSILON = 1e-4
var calcualtedPoints = false
var _points: Array = []

# Variables copied from curve2D
var bake_interval: float

func _init(name_: String, _segments: Array, bake_interval_: float = 5):
	self.name = name_
	self.bake_interval = bake_interval_
	self.segments = filter_segments(_segments)

func get_points():
	if (!calcualtedPoints):
		calcualtedPoints = true
		calculate_points()
	return _points
	

func calculate_points():
	for segment in segments:
			length += segment.length
			if segment is Line:
				add_point_if_unique(segment.start)
				add_point_if_unique(segment.end)
			elif segment is Arc:
				# Optimization: only calculate points on arc for shortest path(up to 6x faster)
				var newPoints = segment.calculate_points_on_arc(bake_interval)
				for point in newPoints:
					add_point_if_unique(point)

## Prevents two of the same point from being added to the 
## points array. This can happen on the boundary of two segments
func add_point_if_unique(point: Vector2) -> void:
	if _points.is_empty() or not _points[-1].is_equal_approx(point):
		_points.append(point)


## Filter out segments that don't have any length; this pretty much only
## happens when it's a straight line
# Filter out segments that are of 0 length, or if after filtering there are no
# valid segments left, return null
func filter_segments(_segments : Array) -> Array:

	var filtered_segments = []
	for segment in _segments:
		if segment.length > EPSILON:
			filtered_segments.append(segment)
	return filtered_segments


# Given an offset(in pixels), return the coordinates on the path at that offset
func get_point_at_offset(offset: float) -> Vector2:
	if offset <= 0:
		return _points[0]
	if offset >= length:
		return _points[-1]
		
	var current_length = 0
	for segment in segments:
		if current_length + segment.length >= offset:
			var segment_offset = offset - current_length
			if segment is Line:
				return segment.get_point_at_offset(segment_offset)
			elif segment is Arc:
				return segment.get_point_at_offset(segment_offset)
		current_length += segment.length
	
	return _points[-1]

class Line:
	var start: Vector2
	var end: Vector2
	var length: float
	var points: PackedVector2Array = []

	func _init(_start: Vector2, _end: Vector2):
		self.start = _start
		self.end = _end
		self.length = (_end - _start).length()
		points.append(start)
		points.append(end)


	func get_point_at_offset(offset: float) -> Vector2:
		var t = offset / length
		return start.lerp(end, t)

# All the data needed to construct an arc
## We should draw the arc from start_angle towards the value of end_angle in a 
## clockwise direction if start_angle < end_angle and counter-clockwise otherwise.
class Arc:
	var center: Vector2
	var start_theta: float
	var end_theta: float
	var radius: float
	var length: float
	var points: PackedVector2Array

	func _init(_center: Vector2, _start_theta: float, _end_theta: float, _radius: float):
		self.center = _center
		self.start_theta = _start_theta
		self.end_theta = _end_theta
		self.radius = _radius
		var thetaDifference = _end_theta - _start_theta
		self.length = abs(_radius * thetaDifference)
		# self.points = calculate_points_on_arc()
		pass
			
	func calculate_points_on_arc(bake_interval: int = 5):
		var temp_points: PackedVector2Array
		var num_of_points = max(2, ceil(length / bake_interval)) #always have at least 2 points on the arc
		var total_theta = end_theta - start_theta
		var theta_slice = total_theta / (num_of_points - 1) # Adjust to ensure the last point is included
		for i in range(num_of_points):
			var point_theta = start_theta + theta_slice * i
			var arc_point = center + Vector2(radius * cos(point_theta), radius * sin(point_theta))
			temp_points.append(arc_point)
		return temp_points

	# Given an offset(in pixels), return the point on the arc
	func get_point_at_offset(offset: float) -> Vector2:
		var t = offset / length
		var theta
		if start_theta < end_theta:
			# Clockwise traversal
			theta = start_theta + (end_theta - start_theta) * t
		else:
			# Counterclockwise traversal
			theta = start_theta - (start_theta - end_theta) * t
		return center + Vector2(radius * cos(theta), radius * sin(theta))
