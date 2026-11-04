extends Node

## InputManager — Auto-detects gamepads and remaps player input actions.
##
## How it works:
##   · P1 always uses keyboard (WASD).
##   · P2 always uses keyboard (Arrow keys).
##   · P3 and P4 are auto-assigned to connected gamepads (device 0, 1 …).
##     If no gamepad is present for that slot, they fall back to keyboard.
##
## Any scene can call:
##   InputManager.get_device_type(player_id)   → "keyboard" or "gamepad"
##   InputManager.get_device_index(player_id)  → -1 or 0/1/…
##
## The PlayerData.device_id field is kept in sync automatically.

# Signals
signal device_changed(player_id: int, device_type: String)

# Keyboard-only slots (never reassigned to gamepad)
const KEYBOARD_SLOTS = [0, 1]

# Gamepad-eligible player slots and the order they claim pad indices
const GAMEPAD_SLOTS = [2, 3]

# Internal state: player_id → device_index (-1 = keyboard)
var _device_map: Dictionary = {0: -1, 1: -1, 2: -1, 3: -1}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Listen for hotplug events
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	# Initial detection pass
	_assign_gamepads()


# ─────────────────────────────────────────────────────────────
#  Public API
# ─────────────────────────────────────────────────────────────

func get_device_type(player_id: int) -> String:
	if _device_map.get(player_id, -1) >= 0:
		return "gamepad"
	return "keyboard"


func get_device_index(player_id: int) -> int:
	return _device_map.get(player_id, -1)


func is_using_gamepad(player_id: int) -> bool:
	return _device_map.get(player_id, -1) >= 0


# ─────────────────────────────────────────────────────────────
#  Auto-assign gamepads to GAMEPAD_SLOTS
# ─────────────────────────────────────────────────────────────

func _assign_gamepads() -> void:
	var connected = Input.get_connected_joypads()

	for slot_rank in range(GAMEPAD_SLOTS.size()):
		var pid = GAMEPAD_SLOTS[slot_rank]
		var old_device = _device_map.get(pid, -1)
		var new_device = -1

		if slot_rank < connected.size():
			new_device = connected[slot_rank]  # e.g. 0 or 1

		_device_map[pid] = new_device

		if new_device != old_device:
			_remap_actions(pid, new_device)
			_sync_player_data(pid, new_device)
			var dtype = "gamepad" if new_device >= 0 else "keyboard"
			device_changed.emit(pid, dtype)
			if new_device >= 0:
				print("[InputManager] P%d → Gamepad %d (%s)" % [
					pid + 1, new_device, Input.get_joy_name(new_device)])
			else:
				print("[InputManager] P%d → Keyboard fallback" % (pid + 1))


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_assign_gamepads()


# ─────────────────────────────────────────────────────────────
#  Remap project input actions for a player slot to the given device.
#
#  Each pN_* action keeps its keyboard fallback events and swaps out
#  only the joypad events (axis + dpad buttons) to the new device index.
# ─────────────────────────────────────────────────────────────

func _remap_actions(player_id: int, device_index: int) -> void:
	var prefix = "p%d_" % (player_id + 1)
	var dirs = ["up", "down", "left", "right", "jump", "action"]

	for dir in dirs:
		var action = prefix + dir
		if not InputMap.has_action(action):
			continue

		# Remove old joypad events (keep keyboard events)
		var kept = []
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadMotion or ev is InputEventJoypadButton:
				pass  # discard — will re-add with correct device
			else:
				kept.append(ev)
		InputMap.action_erase_events(action)
		for ev in kept:
			InputMap.action_add_event(action, ev)

		# If a real gamepad is assigned, add axis + dpad events for it
		if device_index >= 0:
			_add_joy_events(action, dir, device_index)


func _add_joy_events(action: String, dir: String, dev: int) -> void:
	match dir:
		"left":
			# Left analog stick axis
			var ax = InputEventJoypadMotion.new()
			ax.device     = dev
			ax.axis       = JOY_AXIS_LEFT_X
			ax.axis_value = -1.0
			InputMap.action_add_event(action, ax)
			# D-pad
			var dp = InputEventJoypadButton.new()
			dp.device       = dev
			dp.button_index = JOY_BUTTON_DPAD_LEFT
			InputMap.action_add_event(action, dp)

		"right":
			var ax = InputEventJoypadMotion.new()
			ax.device     = dev
			ax.axis       = JOY_AXIS_LEFT_X
			ax.axis_value = 1.0
			InputMap.action_add_event(action, ax)
			var dp = InputEventJoypadButton.new()
			dp.device       = dev
			dp.button_index = JOY_BUTTON_DPAD_RIGHT
			InputMap.action_add_event(action, dp)

		"up":
			var ax = InputEventJoypadMotion.new()
			ax.device     = dev
			ax.axis       = JOY_AXIS_LEFT_Y
			ax.axis_value = -1.0
			InputMap.action_add_event(action, ax)
			var dp = InputEventJoypadButton.new()
			dp.device       = dev
			dp.button_index = JOY_BUTTON_DPAD_UP
			InputMap.action_add_event(action, dp)

		"down":
			var ax = InputEventJoypadMotion.new()
			ax.device     = dev
			ax.axis       = JOY_AXIS_LEFT_Y
			ax.axis_value = 1.0
			InputMap.action_add_event(action, ax)
			var dp = InputEventJoypadButton.new()
			dp.device       = dev
			dp.button_index = JOY_BUTTON_DPAD_DOWN
			InputMap.action_add_event(action, dp)

		"jump":
			# South button (A/Cross)
			var btn = InputEventJoypadButton.new()
			btn.device       = dev
			btn.button_index = JOY_BUTTON_A
			InputMap.action_add_event(action, btn)

		"action":
			# East button (B/Circle)
			var btn = InputEventJoypadButton.new()
			btn.device       = dev
			btn.button_index = JOY_BUTTON_B
			InputMap.action_add_event(action, btn)


# ─────────────────────────────────────────────────────────────
#  Keep PlayerData.device_id in sync
# ─────────────────────────────────────────────────────────────

func _sync_player_data(player_id: int, device_index: int) -> void:
	var pd = GameManager.get_player_data(player_id)
	if pd:
		pd.device_id = device_index
