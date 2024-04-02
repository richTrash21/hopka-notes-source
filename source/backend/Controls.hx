package backend;

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;

/**
	Keeping same use cases on stuff for it to be easier to understand/use
	I'd have removed it but this makes it a lot less annoying to use in my opinion

	You do NOT have to create these variables/getters for adding new keys,
	but you will instead have to use:
	   controls.justPressed("ui_up")   instead of   controls.UI_UP

	Dumb but easily usable code, or Smart but complicated? Your choice.
	Also idk how to use macros they're weird as fuck lol
**/
class Controls
{
	// main class instance
	@:allow(Main)
	public static var instance(default, null):Controls;

	// Pressed buttons (directions)
	public var UI_UP_P(get, never):Bool;
	public var UI_DOWN_P(get, never):Bool;
	public var UI_LEFT_P(get, never):Bool;
	public var UI_RIGHT_P(get, never):Bool;
	public var NOTE_UP_P(get, never):Bool;
	public var NOTE_DOWN_P(get, never):Bool;
	public var NOTE_LEFT_P(get, never):Bool;
	public var NOTE_RIGHT_P(get, never):Bool;

	// Held buttons (directions)
	public var UI_UP(get, never):Bool;
	public var UI_DOWN(get, never):Bool;
	public var UI_LEFT(get, never):Bool;
	public var UI_RIGHT(get, never):Bool;
	public var NOTE_UP(get, never):Bool;
	public var NOTE_DOWN(get, never):Bool;
	public var NOTE_LEFT(get, never):Bool;
	public var NOTE_RIGHT(get, never):Bool;

	// Released buttons (directions)
	public var UI_UP_R(get, never):Bool;
	public var UI_DOWN_R(get, never):Bool;
	public var UI_LEFT_R(get, never):Bool;
	public var UI_RIGHT_R(get, never):Bool;
	public var NOTE_UP_R(get, never):Bool;
	public var NOTE_DOWN_R(get, never):Bool;
	public var NOTE_LEFT_R(get, never):Bool;
	public var NOTE_RIGHT_R(get, never):Bool;

	// Pressed buttons (others)
	public var ACCEPT(get, never):Bool;
	public var BACK(get, never):Bool;
	public var PAUSE(get, never):Bool;
	public var RESET(get, never):Bool;

	// Gamepad & Keyboard stuff
	public var keyboardBinds:Map<String, Array<FlxKey>>;
	public var gamepadBinds:Map<String, Array<FlxGamepadInputID>>;
	public var controllerMode:Bool = false;

	inline public function justPressed(key:String):Bool
	{
		return __inputHelper(key, FlxG.keys.anyJustPressed, _myGamepadJustPressed);
	}

	inline public function pressed(key:String):Bool
	{
		return __inputHelper(key, FlxG.keys.anyPressed, _myGamepadPressed);
	}

	inline public function justReleased(key:String):Bool
	{
		return __inputHelper(key, FlxG.keys.anyJustReleased, _myGamepadJustReleased);
	}

	@:noCompletion inline function _myGamepadJustPressed(keys:Array<FlxGamepadInputID>):Bool
	{
		return __gamepadHelper(keys, FlxG.gamepads.anyJustPressed);
	}

	@:noCompletion inline function _myGamepadPressed(keys:Array<FlxGamepadInputID>):Bool
	{
		return __gamepadHelper(keys, FlxG.gamepads.anyPressed);
	}

	@:noCompletion inline function _myGamepadJustReleased(keys:Array<FlxGamepadInputID>):Bool
	{
		return __gamepadHelper(keys, FlxG.gamepads.anyJustReleased);
	}

	@:noCompletion function __inputHelper(key:String, f1:(Array<FlxKey>)->Bool, f2:(Array<FlxGamepadInputID>)->Bool):Bool
	{
		final result = f1(keyboardBinds[key]);
		if (result)
			controllerMode = false;

		return result || f2(gamepadBinds[key]);
	}

	@:noCompletion function __gamepadHelper(keys:Array<FlxGamepadInputID>, f:(FlxGamepadInputID)->Bool):Bool
	{
		if (keys != null)
			for (key in keys)
				if (f(key))
					return controllerMode = true;

		return false;
	}

	@:noCompletion inline function get_UI_UP_P():Bool		return justPressed("ui_up");
	@:noCompletion inline function get_UI_DOWN_P():Bool		return justPressed("ui_down");
	@:noCompletion inline function get_UI_LEFT_P():Bool		return justPressed("ui_left");
	@:noCompletion inline function get_UI_RIGHT_P():Bool	return justPressed("ui_right");
	@:noCompletion inline function get_NOTE_UP_P():Bool		return justPressed("note_up");
	@:noCompletion inline function get_NOTE_DOWN_P():Bool	return justPressed("note_down");
	@:noCompletion inline function get_NOTE_LEFT_P():Bool	return justPressed("note_left");
	@:noCompletion inline function get_NOTE_RIGHT_P():Bool	return justPressed("note_right");

	@:noCompletion inline function get_UI_UP():Bool			return pressed("ui_up");
	@:noCompletion inline function get_UI_DOWN():Bool		return pressed("ui_down");
	@:noCompletion inline function get_UI_LEFT():Bool		return pressed("ui_left");
	@:noCompletion inline function get_UI_RIGHT():Bool		return pressed("ui_right");
	@:noCompletion inline function get_NOTE_UP():Bool		return pressed("note_up");
	@:noCompletion inline function get_NOTE_DOWN():Bool		return pressed("note_down");
	@:noCompletion inline function get_NOTE_LEFT():Bool		return pressed("note_left");
	@:noCompletion inline function get_NOTE_RIGHT():Bool	return pressed("note_right");

	@:noCompletion inline function get_UI_UP_R():Bool		return justReleased("ui_up");
	@:noCompletion inline function get_UI_DOWN_R():Bool		return justReleased("ui_down");
	@:noCompletion inline function get_UI_LEFT_R():Bool		return justReleased("ui_left");
	@:noCompletion inline function get_UI_RIGHT_R():Bool	return justReleased("ui_right");
	@:noCompletion inline function get_NOTE_UP_R():Bool		return justReleased("note_up");
	@:noCompletion inline function get_NOTE_DOWN_R():Bool	return justReleased("note_down");
	@:noCompletion inline function get_NOTE_LEFT_R():Bool	return justReleased("note_left");
	@:noCompletion inline function get_NOTE_RIGHT_R():Bool	return justReleased("note_right");

	@:noCompletion inline function get_ACCEPT():Bool		return justPressed("accept");
	@:noCompletion inline function get_BACK():Bool			return justPressed("back");
	@:noCompletion inline function get_PAUSE():Bool			return justPressed("pause");
	@:noCompletion inline function get_RESET():Bool			return justPressed("reset");

	// IGNORE!!!
	@:allow(Main)
	function new()
	{
		keyboardBinds = ClientPrefs.keyBinds;
		gamepadBinds = ClientPrefs.gamepadBinds;
	}
}