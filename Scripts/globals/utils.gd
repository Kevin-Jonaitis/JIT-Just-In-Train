extends Node


# Error difference we use. Angle calculation errors are pretty abismal in Godot
const EPSILON: float = 1e-4


@onready var trains: Trains = get_tree().get_first_node_in_group("trains")

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var uuid_counter: int = 0


# Utility script for generating 
func generate_unique_id() -> String:
	uuid_counter += 1
	return str(uuid_counter)
	# rng.randomize()
	# var bytes: Array[int] = []
	# for i: int in range(16):
	# 	bytes.append(rng.randi_range(0, 255))

	# # Set the version to 4 (0100)
	# bytes[6] = (bytes[6] & 0x0F) | 0x40
	# # Set the variant to RFC 4122 (10xx)
	# bytes[8] = (bytes[8] & 0x3F) | 0x80

	# var hex_str: String = ""
	# for b: int in bytes:
	# 	hex_str += String("%02x" % [b])

	# return hex_str.substr(0, 8) + "-" + hex_str.substr(8, 4) + "-" + hex_str.substr(12, 4) + "-" + hex_str.substr(16, 4) + "-" + hex_str.substr(20, 12)


func normalize_angle_0_to_2_pi(angle: float) -> float:
	var normalized: float = fmod(angle, 2 * PI)
	if normalized < 0:
		normalized += 2 * PI
	return normalized

# Used to place this angle between other angles. Normalizing allows us to compare between angles
func normalize_between_angles(start: float, end: float, angle: float) -> float:
	var normalized: float = angle
	if (start < end):
		while(normalized < start && !check_angle_matches(normalized, start)):
			normalized += TAU
		while(normalized > end && !check_angle_matches(normalized, end)):
			normalized -= TAU
	elif(start > end): # start : 5 end : 0
		while(normalized < end && !check_angle_matches(normalized, end)):
			normalized += TAU
		while(normalized > start && !check_angle_matches(normalized, start)):
			normalized -= TAU	
	else:
		assert(false, "This is weird, we should not be normalizing an angle between two values that are the same")
		return angle
	
	var test_angles_almost_match : bool = check_angle_matches(normalized, start) || check_angle_matches(normalized, end)
	assert(test_angles_almost_match ||  (start < normalized && normalized < end) || (end < normalized && normalized < start), \
	"The angle should be between start and end, getting to this state means there was a bug somewhere")
	
	return normalized

	

# Check if angle matches a within EPSILON.
func check_angle_matches(angle_a: float, angle_b: float) -> bool:
	if abs(angle_difference(angle_a, angle_b)) <= EPSILON:
		return true
	return false

func measure(func_to_measure: Callable, name_: String) -> Variant:
	
	var start_time: float = Time.get_ticks_usec()
	var result: Variant = func_to_measure.call()
	var end_time: float = Time.get_ticks_usec()
	print(name_ + ": " + str((end_time - start_time) / 1000) + " milliseconds")
	return result


func is_equal_approx(a: float, b: float, tolerance: float = EPSILON) -> bool:
	return abs(a - b) < tolerance

func check_value_epsilon(value: float) -> bool:
	if abs(value) <= EPSILON:
		return true
	elif abs(value - PI) <= EPSILON:
		return false
	assert(false, "Value %f is neither close to 0 nor PI" % value)
	return false

func get_all_stops() -> Array[Stop]:
	var stops: Array[Stop] = []
	for train: Train in trains.get_children():
		for stop: Stop in train.get_stops():
			stops.append(stop)
	return stops
	

func get_node_by_ground_name(name: String) -> Variant:
	return get_tree().get_first_node_in_group(name)

func get_trains_node() -> Trains:
	return get_node_by_ground_name("trains")
