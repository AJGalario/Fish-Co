class_name FishPlayer
extends CharacterBody2D

@export var player_id: int = 0
@export var peer_id: int = 1
@export var base_speed: float = 400.0
@export var jump_impulse: float = -550.0

# Movement Mode Flags
@export var can_air_jump: bool = false
@export var zero_gravity: bool = false # Free 8-directional swimming (DebrisDash)

var is_dead: bool = false
var is_alive: bool:
	get:
		return not is_dead
	set(val):
		is_dead = not val

var input_prefix: String = "p1_"

# Bot AI Properties
var is_bot: bool = false
var bot_difficulty: PlayerData.BotDifficulty = PlayerData.BotDifficulty.MEDIUM
var bot_timer: float = 0.0
var bot_target_x: float = 0.0
var bot_target_y: float = 0.0

# Slap & Stun Mechanics (osu!catch pellet minigame)
var is_stunned: bool = false
var stun_timer: float = 0.0
var slap_cooldown: float = 0.0

@onready var fish_sprite: Sprite2D = $Visuals/FishSprite
@onready var oxygen_bar: ProgressBar = $OxygenBar
@onready var player_name_label: Label = $NameLabel
@onready var slap_hitbox: Area2D = $Visuals/SlapHitbox

# Sprite Sheet Frame offsets for different fish species/slots
const SKIN_ROW_OFFSETS: Array[int] = [0, 16, 32, 48]

func _ready() -> void:
	input_prefix = "p%d_" % (player_id + 1)
	
	var pd = GameManager.get_player_data(player_id)
	if pd:
		is_bot = pd.is_bot
		bot_difficulty = pd.bot_difficulty
	
	_apply_styling()
	
	if oxygen_bar:
		oxygen_bar.visible = false
	
	if slap_hitbox:
		slap_hitbox.body_entered.connect(_on_slap_hitbox_entered)
		slap_hitbox.monitoring = false

func _apply_styling() -> void:
	var colors = PlayerData.PLAYER_COLORS
	var col = colors[player_id % colors.size()]
	
	if fish_sprite:
		var row_start = SKIN_ROW_OFFSETS[player_id % SKIN_ROW_OFFSETS.size()]
		fish_sprite.frame = row_start
		fish_sprite.modulate = col.lerp(Color.WHITE, 0.45)
		
	if player_name_label:
		var pd = GameManager.get_player_data(player_id)
		if pd and pd.is_bot:
			player_name_label.text = "[BOT] P%d" % (player_id + 1)
		else:
			player_name_label.text = "P%d" % (player_id + 1)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	# Handle Stun recovery (pellet minigame slap)
	if is_stunned:
		stun_timer -= delta
		if fish_sprite:
			fish_sprite.modulate = Color(0.4, 0.4, 0.4, 0.7)
		if stun_timer <= 0.0:
			is_stunned = false
			_apply_styling()
		velocity = lerp(velocity, Vector2.ZERO, 0.2)
		move_and_slide()
		return
	
	if slap_cooldown > 0.0:
		slap_cooldown -= delta
	
	if is_bot:
		_process_bot_ai(delta)
	else:
		var pd = GameManager.get_player_data(player_id)
		var has_control = true
		if multiplayer.has_multiplayer_peer() and pd:
			has_control = (pd.peer_id == multiplayer.get_unique_id())
		
		if has_control:
			_process_input_and_movement(delta)
	
	move_and_slide()

func _process_input_and_movement(delta: float) -> void:
	if zero_gravity:
		_process_zero_gravity_swim(delta)
		return

	# Standard platforming gravity
	velocity.y += 980.0 * delta
	
	# Horizontal Movement
	var move_x = Input.get_axis(input_prefix + "left", input_prefix + "right")
	var target_vel_x = move_x * base_speed
	velocity.x = lerp(velocity.x, target_vel_x, 0.25)
	
	# Jump / Flap Input check
	var jump_pressed = Input.is_action_just_pressed(input_prefix + "jump") or Input.is_action_just_pressed(input_prefix + "action")
	if player_id == 0 and not jump_pressed:
		jump_pressed = Input.is_key_pressed(KEY_SPACE) and Input.is_action_just_pressed("p1_action")
	
	if jump_pressed:
		if can_air_jump or is_on_floor() or is_on_ceiling():
			velocity.y = jump_impulse
			
	# Slap Action
	if not can_air_jump:
		var slap_action = input_prefix + "action"
		if Input.is_action_just_pressed(slap_action) and slap_cooldown <= 0.0:
			perform_tail_slap()
	
	# Visual orientation & swimming animation
	if move_x != 0.0:
		$Visuals.scale.x = 1.0 if move_x > 0 else -1.0
		if fish_sprite:
			var base_frame = SKIN_ROW_OFFSETS[player_id % SKIN_ROW_OFFSETS.size()]
			var anim_frame = int(Time.get_ticks_msec() / 150) % 4
			fish_sprite.frame = base_frame + anim_frame

func _process_zero_gravity_swim(delta: float) -> void:
	# 4-Directional smooth swimming: Up, Down, Left, Right
	var move_x = Input.get_axis(input_prefix + "left", input_prefix + "right")
	var move_y = Input.get_axis(input_prefix + "up", input_prefix + "down")
	
	var dir = Vector2(move_x, move_y)
	if dir.length() > 1.0:
		dir = dir.normalized()
		
	var target_vel = dir * base_speed
	velocity = lerp(velocity, target_vel, 0.2)
	
	# Visual orientation & swimming animation
	if move_x != 0.0:
		$Visuals.scale.x = 1.0 if move_x > 0 else -1.0
	if dir.length() > 0.1:
		if fish_sprite:
			var base_frame = SKIN_ROW_OFFSETS[player_id % SKIN_ROW_OFFSETS.size()]
			var anim_frame = int(Time.get_ticks_msec() / 140) % 4
			fish_sprite.frame = base_frame + anim_frame

func _process_bot_ai(delta: float) -> void:
	if zero_gravity:
		# Free 2D navigation bot AI (dodging debris)
		bot_timer += delta
		if bot_timer >= 0.35:
			bot_timer = 0.0
			bot_target_x = randf_range(0.2, 0.8) # Tend to swim forward
			bot_target_y = randf_range(-0.9, 0.9)
			
		var speed_mult = 0.7 if bot_difficulty == PlayerData.BotDifficulty.EASY else (1.0 if bot_difficulty == PlayerData.BotDifficulty.MEDIUM else 1.25)
		velocity = lerp(velocity, Vector2(bot_target_x, bot_target_y) * base_speed * speed_mult, 0.15)
		
		if velocity.x != 0.0:
			$Visuals.scale.x = 1.0 if velocity.x > 0 else -1.0
		return

	velocity.y += 980.0 * delta
	bot_timer += delta
	
	# Flappy game bot logic
	if can_air_jump:
		var flap_interval = 0.45
		if bot_difficulty == PlayerData.BotDifficulty.HARD:
			flap_interval = 0.38
		elif bot_difficulty == PlayerData.BotDifficulty.EASY:
			flap_interval = 0.55
			
		if position.y > 600.0 or (bot_timer >= flap_interval and position.y > 320.0):
			bot_timer = 0.0
			velocity.y = jump_impulse
		return
	
	# General horizontal roaming / pellet chasing bot AI
	if bot_timer >= 0.5:
		bot_timer = 0.0
		bot_target_x = randf_range(-1.0, 1.0)
		if is_on_floor() and randf() > 0.6:
			velocity.y = jump_impulse
		if slap_cooldown <= 0.0 and randf() > 0.7:
			perform_tail_slap()
			
	var speed_multiplier = 0.7 if bot_difficulty == PlayerData.BotDifficulty.EASY else (1.0 if bot_difficulty == PlayerData.BotDifficulty.MEDIUM else 1.25)
	velocity.x = lerp(velocity.x, bot_target_x * base_speed * speed_multiplier, 0.2)
	
	if velocity.x != 0.0:
		$Visuals.scale.x = 1.0 if velocity.x > 0 else -1.0
		if fish_sprite:
			var base_frame = SKIN_ROW_OFFSETS[player_id % SKIN_ROW_OFFSETS.size()]
			var anim_frame = int(Time.get_ticks_msec() / 150) % 4
			fish_sprite.frame = base_frame + anim_frame

func perform_tail_slap() -> void:
	slap_cooldown = 0.8
	if slap_hitbox:
		slap_hitbox.monitoring = true
		var tween = create_tween()
		tween.tween_property($Visuals, "scale:x", $Visuals.scale.x * 1.4, 0.1)
		tween.tween_property($Visuals, "scale:x", $Visuals.scale.x, 0.1)
		await get_tree().create_timer(0.2).timeout
		if slap_hitbox:
			slap_hitbox.monitoring = false

func _on_slap_hitbox_entered(body: Node2D) -> void:
	if body is FishPlayer and body != self:
		body.apply_stun(1.5)

func apply_stun(duration: float = 1.5) -> void:
	is_stunned = true
	stun_timer = duration
	velocity = Vector2(0, -200)

func die(reason: String = "") -> void:
	if is_dead:
		return
	is_dead = true
	EventBus.player_died.emit(player_id)
	visible = false
	set_physics_process(false)
