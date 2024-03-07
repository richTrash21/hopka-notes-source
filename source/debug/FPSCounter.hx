package debug;

import openfl.events.MouseEvent;
import openfl.events.FocusEvent;

import flixel.FlxG;

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
	public var currentFPS(default, null):Int;

	/**
		The current memory usage (WARNING: this is NOT your total program memory usage, rather it shows the garbage collector memory)
	**/
	public var memoryMegas(get, never):Int;

	@:noCompletion var times:Array<Float>;

	public function new(x = 10.0, y = 10.0):Void
	{
		super();

		this.x = x;
		this.y = y;

		currentFPS = 0;
		selectable = mouseEnabled = false;
		defaultTextFormat = new openfl.text.TextFormat("_sans", 12, 0xFFFFFF, true);
		autoSize = LEFT;
		multiline = true;
		text = "FPS: ";

		times = [];

		shader = new shaders.OutlineShader();

		// i think it is optimization -Redar
		removeEventListener(FocusEvent.FOCUS_IN, this_onFocusIn);
		removeEventListener(FocusEvent.FOCUS_OUT, this_onFocusOut);
		removeEventListener(MouseEvent.MOUSE_DOWN, this_onMouseDown);
		removeEventListener(MouseEvent.MOUSE_WHEEL, this_onMouseWheel);
		removeEventListener(MouseEvent.DOUBLE_CLICK, this_onDoubleClick);
		removeEventListener(openfl.events.KeyboardEvent.KEY_DOWN, this_onKeyDown);
	}

	@:noCompletion var deltaTimeout = 0;
	@:noCompletion var currentTime = 0;
	@:noCompletion var cacheCount = 0;

	// Event Handlers
	@:noCompletion override function __enterFrame(deltaTime:Int):Void
	{
		if (!visible || alpha == 0.0)
			return;

		currentTime += deltaTime;
		times.push(currentTime);
		while (times[0] < currentTime - 1000)
			times.shift();

		final currentCount = times.length;
		if (currentCount != cacheCount)
		{
			final newFPS = Std.int((currentCount + cacheCount) * .5);
			// caping new framerate to the maximum fps possible so it wont go above
			currentFPS = FlxMath.minInt(newFPS, FlxG.updateFramerate);
			cacheCount = currentCount;
		}
		updateText();
	}

	public dynamic function updateText():Void // so people can override it in hscript
	{
		text = 'FPS: $currentFPS\n';
		text += "Memory: " + flixel.util.FlxStringUtil.formatBytes(memoryMegas);
		textColor = (currentFPS < 30 /*FlxG.drawFramerate * 0.5*/) ? 0xFF0000 : 0xFFFFFF;
	}

	@:noCompletion inline function get_memoryMegas():Int
	{
		return cast (openfl.system.System.totalMemory, UInt);
	}
}
