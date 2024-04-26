package debug;

import openfl.utils.Object;
import debug.macro.GitCommitMacro;
import flixel.FlxState;

@:allow(debug.DebugOverlay)
class DebugInfo extends DebugTextField
{
	@:noCompletion extern inline static final PRECISION = 2;

	@:noCompletion var __extraData = new Array<ExtraData>();
	@:noCompletion var __timeElapsed:String;
	@:noCompletion var __stateClass:String;
	@:noCompletion var __prevTime = 0;

	public function new(x = 0.0, y = 0.0)
	{
		super(x, y);

		FlxG.signals.preStateCreate.add((s) ->
		{
			__stateClass = __get__state__class(s);
			while (__extraData.length != 0)
				__extraData.pop();
		});
		__timeElapsed = __get__time__elapsed(0);
	}

	@:access(flixel.util.FlxTimerManager._timers)
	@:access(flixel.tweens.FlxTweenManager._tweens)
	override function flixelUpdate()
	{
		if (!__visible || __alpha == 0.0)
			return;

		// upate time info once a second
		final currentTime = FlxG.game.ticks;
		if (__prevTime % 1000 > currentTime % 1000)
			__timeElapsed = __get__time__elapsed(currentTime * 0.001);

		var tmp:String;
		_text = "";

		#if MODS_ALLOWED
		tmp = "";
		tmp += "\n - Current: " + (Mods.currentModDirectory.length == 0 ? null : Mods.currentModDirectory);
		if (Mods.getGlobalMods().length != 0)
			tmp += "\n - Global: [" + Mods.getGlobalMods().join(", ") + "]";
		_text += '\nMods: $tmp';
		#end
		_text += "\nDirrectory: " + Paths.currentLevel;

		_text += '\nState: $__stateClass';
		tmp = __get__substate__info(FlxG.state.subState);
		if (tmp.length != 0)
		{
			_text += "\nSubstate";
			if (tmp.contains("->"))
				_text += "s";
			_text += ': $tmp';
		}

		_text += "\nTweens: " + (FlxTween.globalManager._tweens.length + substates.PauseSubState.tweenManager._tweens.length);
		_text += "\nTimers: " + FlxTimer.globalManager._timers.length;

		if (__extraData.length != 0)
		{
			_text += "\n";
			var value:Dynamic;
			for (data in __extraData)
			{
				value = (Type.typeof(data.value) == TFunction ? data.value() : data.value);
				if (value is Float)
					value = FlxMath.roundDecimal(value, PRECISION);
				_text += "\n" + data.label + ': $value';
			}
		}

		_text += "\n";
		_text += '\nTime Elapsed: $__timeElapsed';
		if (DiscordClient.user != null)
			_text += "\nDiscord User: " + DiscordClient.user;
		_text += "\nCommit " + GitCommitMacro.number + " (" + GitCommitMacro.hash + ")";
		_text += "\n" + FlxG.VERSION;

		this.text = _text;
		__prevTime = currentTime;
	}

	@:noCompletion extern inline function __get__time__elapsed(__time:Float):String
	{
		var __str = "";
		if (__time > 86400) // like fr wth are you doing here for over a day
			__str += "(go touch some grass you moron) " + Std.int(__time * 0.000011574074074074073) + "d "; // / 86400
		if (__time > 3600)
			__str += Std.int(__time % 86400 * 0.0002777777777777778) + "h "; // / 3600
		if (__time > 60)
			__str += Std.int(__time % 3600 * 0.016666666666666666) + "m "; // / 60

		return __str + Std.int(__time % 60) + "s";
	}

	@:noCompletion extern inline function __get__state__class(__state:FlxState):String
	{
		return Type.getClassName(Type.getClass(__state));
	}

	@:noCompletion extern inline function __get__substate__info(__substate:FlxState):String
	{
		var __str = "";
		while (__substate != null)
		{
			__str += __get__state__class(__substate);
			__substate = __substate.subState;
			if (__substate != null)
				__str += " -> ";
		}
		return __str;
	}
}

abstract ExtraData(Array<Dynamic>) from Array<Dynamic>
{
	public var label(get, set):String;
	public var value(get, set):Dynamic;

	@:noCompletion inline function get_label():String	 return this[0];
	@:noCompletion inline function get_value():Dynamic	 return this[1];
	@:noCompletion inline function set_label(v):String	 return this[0] = v;
	@:noCompletion inline function set_value(v):Dynamic	 return this[1] = v;
}
