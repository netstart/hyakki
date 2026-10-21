class_name InputSetup
extends RefCounted
## Ações de entrada criadas em código: teclado e gamepad (plano 4.1).
## O toque é tratado pelo joystick virtual.


static func ensure_actions() -> void:
	_add_keys(&"move_left", [KEY_A, KEY_LEFT])
	_add_keys(&"move_right", [KEY_D, KEY_RIGHT])
	_add_keys(&"move_up", [KEY_W, KEY_UP])
	_add_keys(&"move_down", [KEY_S, KEY_DOWN])
	_add_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis(&"move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis(&"move_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_keys(&"pause", [KEY_ESCAPE, KEY_P])
	_add_button(&"pause", JOY_BUTTON_START)
	_add_keys(&"speed", [KEY_TAB])
	_add_keys(&"ultimate", [KEY_SPACE, KEY_E])
	_add_button(&"ultimate", JOY_BUTTON_A)
	_add_keys(&"debug_overlay", [KEY_F3])
	_add_keys(&"debug_hitbox", [KEY_F4])


static func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


static func _add_keys(action: StringName, keys: Array[Key]) -> void:
	_ensure(action)
	for key: Key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


static func _add_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)


static func _add_button(action: StringName, button: JoyButton) -> void:
	_ensure(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
