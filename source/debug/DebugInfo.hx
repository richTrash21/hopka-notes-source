package debug;

import flixel.FlxState;
import debug.macro.GitCommitMacro;

class DebugInfo extends DebugTextField
{
	@:noCompletion var __timeElapsed:String;
	@:noCompletion var __stateClass:String;
	@:noCompletion var __prevTime = 0;

	public function new(x = 0.0, y = 0.0)
	{
		super(x, y);

		FlxG.signals.preStateCreate.add((s) -> __stateClass = __get__state__class(s));
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
		if (!Mods.currentModDirectory.isNullOrEmpty())
			tmp += "Current: " + Mods.currentModDirectory;
		if (Mods.getGlobalMods().length != 0)
		{
			if (tmp.length != 0)
				tmp += " | ";
			tmp += "Global: [" + Mods.getGlobalMods().join(", ") + "]";
		}
		if (tmp.length != 0)
			_text += '\nMods: ($tmp)';
		#end
		_text += "\nDirrectory: " + Paths.currentLevel;

		_text += '\nState: $__stateClass';
		if (FlxG.state.subState != null)
		{
			tmp = __get__substate__info(FlxG.state.subState);
			_text += "\nSubstate";
			if (tmp.contains("->"))
				_text += "s";
			_text += ': $tmp';
		}

		final charting = _text.contains("ChartingState");
		final onPlayState = _text.contains("PlayState") || charting;
		tmp = FlxStringUtil.formatTime(Math.abs(Conductor.songPosition) * 0.001);
		if (Conductor.songPosition < 0.0)
			tmp = '-$tmp';
		tmp = 'Position: $tmp';
		if (onPlayState)
		{
			var t = "Song: " + (charting ? states.editors.ChartingState._song.song : PlayState.SONG.song.toLowerCase());
			final d = Difficulty.getString().toLowerCase();
			if (d != Difficulty.defaultDifficulty.toLowerCase())
				t += ' [$d]';
			tmp = '$t | $tmp/' + FlxStringUtil.formatTime(FlxG.sound.music.length * 0.001);
		}
		tmp += " | BPM: " + Conductor.bpm;
		if (onPlayState && Conductor.bpm != PlayState.SONG.bpm)
			tmp += " [" + PlayState.SONG.bpm + "]";
		_text += '\nConductor: ($tmp)';

		_text += "\nTweens: " + FlxTween.globalManager._tweens.length;
		_text += "\nTimers: " + FlxTimer.globalManager._timers.length;

		_text += "\n\nVolume: " + FlxG.sound.volume;
		if (FlxG.sound.muted)
			_text += " [muted]";
		if (DiscordClient.user != null)
			_text += "\nDiscord User: " + DiscordClient.user;
		_text += '\nTime Elapsed: $__timeElapsed';
		_text += "\nCommit #" + GitCommitMacro.number + " (" + GitCommitMacro.hash + ")";

		this.text = _text;
		__prevTime = currentTime;
	}

	@:noCompletion extern inline static function __get__time__elapsed(__time:Float):String
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

	@:noCompletion extern inline static function __get__state__class(__state:FlxState):String
	{
		return Type.getClassName(Type.getClass(__state));
	}

	@:noCompletion extern inline static function __get__substate__info(__substate:FlxState):String
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
