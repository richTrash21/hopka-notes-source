package debug;

import openfl.text.TextFormat;
import openfl.events.MouseEvent;
import openfl.events.FocusEvent;

import flixel.util.FlxStringUtil;

/**
	The FPS class provides an easy-to-use monitor to display
	the current frame rate of an OpenFL project

	from: https://github.com/ShadowMario/FNF-PsychEngine/pull/13591 (merged with new psych lmao)
	UPD: added fix https://github.com/ShadowMario/FNF-PsychEngine/pull/13865
	UPDD: reverted fix to standart OpenFl FPS class
**/
class FPSCounter extends openfl.text.TextField
{
	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(default, null):Int = 0;

	/**
		The current memory usage (WARNING: this is NOT your total program memory usage, rather it shows the garbage collector memory)
	**/
	public var memoryMegas(get, never):Int;

	/**
		**BETA**
		The current memory usage of GPU. (WARNING: this show ALL of GPU memory usage, not just for the game)
	**/
	// public var memoryMegasGPU(get, never):Int;

	#if !RELESE_BUILD_FR
	public var debug:Bool = false;

	@:noCompletion var prevTime = 0;
	@:noCompletion var timeElapsed:String;
	#end

	@:allow(Main) @:noCompletion var commit:String;
	@:noCompletion var times:Array<Float>;
	@:noCompletion var cacheCount = 0;
	@:noCompletion var memPeak = 0;
	@:noCompletion var __formatFPS:TextFormat;

	public function new(x = 10.0, y = 10.0):Void
	{
		super();
		this.x = x;
		this.y = y;

		selectable = mouseEnabled = false;
		defaultTextFormat = new TextFormat("_sans", 12, 0xFFFFFF, true);
		__formatFPS = new TextFormat("_sans", 12, 0xFF0000, true);
		autoSize = LEFT;
		multiline = true;
		text = "FPS: ";

		times = new Array();
		shader = new shaders.OutlineShader(); // for better visibility

		// i think it is optimization - Redar
		removeEventListener(FocusEvent.FOCUS_IN, this_onFocusIn);
		removeEventListener(FocusEvent.FOCUS_OUT, this_onFocusOut);
		removeEventListener(MouseEvent.MOUSE_DOWN, this_onMouseDown);
		removeEventListener(MouseEvent.MOUSE_WHEEL, this_onMouseWheel);
		removeEventListener(MouseEvent.DOUBLE_CLICK, this_onDoubleClick);
		removeEventListener(openfl.events.KeyboardEvent.KEY_DOWN, this_onKeyDown);

		FlxG.signals.preUpdate.add(update);
		timeElapsed = __get__time__elapsed(0);
	}

	// Event Handlers
	@:access(flixel.FlxGame.getTicks)
	@:noCompletion function update():Void
	{
		final currentTime = FlxG.game.getTicks();
		times.push(currentTime);
		while (times[0] < currentTime - 1000)
			times.shift();

		final currentCount = times.length;
		if (currentCount != cacheCount)
		{
			// caping new framerate to the maximum fps possible so it wont go above
			currentFPS = FlxMath.minInt(Std.int((currentCount + cacheCount) * .5), FlxG.updateFramerate);
			cacheCount = currentCount;
		}

		if (!__visible || __alpha == 0.0)
			return;

		final curMem = memoryMegas;
		if (curMem > memPeak)
			memPeak = curMem;

		var text = 'FPS: $currentFPS';
		text += "\nMemory: " + FlxStringUtil.formatBytes(curMem);
		if (debug)
			text += " [Peak: " + FlxStringUtil.formatBytes(memPeak) + "]";
		
		/*if (ClientPrefs.data.cacheOnGPU)
		{
			final gpuMem = memoryMegasGPU;
			if (gpuMem != 0)
				text += "\nGPU Memory: " + FlxStringUtil.formatBytes(memoryMegasGPU);
		}*/
		#if !RELESE_BUILD_FR
		if (debug)
		{
			text += "\n";
			// upate time info once a second
			if (prevTime % 1000 > currentTime % 1000)
				timeElapsed = __get__time__elapsed(currentTime * 0.001);

			var tmp = "";
			#if MODS_ALLOWED
			if (!Mods.currentModDirectory.isNullOrEmpty())
				tmp += "Current: " + Mods.currentModDirectory;
			if (Mods.getGlobalMods().length != 0)
			{
				if (tmp.length != 0)
					tmp += " | ";
				tmp += "Global: [" + Mods.getGlobalMods().join(", ") + "]";
			}
			if (tmp.length != 0)
				text += '\nMods: ($tmp)';
			#end
			text += "\nDirrectory: " + Paths.currentLevel;

			tmp = __get__state__info();
			text += '\nState: $tmp';
			final onPlayState = tmp.contains("PlayState"); // PlayState or EditorPlayState
			if (onPlayState)
				text += "\nSong: " + PlayState.SONG;

			tmp = "Position: " + FlxStringUtil.formatTime(Conductor.songPosition * 0.001);
			if (onPlayState)
				tmp += "/" + FlxStringUtil.formatTime(FlxG.sound.music.length * 0.001);
			tmp += " | BPM: " + Conductor.bpm;
			if (onPlayState && Conductor.bpm != PlayState.SONG.bpm)
				tmp += " [" + PlayState.SONG.bpm + "]";
			text += '\nConductor: ($tmp)';

			text += '\n\nTime Elapsed: $timeElapsed';
			text += '\nCommit #$commit';
			prevTime = currentTime;
		}
		#end
		this.text = text;
		setTextFormat(currentFPS < 30 ? __formatFPS : defaultTextFormat, 0, text.indexOf("\n"));
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

	@:noCompletion extern inline static function __get__state__info():String
	{
		var __state = FlxG.state;
		var __str = FlxStringUtil.getClassName(__state);

		__state = __state.subState;
		var __temp = "";
		while (__state != null)
		{
			__temp += FlxStringUtil.getClassName(__state);
			__state = __state.subState;
			if (__state != null)
				__temp += " -> ";
		}
		if (__temp.length != 0)
			__str += ' [$__temp]';

		return __str;
	}

	@:noCompletion inline function get_memoryMegas():Int
	{
		return cast (openfl.system.System.totalMemory, UInt);
	}

	/*@:noCompletion inline function get_memoryMegasGPU():Int
	{
		return FlxG.stage.context3D.totalGPUMemory;
	}*/
}
