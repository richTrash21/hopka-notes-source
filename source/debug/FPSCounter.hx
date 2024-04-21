package debug;

import flixel.util.FlxStringUtil;
import flixel.FlxState;

@:allow(debug.DebugOverlay)
class FPSCounter extends DebugTextField
{
	@:noCompletion extern inline static final HIGH_FPS = 0xFFFFFF;
	@:noCompletion extern inline static final LOW_FPS = 0xFF0000;

	var currentFPS(default, null):Int = 0;
	var memoryMegas(get, never):Int;
	var memoryMegasGPU(get, never):Int;

	@:noCompletion var lastTime = 0.0;
	@:noCompletion var memPeak = 0;
	@:noCompletion var gpuPeak = 0;

	public function new(x = 0.0, y = 0.0):Void
	{
		super(x, y);
		__textFormat.size += 1;

		styleSheet = new openfl.text.StyleSheet();
		styleSheet.setStyle("fps-text", {fontSize: __textFormat.size + 1, letterSpacing: 1, color: LOW_FPS.hex(6)});
		styleSheet.setStyle("mem-text", {fontSize: __textFormat.size + 1, letterSpacing: 1});
	}

	@:access(flixel.FlxGame._elapsedMS)
	override function flixelUpdate():Void
	{
		// ignores FlxG.timeScale
		currentFPS = __calc__fps(FlxG.game._elapsedMS * 0.001);

		if (!__visible || __alpha == 0.0)
			return;

		_text = 'FPS:<fps-text> $currentFPS</fps-text>';
		styleSheet.getStyle("fps-text").color = (switch (Std.int(currentFPS * 0.05))
		{
			case 0:		LOW_FPS; // 0 - 20 fps
			case 1, 2:	FlxColor.interpolate(LOW_FPS, HIGH_FPS, (currentFPS - 20) * 0.025); // 20 - 59 fps
			default:	HIGH_FPS; // 60+ fps
		}).hex(8);

		final curMem = memoryMegas;
		if (curMem > memPeak)
			memPeak = curMem;

		_text += "\nMemory:<mem-text> " + FlxStringUtil.formatBytes(curMem);
		if (debug)
			_text += " || " + FlxStringUtil.formatBytes(memPeak);
		_text += "</mem-text>";
		
		if (ClientPrefs.data.cacheOnGPU)
		{
			// fun fact: it doesn't work! - rich
			final gpuMem = memoryMegasGPU;
			if (gpuMem > gpuPeak)
				gpuPeak = gpuMem;

			if (gpuMem != 0)
			{
				_text += "\nGPU Memory:<mem-text> " + FlxStringUtil.formatBytes(gpuMem);
				if (debug)
					_text += " || " + FlxStringUtil.formatBytes(gpuPeak);
				_text += "</mem-text>";
			}
		}
		this.text = _text;
	}

	/**
		fps counting method from codename engine
		https://github.com/FNF-CNE-Devs/CodenameEngine/blob/main/source/funkin/backend/system/framerate/FramerateCounter.hx
	**/
	extern inline function __calc__fps(__e:Float):Int
	{
		return FlxMath.minInt(Math.floor(FlxMath.lerp(__e == 0.0 ? 0.0 : 1.0 / __e, currentFPS, Math.exp(-__e * 15.0))), FlxG.updateFramerate);
	}

	@:noCompletion inline function get_memoryMegas():Int
	{
		return #if cpp cast ( #end openfl.system.System.totalMemory #if cpp , UInt) #end ;
	}

	@:noCompletion inline function get_memoryMegasGPU():Int
	{
		return FlxG.stage.context3D == null ? 0 : FlxG.stage.context3D.totalGPUMemory;
	}
}
