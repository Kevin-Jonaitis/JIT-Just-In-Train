extends Object
class_name BezierCurveMath

const MIN_RADIUS: String = "min_radius"
const POINTS: String = "points"
const CURVATURES: String = "curvatures"

static func find_best_curve(
	trackStartingPosition: Vector2, 
	trackStartingControlPoint: Vector2, 
	trackEndingPosition: Vector2, 
	trackEndingControlPoint: Vector2, 
	minAllowedRadius: float, 
	track_mode_flag: bool
) -> Dictionary:
	var max_tangent_multiplier: float = 2.0
	var startControlPoint: Vector2
	var endControlPoint: Vector2

	var lineLength: float = trackStartingPosition.distance_to(trackEndingPosition)
	var numOfTangentsToCheck: int = 20  # SETTING THIS TO 100 makes the framerate shit the bed. we could move this code to C# to improve it by maybe 5-10x

	var best_tangent_size: float = INF
	var best_radius: float = -INF

	for i: int in range(numOfTangentsToCheck):
		var tangentLength: float = (MapManager.cellSize * 1) + ((i / float(numOfTangentsToCheck - 1)) * (max_tangent_multiplier * (lineLength - (MapManager.cellSize * 1))))
		startControlPoint = trackStartingPosition + (tangentLength * trackStartingControlPoint)
		endControlPoint = trackEndingPosition + (tangentLength * trackEndingControlPoint)
		
		var curve_data: Dictionary = calculate_curve_data(trackStartingPosition, startControlPoint, endControlPoint, trackEndingPosition)

		var min_radius: float = curve_data[MIN_RADIUS]
		var has_intersection: bool = self_intersects(trackStartingPosition, startControlPoint, endControlPoint, trackEndingPosition)

		if (min_radius > best_radius and min_radius > minAllowedRadius and not has_intersection):
			best_tangent_size = tangentLength
			best_radius = min_radius
			if (track_mode_flag):
				break  # don't find the minimum radius, just quit early once we found a

	var validTrack: bool
	if (best_radius == -INF):
		validTrack = false
	else:
		validTrack = true

	return {
		"validTrack": validTrack,
		"start_position": trackStartingPosition,
		"end_position": trackEndingPosition,
		"start_control_point": best_tangent_size * trackStartingControlPoint,
		"end_control_point": best_tangent_size * trackEndingControlPoint
	}

static func bezier_length(
	P0: Vector2, 
	P1: Vector2, 
	P2: Vector2, 
	P3: Vector2, 
	num_samples: int = 100
) -> float:
	var length: float = 0.0
	var previous_point: Vector2 = P0  # Start at the first control point

	for i: int in range(1, num_samples + 1):
		var t: float = i / float(num_samples)
		var current_point: Vector2 = (1 - t)**3 * P0 + 3 * (1 - t)**2 * t * P1 + 3 * (1 - t) * t**2 * P2 + t**3 * P3
		length += previous_point.distance_to(current_point)
		previous_point = current_point

	return length

static func calculate_curve_data(
	P0: Vector2, 
	P1: Vector2, 
	P2: Vector2, 
	P3: Vector2, 
	bake_interval: float = 5.0
) -> Dictionary:
	var length: float = bezier_length(P0, P1, P2, P3)

	var num_of_baked_points: float = length / bake_interval
	var curvatures: Array[float] = []
	var t_values: Array[float] = []
	var points: Array[Vector2] = []

	for i: int in range(int(num_of_baked_points)):
		t_values.append(float(i) / float(num_of_baked_points - 1.0))

	t_values.append(1.0)  # always make sure we have the last value

	for t: float in t_values:
		# Calculate the point on the curve
		var point: Vector2 = (1 - t)**3 * P0 + 3 * (1 - t)**2 * t * P1 + 3 * (1 - t) * t**2 * P2 + t**3 * P3
		points.append(point)

		# First derivatives
		var dx_dt: float = 3 * (1 - t)**2 * (P1.x - P0.x) + 6 * (1 - t) * t * (P2.x - P1.x) + 3 * t**2 * (P3.x - P2.x)
		var dy_dt: float = 3 * (1 - t)**2 * (P1.y - P0.y) + 6 * (1 - t) * t * (P2.y - P1.y) + 3 * t**2 * (P3.y - P2.y)

		# Second derivatives
		var d2x_dt2: float = 6 * (1 - t) * (P2.x - 2 * P1.x + P0.x) + 6 * t * (P3.x - 2 * P2.x + P1.x)
		var d2y_dt2: float = 6 * (1 - t) * (P2.y - 2 * P1.y + P0.y) + 6 * t * (P3.y - 2 * P2.y + P1.y)

		# Curvature formula
		var numerator: float = absf(dx_dt * d2y_dt2 - dy_dt * d2x_dt2)
		var denominator: float = pow(dx_dt**2 + dy_dt**2, 1.5)

		if denominator == 0.0:
			curvatures.append(0.0)  # Avoid division by zero
		else:
			curvatures.append(numerator / denominator)

	var radiuses: Array[float] = []
	for curve: float in curvatures:
		radiuses.append(1.0 / curve)

	var min_radius: float = INF
	for radius: float in radiuses:
		if radius < min_radius:
			min_radius = radius

	return {
		MIN_RADIUS: min_radius,
		POINTS: points,
		CURVATURES: curvatures
	}

static func self_intersects(P0: Vector2, P1: Vector2, P2: Vector2, P3: Vector2) -> bool:
	return find_self_intersection(P0, P1, P2, P3).size() > 0

static func find_self_intersection(P0: Vector2, P1: Vector2, P2: Vector2, P3: Vector2) -> Array[float]:
	# if the start and end point are the same, return that it's intersectioning
	if (P0 == P3):
		return [0.0, 1.0]

	if is_straight_line(P0, P1, P2, P3):
		if control_points_outside_segment(P0, P1, P2, P3):
			# Straight line with control points outside the main segment is degenerate
			return [0.0, 1.0]  # Treat as "self-intersecting" in this degenerate case
		else:
			return []  # Straight line without degenerate self-intersection
	# Step 1: Compute the vectors
	var vx: Vector2 = P2 - P1
	var vy: Vector2 = P1 - P0
	var vz: Vector2 = P3 - P0

	# Step 2: Solve the system of linear equations
	var determinant: float = vx.x * vy.y - vx.y * vy.x
	if determinant == 0.0:  # Handle degenerate case
		return []

	# Compute the solution for x and y
	var x: float = (vz.x * vy.y - vz.y * vy.x) / determinant
	var y: float = (vx.x * vz.y - vx.y * vz.x) / determinant

	# Step 3: Check constraints
	if x > 1.0 or \
		4.0 * y > (x + 1.0) * (3.0 - x) or \
		(x > 0.0 and 2.0 * y + x < sqrt(3.0 * x * (4.0 - x))) or \
		3.0 * y < x * (3.0 - x):
		return []

	# Step 4: Compute `λ + μ` and `λ * μ`
	var rs: float = (x - 3.0) / (x + y - 3.0)
	var rp: float = rs * rs + 3.0 / (x + y - 3.0)

	# Step 5: Solve the quadratic equation for λ and μ
	var discriminant: float = rs * rs - 4.0 * rp
	if discriminant < 0.0:
		return []

	var sqrt_discriminant: float = sqrt(discriminant)
	var lambda1: float = (rs - sqrt_discriminant) / 2.0
	var lambda2: float = (rs + sqrt_discriminant) / 2.0

	# Return sorted solutions
	return [min(lambda1, lambda2), max(lambda1, lambda2)]

static func is_straight_line(P0: Vector2, P1: Vector2, P2: Vector2, P3: Vector2) -> bool:
	var v0: Vector2 = P1 - P0
	var v1: Vector2 = P2 - P1
	var v2: Vector2 = P3 - P2
	return absf(v0.cross(v1)) < 0.0001 and absf(v1.cross(v2)) < 0.0001

static func control_points_outside_segment(P0: Vector2, P1: Vector2, P2: Vector2, P3: Vector2) -> bool:
	var main_direction: Vector2 = (P3 - P0).normalized()
	var proj_P1: float = main_direction.dot(P1 - P0) / main_direction.length()
	var proj_P2: float = main_direction.dot(P2 - P0) / main_direction.length()

	return proj_P1 < 0.0 or proj_P1 > (P3 - P0).length() or proj_P2 < 0.0 or proj_P2 > (P3 - P0).length()
