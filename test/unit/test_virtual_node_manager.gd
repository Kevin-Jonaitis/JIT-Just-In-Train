#extends GutTest
#
#class TestVirtualNodeManager:
	#extends GutTest
#
	#func test_delete_interjunction_virtual_nodes():
		#var dummy_track = Track.new()
		#var manager = VirtualNodeManager.new(dummy_track)
		## ...existing code...
		#manager.setup_interjunction_virtual_nodes()
		#manager.delete_interjunction_virtual_nodes()
		## Assert that junction references are removed, etc.
		#assert_eq(dummy_track.start_junction.virtual_nodes.size(), 0)
		#assert_eq(dummy_track.end_junction.virtual_nodes.size(), 0)
		#assert_true(true)  # Ensure Gut sees an assertion
		#dummy_track.queue_free()
#
	#func test_compare_forward():
		#var track = Track.new()
		#var node1 = StopNode.new(track, 2, true, Train.new())
		#var node2 = StopNode.new(track, 5, true, Train.new())
		#var start = JunctionNode.new(null, track, true, true)
		#node1.point_index = 2
		#node2.point_index = 5
		#var manager = VirtualNodeManager.new(track)
		#assert_true(manager.compare_forward(node1, node2, start, node2), "Should be forward")
		#track.queue_free()
#
	#func test_compare_backward():
		#var track = Track.new()
		#var node1 = StopNode.new(track, 7, false, Train.new())
		#var node2 = StopNode.new(track, 2, false, Train.new())
		#var start = JunctionNode.new(null, track, false, false)
		#node1.point_index = 7
		#node2.point_index = 2
		#var manager = VirtualNodeManager.new(track)
		#assert_true(manager.compare_backward(node1, node2, start, node2), "Should be backward")
		#track.queue_free()
#
	#func test_insert_stop_between_nodes():
		#var track = Track.new()
		#var node1 = JunctionNode.new(null, track, true, true)
		#var node2 = JunctionNode.new(null, track, false, false)
		#var stop = StopNode.new(track, 3, true, Train.new())
		#node1.track = track
		#node2.track = node1.track
		#stop.track = node1.track
		#var manager = VirtualNodeManager.new(track)
		#manager.insert_stop_between_nodes(node1, node2, stop)
		#assert_true(node1._connected_nodes.has(stop.name))
		#assert_true(stop._connected_nodes.has(node2.name))
		#track.queue_free()
#
	#func test_remove_stop_after_this_node():
		#var node_before = JunctionNode.new(null, Track.new(), true, true)
		#var train = Train.new()
		#var stop = StopNode.new(node_before.track, 5, true, train)
		#node_before.track = Track.new()
		#stop.track = node_before.track
		#node_before.add_connected_node(stop, 10.0)
		#
		## Provide a next node so remove_stop_after_this_node can link around
		#var node_after = JunctionNode.new(null, node_before.track, true, true)
		#stop.add_connected_node(node_after, 5.0)
#
		#var manager = VirtualNodeManager.new(node_before.track)
		#manager.remove_stop_after_this_node(node_before, train)
		#assert_false(node_before._connected_nodes.has(stop.name))
		#node_before.track.queue_free()
#
	#func test_cost_between_nodes():
		#var track = Track.new()
		#var stop1 = StopNode.new(track, 2, true, Train.new())
		#var stop2 = StopNode.new(track, 5, true, Train.new())
		#stop1.point_index = 2
		#stop2.point_index = 5
		#var manager = VirtualNodeManager.new(track)
		#var cost = manager.cost_between_nodes(stop1, stop2)
		#assert_eq(cost, abs(track.get_distance_to_point(5) - track.get_distance_to_point(2)))
		#track.queue_free()
