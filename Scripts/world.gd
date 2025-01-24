extends Node2D

@onready var train_schedule_ui: TrainScheduleUI = $UI/Control/TrainScheduleUI
@onready var interactive_mode: InteractiveMode = $MouseTracker/InteractiveMode

func _ready() -> void:
	interactive_mode.train_schedule_ui = train_schedule_ui
	train_schedule_ui.track_intersection_searcher = TrackIntersectionSearcher.new(self)
