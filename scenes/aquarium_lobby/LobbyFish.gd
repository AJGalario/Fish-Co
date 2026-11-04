class_name LobbyFish
extends CharacterBody2D

## ─────────────────────────────────────────────────────────────
##  LobbyFish — per-player fish shown in the Aquarium Lobby.
##
##  HUMAN players:  Move freely in all 6 directions so they can
##                  identify themselves ("Move to claim!").
##  BOT players:    Wander autonomously in 6 directions, bouncing
##                  gently around their home column zone.
##
##  No gravity — this is a pure aquarium free-swim environment.
## ─────────────────────────────────────────────────────────────

# ── Identity ──────────────────────────────────────────────────
var player_id    : int    = 0
var is_bot       : bool   = false
var player_name  : String = "Fish"
var player_color : Color  = Color.WHITE

# ── Movement ──────────────────────────────────────────────────
const HUMAN_SPEED  : float = 320.0
const BOT_SPEED    : float = 90.0

# Tank bounds (screen-space; will be set by the lobby)
var tank_left   : float = 60.0
var tank_right  : float = 1860.0
var tank_top    : float = 60.0
var tank_bottom : float = 880.0   # above sand bed

# Bot wandering
var _bot_target   : Vector2 = Vector2.ZERO
var _bot_timer    : float   = 0.0
var _home_x       : float   = 0.0   # column centre for this bot

# Input action prefix (p1_, p2_, p3_, p4_)
var _input_prefix : String  = "p1_"

# Sub-nodes (built in _ready)
var _sprite       : Sprite2D
var _name_label   : Label
var _tip_label    : Label   # "MOVE TO CLAIM!" shown for humans
var _badge_label  : Label   # "🤖 BOT" shown for bots
var _bg_rect      : ColorRect  # coloured pill behind the name

const SKIN_ROW_OFFSETS : Array[int] = [0, 16, 32, 48]

# ── Init ───────────────────────────────────────────────────────
func _ready() -> void:
	_input_prefix = "p%d_" % (player_id + 1)
	_bot_target   = position
	_home_x       = position.x
	_build_visuals()
	_pick_bot_target()


func _build_visuals() -> void:
	# ── Sprite ─────────────────────────────────────────────────
	_sprite = Sprite2D.new()
	_sprite.texture        = load("res://entities/fish/Fish_Sprite_Sheet_16.png")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.hframes        = 16
	_sprite.vframes        = 24
	_sprite.frame          = SKIN_ROW_OFFSETS[player_id % SKIN_ROW_OFFSETS.size()]
	_sprite.scale          = Vector2(2.8, 2.8)
	_sprite.modulate       = player_color.lerp(Color.WHITE, 0.35)
	add_child(_sprite)

	# ── Coloured nameplate background ──────────────────────────
	_bg_rect = ColorRect.new()
	_bg_rect.size                        = Vector2(130, 28)
	_bg_rect.position                    = Vector2(-65, -68)
	_bg_rect.color                       = Color(player_color.r, player_color.g, player_color.b, 0.45)
	add_child(_bg_rect)

	# ── Player name label ──────────────────────────────────────
	_name_label                          = Label.new()
	_name_label.text                     = player_name
	_name_label.position                 = Vector2(-65, -68)
	_name_label.custom_minimum_size      = Vector2(130, 28)
	_name_label.horizontal_alignment     = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment       = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_name_label)

	if is_bot:
		# ── BOT badge ──────────────────────────────────────────
		_badge_label                     = Label.new()
		_badge_label.text                = "🤖 BOT"
		_badge_label.position            = Vector2(-36, -92)
		_badge_label.custom_minimum_size = Vector2(72, 22)
		_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_badge_label.add_theme_font_size_override("font_size", 12)
		_badge_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		add_child(_badge_label)
	else:
		# ── "MOVE TO CLAIM!" tip for human players ─────────────
		_tip_label                       = Label.new()
		_tip_label.text                  = "▶ MOVE TO CLAIM!"
		_tip_label.position              = Vector2(-70, -92)
		_tip_label.custom_minimum_size   = Vector2(140, 22)
		_tip_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
		_tip_label.add_theme_font_size_override("font_size", 11)
		_tip_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.75))
		add_child(_tip_label)
		# Pulsing visibility so it's eye-catching but not annoying
		_pulse_tip()


# ── Physics ────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_bot:
		_process_bot(delta)
	else:
		_process_human(delta)

	# Clamp within tank bounds
	position.x = clampf(position.x, tank_left,  tank_right)
	position.y = clampf(position.y, tank_top,    tank_bottom)

	move_and_slide()
	_animate_swim()


# ── Human: free 6-direction swim ───────────────────────────────
func _process_human(delta: float) -> void:
	var move_x : float = Input.get_axis(_input_prefix + "left",  _input_prefix + "right")
	var move_y : float = Input.get_axis(_input_prefix + "up",    _input_prefix + "down")

	# Also accept jump as "swim up"
	if Input.is_action_pressed(_input_prefix + "jump"):
		move_y = -1.0

	var dir : Vector2 = Vector2(move_x, move_y)
	if dir.length_squared() > 1.0:
		dir = dir.normalized()

	velocity = lerp(velocity, dir * HUMAN_SPEED, 0.22)

	# Hide tip once the player actually moves
	if _tip_label and dir.length_squared() > 0.05:
		_tip_label.visible = false

	# Flip sprite to face direction
	if move_x != 0.0:
		scale.x = 1.0 if move_x > 0.0 else -1.0


# ── Bot: gentle 6-direction wander within home column zone ─────
func _process_bot(delta: float) -> void:
	_bot_timer -= delta
	if _bot_timer <= 0.0:
		_pick_bot_target()

	var dir : Vector2 = (_bot_target - position)
	if dir.length_squared() < 400.0:
		# Close enough — pick a new target
		_pick_bot_target()
		dir = (_bot_target - position)

	if dir.length_squared() > 1.0:
		dir = dir.normalized()

	velocity = lerp(velocity, dir * BOT_SPEED, 0.08)

	if dir.x != 0.0:
		scale.x = 1.0 if dir.x > 0.0 else -1.0


func _pick_bot_target() -> void:
	# Wander within ±220 px of the bot's home column
	var half_w  : float = 220.0
	var half_h  : float = 180.0
	_bot_target = Vector2(
		clampf(_home_x + randf_range(-half_w, half_w), tank_left  + 40.0, tank_right  - 40.0),
		clampf(
			(tank_top + tank_bottom) * 0.5 + randf_range(-half_h, half_h),
			tank_top  + 40.0,
			tank_bottom - 40.0
		)
	)
	_bot_timer = randf_range(1.8, 3.4)


# ── Swimming animation ─────────────────────────────────────────
func _animate_swim() -> void:
	if not _sprite:
		return
	var speed_sq : float = velocity.length_squared()
	var base     : int   = SKIN_ROW_OFFSETS[player_id % SKIN_ROW_OFFSETS.size()]

	if speed_sq > 200.0:
		# Active swim cycle (4-frame loop)
		_sprite.frame = base + (int(Time.get_ticks_msec() / 140) % 4)
	else:
		# Idle gentle bob — stay on frame 0
		_sprite.frame = base


# ── Tip pulse ─────────────────────────────────────────────────
func _pulse_tip() -> void:
	if not _tip_label:
		return
	var t : Tween = create_tween().set_loops()
	t.tween_property(_tip_label, "modulate:a", 0.15, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(_tip_label, "modulate:a", 1.0,  0.7).set_trans(Tween.TRANS_SINE)
