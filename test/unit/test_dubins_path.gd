extends GutTest

class TestGetAngleAtPoint:
	extends GutTest
	func test_always_left():
		pass
		var start = Vector2(0,0)
		var end = Vector2(0,100)
		var start_angle = 0
		var end_angle = 0

		var paths = DubinsPathMath.compute_dubins_paths(start, start_angle, end, end_angle, 20)
		var shortest_path = DubinsPathMath.get_shortest_dubin_path(paths)
		var num_of_points = shortest_path._points.size()
		
		var angle_end = shortest_path.get_angle_at_point_index(num_of_points - 1)
		assert_true(Utils.check_angle_matches(angle_end, 0))
		
		var angle_start = shortest_path.get_angle_at_point_index(0)
		assert_true(Utils.check_angle_matches(angle_start, 0))
	
	func test_always_down():
		var start = Vector2(0,0)
		var end = Vector2(0,100)
		var start_angle = PI / 2
		var end_angle = PI / 2

		var paths = DubinsPathMath.compute_dubins_paths(start, start_angle, end, end_angle, 20)
		var shortest_path = DubinsPathMath.get_shortest_dubin_path(paths)
		var num_of_points = shortest_path._points.size()
		
		var angle_end = shortest_path.get_angle_at_point_index(num_of_points - 1)
		assert_true(Utils.check_angle_matches(angle_end, PI / 2))
		
		var angle_start = shortest_path.get_angle_at_point_index(0)
		assert_true(Utils.check_angle_matches(angle_start, PI / 2))
		
	func test_middle_value_straight_line():
		var start = Vector2(0,0)
		var end = Vector2(0,100)
		var start_angle = PI / 2
		var end_angle = PI / 2

		var paths = DubinsPathMath.compute_dubins_paths(start, start_angle, end, end_angle, 20)
		var shortest_path = DubinsPathMath.get_shortest_dubin_path(paths)
		var num_of_points = shortest_path._points.size()
		
		var middle = shortest_path.get_angle_at_point_index(num_of_points / 2) #aprox
		assert_almost_eq(middle, PI /2, Utils.EPSILON)
		assert_true(Utils.check_angle_matches(middle, PI / 2))
		

	func test_turn():
		var start = Vector2(0,0)
		var end = Vector2(0,100)
		var start_angle = 0
		var end_angle = PI / 2

		var paths = DubinsPathMath.compute_dubins_paths(start, start_angle, end, end_angle, 20)
		var shortest_path = DubinsPathMath.get_shortest_dubin_path(paths)
		var num_of_points = shortest_path._points.size()
		
		var angle_end = shortest_path.get_angle_at_point_index(num_of_points - 1)
		assert_almost_eq(angle_end, PI /2, Utils.EPSILON)
		assert_true(Utils.check_angle_matches(angle_end, PI / 2))
		
		var angle_start = shortest_path.get_angle_at_point_index(0)
		assert_almost_eq(angle_start, 0.0, Utils.EPSILON)

	# This might be brittle, idk
	func test_s_curve():
		var start = Vector2(0,0)
		var end = Vector2(100,0)
		var start_angle = -PI/2
		var end_angle = PI/2

		var paths = DubinsPathMath.compute_dubins_paths(start, start_angle, end, end_angle, 20)
		var shortest_path = DubinsPathMath.get_shortest_dubin_path(paths)
		var num_of_points = shortest_path._points.size()
		
		var angle_start = shortest_path.get_angle_at_point_index(0)
		var angle_middle = shortest_path.get_angle_at_point_index(num_of_points/2)
		var angle_end = shortest_path.get_angle_at_point_index(num_of_points - 1)
		
		assert_true(Utils.check_angle_matches(angle_start, -PI/2))
		assert_almost_eq(abs(angle_middle), 0.0, Utils.EPSILON)
		assert_true(Utils.check_angle_matches(angle_end, PI/2))

	func test_negative_one_index():
		var start = Vector2(0,0)
		var end = Vector2(100,0)
		var start_angle = 0
		var end_angle = PI/2
		
		var paths = DubinsPathMath.compute_dubins_paths(start, start_angle, end, end_angle, 20)
		var shortest_path = DubinsPathMath.get_shortest_dubin_path(paths)
		var num_of_points = shortest_path._points.size()
		
		var last_point_angle = shortest_path.get_angle_at_point_index(num_of_points - 1)
		var negative_one_angle = shortest_path.get_angle_at_point_index(-1)
		
		assert_almost_eq(last_point_angle, negative_one_angle, Utils.EPSILON)
		assert_true(Utils.check_angle_matches(negative_one_angle, PI/2))
