extends Node3D


@onready var train_schedule_ui: TrainScheduleUI = $UI/Control/TrainScheduleUI
@onready var interactive_mode: InteractiveMode = $MouseTracker3D/InteractiveMode

func _ready() -> void:
	interactive_mode.train_schedule_ui = train_schedule_ui
	train_schedule_ui.track_intersection_searcher = TrackIntersectionSearcher3D.new(self)
