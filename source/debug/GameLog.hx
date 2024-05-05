package debug;

#if !FLX_DEBUG
import flixel.system.FlxAssets;
#end
import haxe.PosInfos;

@:allow(Main)
class GameLog
{
	extern inline static final WARN_SOUND = "assets/sounds/pikmin";
	extern inline static final ERROR_SOUND = "assets/sounds/metal";
	public static var silent = #if FLX_DEBUG false #else true #end;
	public static var logTime = true;

	static var __log = "";
	static var __warns = new Array<String>();
	static var __errors = new Array<String>();

	inline public static function trace(value:Dynamic, ?pos:PosInfos)
	{
		add(value, TRACE, pos);
	}

	inline public static function warn(value:Dynamic, ?pos:PosInfos)
	{
		add(value, WARN, pos);
	}

	inline public static function error(value:Dynamic, ?pos:PosInfos)
	{
		add(value, ERROR, pos);
	}

	inline public static function notice(value:Dynamic, ?pos:PosInfos)
	{
		add(value, NOTICE, pos);
	}

	public static function add(value:Dynamic, type:LogType, ?pos:PosInfos)
	{
		inline function __add(v:String, t:LogType, p:PosInfos)
		{
			final s = formatOutput(v, t, p);
			__log += '$s\n';
			Sys.println(s);
		}

		final v = Std.string(value);
		switch (type)
		{
			case WARN:
				#if FLX_DEBUG
				final snd = flixel.system.debug.log.LogStyle.WARNING.errorSound;
				if (silent)
					flixel.system.debug.log.LogStyle.WARNING.errorSound = null;
				FlxG.log.warn(v);
				flixel.system.debug.log.LogStyle.WARNING.errorSound = snd;
				#end
				if (!__warns.contains(v))
				{
					#if !FLX_DEBUG
					if (!silent)
						FlxG.sound.load(FlxAssets.getSound(WARN_SOUND)).play();
					#end
					__warns.push(v);
					__add(v, type, pos);
				}

			case ERROR:
				#if FLX_DEBUG
				final snd = flixel.system.debug.log.LogStyle.ERROR.errorSound;
				if (silent)
					flixel.system.debug.log.LogStyle.ERROR.errorSound = null;
				FlxG.log.error(v);
				flixel.system.debug.log.LogStyle.ERROR.errorSound = snd;
				#end
				if (!__errors.contains(v))
				{
					#if !FLX_DEBUG
					if (!silent)
						FlxG.sound.load(FlxAssets.getSound(ERROR_SOUND)).play();
					#end
					__errors.push(v);
					__add(v, type, pos);
				}

			default:
				__add(v, type, pos);
		}
	}

	// based on haxe.Log.formatOutput()
	@:noCompletion extern inline static function formatOutput(s:String, lt:LogType, pos:PosInfos):String
	{
		var t = '$lt';
		if (logTime)
			t = "<" + Date.now().toString().substr(11) + '> $t';
		if (pos == null)
			return '$t > $s';

		var p = pos.fileName + ":" + pos.lineNumber;
		if (!pos.methodName.isNullOrEmpty())
		{
			p += " - ";
			if (!pos.className.isNullOrEmpty())
			{
				var c = pos.className;
				final i = c.indexOf(".");
				if (i != -1)
					c = c.substr(i+1);
				p += '$c.';
			}
			p += pos.methodName; // + "()"
		}

		if (pos.customParams != null)
			for (v in pos.customParams)
				s += ', $v';

		return '$t [$p] > $s';
	}
}

enum abstract LogType(Int) from Int to Int
{
	var TRACE   = 0;
	var WARN    = 1;
	var WARNING = 1;
	var ERROR   = 2;
	var NOTICE  = 3;

	// TODO: print colors
	/*inline public function color():FlxColor
	{
		return switch (this)
		{
			case WARN:    0xFF9900;
			case ERROR:   0xFF0000;
			default:      0xEEEEEE;
		}
	}*/

	@:from inline public static function fromString(s:String):LogType
	{
		return switch (s.toLowerCase())
		{
			case "warn" | "warning": WARN;
			case "error":            ERROR;
			case "notice":           NOTICE;
			default:                 TRACE;
		}
	}

	@:to inline public function toString():String
	{
		return switch (this)
		{
			case WARN:   "[WARNING]";
			case ERROR:  "[ERROR]";
			case NOTICE: "[NOTICE]";
			default:     "[TRACE]";
		}
	}
}
