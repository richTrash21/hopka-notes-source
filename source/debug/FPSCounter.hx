package debug;

import flixel.util.FlxStringUtil;

@:allow(debug.DebugOverlay)
class FPSCounter extends DebugTextField
{
	@:noCompletion extern inline static final HIGH_FPS = 0xFFFFFF;
	@:noCompletion extern inline static final LOW_FPS = 0xFF0000;

	var currentFPS(default, null):Int = 0;
	var memoryMegas(get, never):Int;
	// var memoryMegasGPU(get, never):Int;

	@:noCompletion var __memPeak = 0;
	// @:noCompletion var __gpuPeak = 0;
	@:noCompletion var __fpsStyle:openfl.utils.Object;

	@:access(openfl.text.StyleSheet.__styles)
	public function new(x = 0.0, y = 0.0, ?followObject:openfl.text.TextField):Void
	{
		super(x, y, followObject);
		__textFormat.size += 1;

		// i hate StyleSheet.setStyle() all my homies hate StyleSheet.setStyle()
		__styleSheet.__styles.set("fps-text", __fpsStyle = {fontSize: __textFormat.size + 1, letterSpacing: 1, color: LOW_FPS.hex(6)});
		__styleSheet.__styles.set("mem-text", {fontSize: __textFormat.size + 1, letterSpacing: 1});
	}

	@:access(flixel.FlxGame._elapsedMS)
	override function flixelUpdate():Void
	{
		// ignores FlxG.timeScale
		currentFPS = __get__fps(currentFPS, FlxG.game._elapsedMS * 0.001);

		if (!__visible || __alpha == 0.0)
			return;

		_text = 'FPS:<fps-text> $currentFPS</fps-text>';
		__fpsStyle.color = (switch (Std.int(currentFPS * 0.05))
		{
			case 0:		LOW_FPS; // 0 - 20 fps
			case 1, 2:	FlxColor.interpolate(LOW_FPS, HIGH_FPS, (currentFPS - 20) * 0.025); // 20 - 59 fps
			default:	HIGH_FPS; // 60+ fps
		}).hex(8);

		final curMem = memoryMegas;
		if (curMem > __memPeak)
			__memPeak = curMem;

		_text += "\nMemory:<mem-text> " + FlxStringUtil.formatBytes(curMem);
		if (debug)
			_text += " || " + FlxStringUtil.formatBytes(__memPeak);
		_text += "</mem-text>";
		
		/*if (ClientPrefs.data.cacheOnGPU)
		{
			// fun fact: it doesn't work! - rich
			// UPD: works for redar ig
			// https://cdn.discordapp.com/attachments/1041755661630976052/1232710415029502046/image.png?ex=662a7289&is=66292109&hm=d8510a69d33d7df2c09d9f1ae4b61db12953760a3ca434fa3ac2c6b203fade25&
			final gpuMem = memoryMegasGPU;
			if (gpuMem > __gpuPeak)
				__gpuPeak = gpuMem;

			if (gpuMem != 0)
			{
				_text += "\nGPU Memory:<mem-text> " + FlxStringUtil.formatBytes(gpuMem);
				if (debug)
					_text += " || " + FlxStringUtil.formatBytes(__gpuPeak);
				_text += "</mem-text>";
			}
		}*/
		this.text = _text;
		super.flixelUpdate();
	}

	/**
		fps counting method from codename engine
		https://github.com/FNF-CNE-Devs/CodenameEngine/blob/main/source/funkin/backend/system/framerate/FramerateCounter.hx
	**/
	extern inline function __get__fps(__cur__fps:Int, __e:Float):Int
	{
		return FlxMath.minInt(Math.floor(FlxMath.lerp(__e == 0.0 ? 0.0 : 1.0 / __e, __cur__fps, Math.exp(-__e * 15.0))), FlxG.updateFramerate);
	}

	@:noCompletion inline function get_memoryMegas():Int
	{
		return #if cpp cast ( #end openfl.system.System.totalMemory #if cpp , UInt) #end ;
	}

	/*@:noCompletion inline function get_memoryMegasGPU():Int
	{
		return FlxG.stage.context3D == null ? 0 : FlxG.stage.context3D.totalGPUMemory;
	}*/
}
