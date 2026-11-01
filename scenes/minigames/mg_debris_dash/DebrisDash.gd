extends MinigameBase

# Minigame 3: Debris Dash
# Zero-Gravity underwater swim navigation through scrolling hazards

const DebrisScene = preload("res://scenes/minigames/mg_debris_dash/SinkingDebris.tscn")

@export var scroll_speed: float = 180.0
@export var debris_interval: float = 1.2

var debris_timer: float = 0.0
var winners_ranking: Array = []

@onready var world_container: Node2D = $WorldContainer
@onready var finish_line_area: Area2D = $WorldContainer/FinishLineArea

func _ready() -> void:
	minigame_title = "Debris Dash"
	minigame_instructions = "ZERO GRAVITY: USE UP, DOWN, LEFT, RIGHT TO SWIM AND DODGE DEBRIS!"
	round_time = 45.0
	super._ready()
	
	if finish_line_area:
		finish_line_area.body_entered.connect(_on_finish_line_reached)

func setup_players() -> void:
	super.setup_players()
	# Enable zero gravity 4-directional swimming for all fish in DebrisDash
	for child in get_children():
		if child is FishPlayer:
			child.zero_gravity = true
			child.base_speed = 460.0

func _process(delta: float) -> void:
	super._process(delta)
	if not is_active:
		return
		
	# Scroll world to the left
	world_container.position.x -= scroll_speed * delta
	
	debris_timer += delta
	if debris_timer >= debris_interval:
		debris_timer = 0.0
		_spawn_debris_scene()
		
	# Check for fish pushed beyond the left screen boundary
	for child in get_children():
		if child is FishPlayer and not child.is_dead:
			if child.global_position.x < 50.0:
				child.die("Swept away by the rapid current!")

func _spawn_debris_scene() -> void:
	var debris = DebrisScene.instantiate() as SinkingDebris
	var spawn_y = randf_range(160.0, 920.0)
	debris.position = Vector2(2100.0 - world_container.position.x, spawn_y)
	world_container.add_child(debris)

func _on_finish_line_reached(body: Node2D) -> void:
	if body is FishPlayer and body.player_id not in winners_ranking:
		winners_ranking.append(body.player_id)
		body.set_physics_process(false)
		
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
