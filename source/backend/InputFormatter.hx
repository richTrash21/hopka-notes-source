package backend;

import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;

class InputFormatter
{
	public static function getKeyName(key:FlxKey):String
	{
		return switch (key)
		{
			case BACKSPACE:			"BckSpc";
			case CONTROL:			"Ctrl";
			case ALT:				"Alt";
			case CAPSLOCK:			"Caps";
			case PAGEUP:			"PgUp";
			case PAGEDOWN:			"PgDown";
			case ZERO:				"0";
			case ONE:				"1";
			case TWO:				"2";
			case THREE:				"3";
			case FOUR:				"4";
			case FIVE:				"5";
			case SIX:				"6";
			case SEVEN:				"7";
			case EIGHT:				"8";
			case NINE:				"9";
			case NUMPADZERO:		"#0";
			case NUMPADONE:			"#1";
			case NUMPADTWO:			"#2";
			case NUMPADTHREE:		"#3";
			case NUMPADFOUR:		"#4";
			case NUMPADFIVE:		"#5";
			case NUMPADSIX:			"#6";
			case NUMPADSEVEN:		"#7";
			case NUMPADEIGHT:		"#8";
			case NUMPADNINE:		"#9";
			case NUMPADMULTIPLY:	"#*";
			case NUMPADPLUS:		"#+";
			case NUMPADMINUS:		"#-";
			case NUMPADPERIOD:		"#.";
			case SEMICOLON:			";";
			case COMMA:				",";
			case PERIOD:			".";
//			case SLASH:				"/";
			case GRAVEACCENT:		"`";
			case LBRACKET:			"[";
//			case BACKSLASH:			"\\";
			case RBRACKET:			"]";
			case QUOTE:				"'";
			case PRINTSCREEN:		"PrtScrn";
			case NONE:				"---";
			default:				__keyToString(key);
		}
	}

	public static function getGamepadName(key:FlxGamepadInputID)
	{
		final model = FlxG.gamepads.firstActive?.detectedModel ?? UNKNOWN;
		return switch (key)
		{
			// Analogs
			case LEFT_STICK_DIGITAL_LEFT:  "Left";
			case LEFT_STICK_DIGITAL_RIGHT: "Right";
			case LEFT_STICK_DIGITAL_UP:    "Up";
			case LEFT_STICK_DIGITAL_DOWN:  "Down";

			case LEFT_STICK_CLICK: switch (model)
					{
						case PS4:	 "L3";
						case XINPUT: "LS";
						default:	 "Analog Click";
					}

			case RIGHT_STICK_DIGITAL_LEFT:	"C. Left";
			case RIGHT_STICK_DIGITAL_RIGHT:	"C. Right";
			case RIGHT_STICK_DIGITAL_UP:	"C. Up";
			case RIGHT_STICK_DIGITAL_DOWN:	"C. Down";

			case RIGHT_STICK_CLICK: switch (model)
					{
						case PS4:	 "R3";
						case XINPUT: "RS";
						default:	 "C. Click";
					}

			// Directional
			case DPAD_LEFT:  "D. Left";
			case DPAD_RIGHT: "D. Right";
			case DPAD_UP:    "D. Up";
			case DPAD_DOWN:  "D. Down";

			// Top buttons
			case LEFT_SHOULDER: switch (model)
					{
						case PS4:	 "L1";
						case XINPUT: "LB";
						default:	 "L. Bumper";
					}

			case RIGHT_SHOULDER: switch (model)
					{
						case PS4:	 "R1";
						case XINPUT: "RB";
						default:	 "R. Bumper";
					}

			case LEFT_TRIGGER, LEFT_TRIGGER_BUTTON: switch (model)
					{
						case PS4:	 "L2";
						case XINPUT: "LT";
						default:	 "L. Trigger";
					}

			case RIGHT_TRIGGER, RIGHT_TRIGGER_BUTTON: switch (model)
					{
						case PS4:	 "R2";
						case XINPUT: "RT";
						default:	 "R. Trigger";
					}

			// Buttons
			case A: switch (model)
					{
						case PS4:	 "X";
						case XINPUT: "A";
						default:	 "Action Down";
					}

			case B: switch (model)
					{
						case PS4:	 return "O";
						case XINPUT: return "B";
						default:	 "Action Right";
					}

			case X: switch (model)
					{
						case PS4:	 "["; // This gets its image changed through code
						case XINPUT: "X";
						default:	 "Action Left";
					}

			case Y: switch (model)
					{ 
						case PS4: return "]"; // This gets its image changed through code
						case XINPUT: return "Y";
						default: return "Action Up";
					}

			case BACK: switch (model)
					{
						case PS4:	 "Share";
						case XINPUT: "Back";
						default:	 "Select";
					}

			case START: switch (model)
					{
						case PS4: "Options";
						default:  "Start";
					}

			case NONE: "---";
			default: __keyToString(key);
		}
	}

	inline static function __keyToString(key:haxe.extern.EitherType<FlxKey, FlxGamepadInputID>):String
	{
		final label = Std.string(key);
		if (label.toLowerCase() == "null")
			return "---";

		final arr = label.split("_");
		for (i in 0...arr.length)
			arr[i] = CoolUtil.capitalize(arr[i]);

		return arr.join(" ");
	}
}