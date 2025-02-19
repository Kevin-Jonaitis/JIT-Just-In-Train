extends Node

var deferred_schedule_calls: Array[Callable] = []
var deferred_update_loops_call: Variant = null

var queue_dirty: bool = false


func queue_all_turnaround_loop_calculationos() -> void:
	for train: Train in Utils.get_trains_node().trains:
		queue_calculate_turnaround(train)

func queue_calculate_turnaround(train: Train) -> void:
	Graph.update_turnaround_loops_dirty = true
	queue_dirty = true
	deferred_update_loops_call = func() -> void: Graph.update_turnaround_loops_for_train(train)
	call_deferred("process_queue")
	

# Add/remove/delte track
func network_updated() -> void:
	queue_all_turnaround_loop_calculationos()
	queue_update_schedules()


func queue_update_schedules() -> void:
	for train: Train in Utils.get_trains_node().trains:
		DeferredQueue.queue_update_schedule(train)


func queue_update_schedule(train: Train) -> void:
	queue_dirty = true
	train.update_schedule_dirty = true
	deferred_schedule_calls.append(func() -> void: train.calculate_schedule())
	call_deferred("process_queue")

# This function should be called once per frame, and each individual callable
# should affect it's own state so that it's only called once per frame
# We use dirty bits to do this

# The main reason we have this is so we can control the ORDER in which deferred objects are called.
#specifically, we should always update the turnaround nodes before the schedule
func process_queue() -> void:
	if (queue_dirty):
		queue_dirty = false
	else:
		return

	##  QUEUE ORDERING ##
	if (deferred_update_loops_call != null):
		(deferred_update_loops_call as Callable).call()

	for callable: Callable in deferred_schedule_calls:
		callable.call()


	## CLEAR QUEUE ##
	deferred_schedule_calls.clear()
	deferred_update_loops_call = null
