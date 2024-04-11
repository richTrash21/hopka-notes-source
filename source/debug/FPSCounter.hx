package debug;

import openfl.text._internal.TextFormatRange;
import openfl.events.KeyboardEvent;
import openfl.events.FocusEvent;
import openfl.events.MouseEvent;
import openfl.text.TextFormat;

import flixel.util.FlxStringUtil;
import flixel.FlxState;

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
	public var memoryMegasGPU(get, never):Int;

	#if !RELESE_BUILD_FR
	public var debug:Bool = false;

	@:noCompletion var __prevTime = 0;
	@:noCompletion var __timeElapsed:String;
	@:noCompletion var __stateClass:String;
	#end

	@:allow(Main) @:noCompletion var commit:String;
	@:noCompletion var times:Array<Int>;
	@:noCompletion var cacheCount = 0;
	@:noCompletion var memPeak = 0;

	@:noCompletion var __textFormatList:Array<TextFormatRange>;

	public function new(x = 10.0, y = 10.0):Void
	{
		super();
		this.x = x;
		this.y = y;

		selectable = mouseEnabled = false;
		defaultTextFormat = new TextFormat("_sans", 12, 0xFFFFFF, true);
		__textFormatList = [
			new TextFormatRange(new TextFormat(), 4, 4) // fps color format
		];
		multiline = true;
		autoSize = LEFT;

		times = new Array();
		shader = new shaders.OutlineShader(); // for better visibility

		// i think it is optimization - Redar
		removeEventListener(FocusEvent.FOCUS_IN, this_onFocusIn);
		removeEventListener(FocusEvent.FOCUS_OUT, this_onFocusOut);
		removeEventListener(MouseEvent.MOUSE_DOWN, this_onMouseDown);
		removeEventListener(MouseEvent.MOUSE_WHEEL, this_onMouseWheel);
		removeEventListener(MouseEvent.DOUBLE_CLICK, this_onDoubleClick);
		removeEventListener(KeyboardEvent.KEY_DOWN, this_onKeyDown);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, this_onKeyDown);

		FlxG.signals.preUpdate.add(update);
		#if !RELESE_BUILD_FR
		FlxG.signals.preStateCreate.add((s) -> __stateClass = __get__state__class(s));
		#end
		__timeElapsed = __get__time__elapsed(0);
	}

	@:noCompletion override function this_onKeyDown(event:KeyboardEvent):Void
	{
		if (event.keyCode == flixel.input.keyboard.FlxKey.F4)
		{
			debug = FlxG.save.data.debugInfo = !FlxG.save.data.debugInfo;
			FlxG.save.flush();
		}
	}

	// Event Handlers
	@:access(flixel.FlxGame.getTicks)
	@:noCompletion override function __enterFrame(deltaTime:Int):Void
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
	}

	@:access(flixel.util.FlxTimerManager._timers)
	@:access(flixel.tweens.FlxTweenManager._tweens)
	@:noCompletion function update():Void
	{
		if (!__visible || __alpha == 0.0)
			return;

		final curMem = memoryMegas;
		if (curMem > memPeak)
			memPeak = curMem;

		var text = 'FPS: $currentFPS';
		var formatData = __textFormatList[0];
		formatData.format.color = switch (Std.int(currentFPS * 0.05)) // / 20
		{
			case 0:		0xFF0000; // < 20 fps
			case 1, 2:	FlxColor.interpolate(0xFF0000, 0xFFFFFF, (currentFPS - 20) * 0.025); // 20 - 59 fps
			default:	0xFFFFFF; // 60+ fps
		}
		formatData.end = text.length;

		text += "\nMemory: " + FlxStringUtil.formatBytes(curMem);
		if (debug)
			text += " [Peak: " + FlxStringUtil.formatBytes(memPeak) + "]";
		
		if (ClientPrefs.data.cacheOnGPU)
		{
			// fun fact: it doesn't work on my pc, cuz it doesn't have gl "NVX_gpu_memory_info" extension! - rich
			final gpuMem = memoryMegasGPU;
			if (gpuMem != 0)
				text += "\nGPU Memory: " + FlxStringUtil.formatBytes(gpuMem);
		}
		#if !RELESE_BUILD_FR
		if (debug)
		{
			text += "\n";
			// upate time info once a second
			final currentTime = times[times.length-1];
			if (__prevTime % 1000 > currentTime % 1000)
				__timeElapsed = __get__time__elapsed(currentTime * 0.001);

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

			text += '\nState: $__stateClass';
			if (FlxG.state.subState != null)
			{
				tmp = __get__substate__info(FlxG.state.subState);
				text += "\nSubstate";
				if (tmp.contains("->"))
					text += "s";
				text += ': $tmp';
			}

			final onPlayState = text.contains("PlayState") || text.contains("ChartingState");
			tmp = "Position: " + FlxStringUtil.formatTime(Conductor.songPosition * 0.001);
			if (onPlayState)
			{
				var t = "Song: " + PlayState.SONG.song.toLowerCase();
				final d = Difficulty.getString().toLowerCase();
				if (d != Difficulty.defaultDifficulty.toLowerCase())
					t += ' [$d]';
				tmp = '$t | $tmp/' + FlxStringUtil.formatTime(FlxG.sound.music.length * 0.001);
			}
			tmp += " | BPM: " + Conductor.bpm;
			if (onPlayState && Conductor.bpm != PlayState.SONG.bpm)
				tmp += " [" + PlayState.SONG.bpm + "]";
			text += '\nConductor: ($tmp)';

			text += "\nTweens: " + FlxTween.globalManager._tweens.length;
			text += "\nTimers: " + FlxTimer.globalManager._timers.length;

			text += '\n\nTime Elapsed: $__timeElapsed';
			text += '\nCommit #$commit';
			__prevTime = currentTime;
		}
		#end
		this.text = text;
		for (data in __textFormatList)
		{
			// if (__textEngine.textFormatRanges.indexOf(data) == -1)
			//	__textEngine.textFormatRanges.push(data);
			setTextFormat(data.format, data.start, data.end);
		}
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
		var __str = __get__state__class(__substate);
		__substate = __substate.subState;
		while (__substate != null)
		{
			__str += __get__state__class(__substate);
			__substate = __substate.subState;
			if (__substate != null)
				__str += " -> ";
		}
		return __str;
	}

	@:noCompletion inline function get_memoryMegas():Int
	{
		return cast (openfl.system.System.totalMemory, UInt);
	}

	@:noCompletion inline function get_memoryMegasGPU():Int
	{
		return FlxG.stage.context3D.totalGPUMemory;
	}
}
