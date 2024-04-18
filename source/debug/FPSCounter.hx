package debug;

import openfl.events.KeyboardEvent;
import openfl.events.FocusEvent;
import openfl.events.MouseEvent;
import openfl.text.TextFormat;
import openfl.text.StyleSheet;

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
	@:noCompletion extern inline static final HIGH_FPS = 0xFFFFFF;
	@:noCompletion extern inline static final LOW_FPS = 0xFF0000;

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
	public var debug = #if debug true #else false #end;

	@:noCompletion var __prevTime = 0;
	@:noCompletion var __timeElapsed:String;
	@:noCompletion var __stateClass:String;
	#end

	@:allow(Main) @:noCompletion var commit:String;
	@:noCompletion var times = new Array<Int>();
	@:noCompletion var cacheCount = 0;
	@:noCompletion var memPeak = 0;
	@:noCompletion var gpuPeak = 0;

	public function new(x = 10.0, y = 10.0):Void
	{
		super();
		this.x = x;
		this.y = y;

		selectable = mouseEnabled = false;
		defaultTextFormat = new TextFormat("_sans", 12, 0xFFFFFF, true);
		multiline = true;
		autoSize = LEFT;
		// for better visibility
		shader = new shaders.OutlineShader();

		styleSheet = new StyleSheet();
		styleSheet.setStyle("fps-text", {fontSize: __textFormat.size + 1, letterSpacing: 1, color: LOW_FPS.hex(6)});
		styleSheet.setStyle("mem-text", {fontSize: __textFormat.size + 1, letterSpacing: 1});

		// i think it is optimization - Redar
		removeEventListener(FocusEvent.FOCUS_IN, this_onFocusIn);
		removeEventListener(FocusEvent.FOCUS_OUT, this_onFocusOut);
		removeEventListener(MouseEvent.MOUSE_DOWN, this_onMouseDown);
		removeEventListener(MouseEvent.MOUSE_WHEEL, this_onMouseWheel);
		removeEventListener(MouseEvent.DOUBLE_CLICK, this_onDoubleClick);
		removeEventListener(KeyboardEvent.KEY_DOWN, this_onKeyDown);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, (e) ->
			if (e.keyCode == flixel.input.keyboard.FlxKey.F4)
			{
				debug = FlxG.save.data.debugInfo = !FlxG.save.data.debugInfo;
				FlxG.save.flush();
			}
		);

		FlxG.signals.preUpdate.add(update);
		#if !RELESE_BUILD_FR
		FlxG.signals.preStateCreate.add((s) -> __stateClass = __get__state__class(s));
		#end
		__timeElapsed = __get__time__elapsed(0);
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

		var text = 'FPS:<fps-text> $currentFPS</fps-text>';
		styleSheet.getStyle("fps-text").color = (switch (Std.int(currentFPS * 0.05))
		{
			case 0:		LOW_FPS; // 0 - 20 fps
			case 1, 2:	FlxColor.interpolate(LOW_FPS, HIGH_FPS, (currentFPS - 20) * 0.025); // 20 - 59 fps
			default:	HIGH_FPS; // 60+ fps
		}).hex(8);

		final curMem = memoryMegas;
		if (curMem > memPeak)
			memPeak = curMem;

		text += "\nMemory:<mem-text> " + FlxStringUtil.formatBytes(curMem);
		if (debug)
			text += " || " + FlxStringUtil.formatBytes(memPeak);
		text += "</mem-text>";
		
		if (ClientPrefs.data.cacheOnGPU)
		{
			// fun fact: it doesn't work! - rich
			final gpuMem = memoryMegasGPU;
			if (gpuMem > gpuPeak)
				gpuPeak = gpuMem;

			if (gpuMem != 0)
			{
				text += "\nGPU Memory:<mem-text> " + FlxStringUtil.formatBytes(gpuMem);
				if (debug)
					text += " || " + FlxStringUtil.formatBytes(gpuPeak);
				text += "</mem-text>";
			}
		}
		#if !RELESE_BUILD_FR
		if (debug)
		{
			var tmp:String;
			text += "\n";

			// upate time info once a second
			final currentTime = times[times.length-1];
			if (__prevTime % 1000 > currentTime % 1000)
				__timeElapsed = __get__time__elapsed(currentTime * 0.001);

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

			text += "\n\nVolume: " + FlxG.sound.volume;
			if (FlxG.sound.muted)
				text += " [muted]";
			if (DiscordClient.user != null)
				text += "\nDiscord User: " + DiscordClient.user;
			text += '\nTime Elapsed: $__timeElapsed';
			text += '\nCommit #$commit';
			__prevTime = currentTime;
		}
		#end
		this.text = text;
	}

	@:noCompletion inline function get_memoryMegas():Int
	{
		final mem = openfl.system.System.totalMemory;
		return #if cpp cast (mem, UInt) #else mem #end;
	}

	@:noCompletion inline function get_memoryMegasGPU():Int
	{
		return FlxG.stage.context3D == null ? 0 : FlxG.stage.context3D.totalGPUMemory;
	}
}
