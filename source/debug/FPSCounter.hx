package debug;

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

	@:noCompletion private var times:Array<Float>;
	@:noCompletion private var changeColor:Bool;
	@:noCompletion private var _color:Int;

	public function new(x = 10.0, y = 10.0, ?color = 0x000000, ?_changeColor = true):Void
	{
		super();

		this.x = x;
		this.y = y;

		changeColor = _changeColor;
		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new openfl.text.TextFormat("_sans", 12, color, true);
		autoSize = LEFT;
		multiline = true;
		text = "FPS: ";
		_color = color;

		times = [];

		shader = new shaders.OutlineShader();
	}

	@:noCompletion private var deltaTimeout = 0;
	@:noCompletion private var currentTime = 0;
	@:noCompletion private var cacheCount = 0;

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
		
		if (changeColor)
			textColor = (currentFPS < 30 /*FlxG.drawFramerate * 0.5*/) ? 0xFFFF0000 : _color;
	}

	@:noCompletion inline function get_memoryMegas():Int
	{
		return cast(openfl.system.System.totalMemory, UInt);
	}
}
