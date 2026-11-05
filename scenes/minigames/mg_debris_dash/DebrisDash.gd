extends MinigameBase

# Minigame 3: Debris Dash
# Zero-Gravity underwater swim navigation through scrolling hazards

const DebrisScene = preload("res://scenes/minigames/mg_debris_dash/SinkingDebris.tscn")

@export var scroll_speed: float = 320.0
@export var debris_interval: float = 1.2
const FINISH_SPAWN_SECONDS_BEFORE_END: float = 3.0

var debris_timer: float = 0.0
var winners_ranking: Array = []
var finish_line_spawned: bool = false

@onready var world_container: Node2D = $WorldContainer
@onready var finish_line_area: Area2D = $WorldContainer/FinishLineArea

func _ready() -> void:
	minigame_title = "Debris Dash"
	minigame_instructions = "ZERO GRAVITY: USE UP, DOWN, LEFT, RIGHT TO SWIM AND DODGE DEBRIS!"
	round_time = 45.0
	super._ready()
	
	if finish_line_area:
		finish_line_area.body_entered.connect(_on_finish_line_reached)
		# Deactivate and park off-screen initially; dynamically spawns 3s before timer runs out
		finish_line_area.visible = false
		finish_line_area.set_deferred("monitoring", false)
		finish_line_area.position.x = 99999.0

func setup_players() -> void:
	super.setup_players()
	# Enable zero gravity 4-directional swimming for all fish in DebrisDash
	for child in get_children():
		if child is FishPlayer:
			child.zero_gravity = true
			child.base_speed = 460.0

func _process(delta: float) -> void:
	if not is_active:
		return
		
	# Scroll world to the left
	world_container.position.x -= scroll_speed * delta
	
	# Manage round timer countdown
	if time_remaining > 0.0:
		time_remaining -= delta
		if timer_label:
			timer_label.text = "%02d" % max(0, int(time_remaining))
	else:
		if timer_label:
			timer_label.text = "00"
			
	# Dynamically spawn finish line 3 seconds before the timer hits 0
	if time_remaining <= FINISH_SPAWN_SECONDS_BEFORE_END and not finish_line_spawned:
		_spawn_finish_line()
		
	# Spawn debris hazards until finish line has arrived
	if not finish_line_spawned:
		debris_timer += delta
		if debris_timer >= debris_interval:
			debris_timer = 0.0
			_spawn_debris_scene()
		
	# Check for fish pushed beyond the left screen boundary (unless already finished)
	for child in get_children():
		if child is FishPlayer and not child.is_dead and child.player_id not in winners_ranking:
			if child.global_position.x < 50.0:
				child.die("Swept away by the rapid current!")

	# Conclude game if the finish line has fully crossed the screen past the left edge
	if finish_line_spawned:
		if finish_line_area and finish_line_area.global_position.x < -100.0:
			finish_minigame()
		elif time_remaining <= -4.0: # Failsafe grace period
			finish_minigame()

func _spawn_finish_line() -> void:
	if finish_line_spawned or not finish_line_area:
		return
	finish_line_spawned = true
	
	# Spawn just past the right screen boundary (1920) so it scrolls into view smoothly
	finish_line_area.position = Vector2(1960.0 - world_container.position.x, 540.0)
	finish_line_area.visible = true
	finish_line_area.set_deferred("monitoring", true)
	
	# Announce final sprint
	if instructions_label:
		instructions_label.text = "🏁 FINAL STRETCH! 🏁"
		instructions_label.visible = true
		get_tree().create_timer(1.8).timeout.connect(func():
			if is_instance_valid(instructions_label) and is_active:
				instructions_label.visible = false
		)

func _spawn_debris_scene() -> void:
	var debris = DebrisScene.instantiate() as SinkingDebris
	var spawn_y = randf_range(160.0, 920.0)
	debris.position = Vector2(2100.0 - world_container.position.x, spawn_y)
	world_container.add_child(debris)

func _on_finish_line_reached(body: Node2D) -> void:
	if body is FishPlayer and body.player_id not in winners_ranking:
		winners_ranking.append(body.player_id)
		body.set_physics_process(false)
		
		# Celebratory glow on the victorious fish
		var tween = create_tween()
		tween.tween_property(body, "modulate", Color(1.3, 1.3, 0.8), 0.15)
		
		if winners_ranking.size() >= surviving_player_ids.size():
			finish_minigame()

func finish_minigame() -> void:
	if not is_active:
		return
	is_active = false
	
	var final_rank = winners_ranking.duplicate()
	for pid in surviving_player_ids:
		if pid not in final_rank:
			final_rank.append(pid)
	eliminated_order.reverse()
	final_rank.append_array(eliminated_order)
	
	GameManager.call_deferred("complete_minigame", final_rank)
