extends Node3D ## THIS SHOULD NOT BE A NODE. It's just a data countainer, so we should use resource? or refcounted mayBe?
# We need to fix this so we're not drawing on the node
class_name DubinPath3D

var drawableFunctionsToCallLater: Array[Callable] = []
var shortest_path: DubinPath
# Should probably clear this once the shortest path is found
# Maybe can clear it when the user isn't asking to draw all the paths
var paths: Array[DubinPath] = []
# There are 6 possible paths that can be drawn
var drawable_paths: Dictionary[String, Line3D] = {}
const PATH_COLORS: Array[Color] = [Color.PURPLE, Color.AQUA, Color.BLACK, Color.YELLOW, Color.ORANGE, Color.GREEN]
const LINE_WIDTH: float = 0.5
const LINE_Y_INDEX : int = 2
const TOP_LINE_INDEX : int = 7


## Use images here point names and thetas refererd to:
## https://www.habrador.com/tutorials/unity-dubins-paths/2-basic-dubins-paths/

func _ready() -> void:
	for name: String in DubinsPathMath.PATH_TYPES:
		var line: Line3D = Line3D.new()
		line.name = name
		line.width = LINE_WIDTH
		drawable_paths[name] = line
		add_child(line)
	# drawableFunctionsToCallLater = []
	# drawable_paths = []
	# self.paths = []
	# self.shortest_path = null
	pass

func compute_dubin_paths(start_pos: Vector2, start_angle: float, end_pos: Vector2, end_angle: float, min_turn_radius: float) -> Array[DubinPath]:
	if start_pos == end_pos and Utils.check_angle_matches(start_angle,end_angle):
		return []
	return DubinsPathMath.compute_dubins_paths(start_pos, start_angle, end_pos, end_angle, min_turn_radius)

## Maybe should store passed in variables?
func calculate_and_draw_paths(start_pos: Vector2, start_angle: float, end_pos: Vector2, end_angle: float, min_turn_radius: float, draw_paths: bool) -> bool:
	# If the start and end are the same, we don't need to move at all. Short-circuit everything. The shortest
	# path is standing still. If you really want to calculate this path, just draw a circle(in your perferred direction)
	# ending at this point. The below code freaks out because of direction of rotation and floating point precision
	# issues, so gives incosistent results depending on where you start and end. These issues arn't worth figuring out,
	# because even if I did they'd give some arbitrary result that you probably wouldn't want anyways.
	clear_drawables()

	if start_pos == end_pos and Utils.check_angle_matches(start_angle,end_angle):
		return false
	self.paths = DubinsPathMath.compute_dubins_paths(start_pos, start_angle, end_pos, end_angle, min_turn_radius)
	# Technically, we should never return a path size of 0. Dubins paths are always valid.
	# The only time this really happens
	# is if the starting point is also the ending point. Maybe the user wants to draw this
	# a big circle, but they have other ways to do that(split it into 2 half circles). So in this case
	# we're just going to return no path found. We might revisit this later.
	if (paths.size() == 0):
		print("NO PATHS FOUND")
		return false
	self.shortest_path = DubinsPathMath.get_shortest_dubin_path(paths)
	if (draw_paths):
		draw_tangent_circles(start_pos, start_angle, end_pos, end_angle, min_turn_radius)
		draw_dubin_paths()
		draw_path(shortest_path, Color.WHITE, TOP_LINE_INDEX)
		# queue_redraw()
	return true;


func draw_dubin_paths() -> void:
	pass
	# var path_colors: Array[Color] = [Color.PURPLE, Color.AQUA, Color.BLACK, Color.YELLOW, Color.ORANGE, Color.GREEN]
	# var index: int = 0;
	# for path: DubinPath in paths:
	# 	draw_path(path, path_colors[index], index)
	# 	index += 1

func clear_drawables() -> void:
	for line: Line3D in drawable_paths.values():
		line.hide() # Hide rather than clear, it's more performant
		# line.clear()
	# drawableFunctionsToCallLater.clear()
	# queue_redraw()

func draw_path(path: DubinPath, color: Color, y_index: int) -> void:
	if (path.get_points().size() < 2):
		print("WE HAVE TOO SHORT OF A PATH")
	var line: Line3D = drawable_paths[path.name]
	assert(path != null, "We should always have a path based on the name")
	TrackDrawer.set_line_attributes(line, path.get_points(), y_index, color, 1.0)
	line.show()
	# drawableFunctionsToCallLater.append(
	# 			func() -> void: draw_polyline(PackedVector2Array(path.get_points()), color, 3))

# Function to draw two circles based on tangent, radius, and point
func draw_tangent_circles(start_pos: Vector2, start_angle: float, end_pos: Vector2, end_angle: float, radius: float) -> void:

	var circles_start: DubinsPathMath.TangentCircles = DubinsPathMath.get_perpendicular_circle_centers(start_pos, start_angle, radius)
	var circles_end: DubinsPathMath.TangentCircles = DubinsPathMath.get_perpendicular_circle_centers(end_pos, end_angle, radius)

	# Draw the circles
	# drawableFunctionsToCallLater.append(
	# 	func() -> void: draw_circle(circles_start.left.center, radius, Color.RED, false, 2))
	# drawableFunctionsToCallLater.append(
	# 	func() -> void: draw_circle(circles_start.right.center, radius, Color.BLUE, false, 2))
	# drawableFunctionsToCallLater.append(
	# 	func() -> void: draw_circle(circles_end.left.center, radius, Color.RED, false, 2))
	# drawableFunctionsToCallLater.append(
	#	 func() -> void: draw_circle(circles_end.right.center, radius, Color.BLUE, false, 2))

# func _draw() -> void:
# 	for function: Callable in drawableFunctionsToCallLater:
# 		function.call()
# 	drawableFunctionsToCallLater.clear()
