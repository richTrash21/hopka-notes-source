package debug;

import flixel.FlxG;
import openfl.text.TextFormat;

/**
	The FPS class provides an easy-to-use monitor to display
	the current frame rate of an OpenFL project

	from: https://github.com/ShadowMario/FNF-PsychEngine/pull/13591
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
	public var memoryMegas(get, never):Float;

	@:noCompletion private var times:Array<Float>;
	@:noCompletion private var _color:Int;

	@:noCompletion public var changeColor:Bool;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		this.x = x;
		this.y = y;

		changeColor = true;
		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat("_sans", 12, color, true);
		autoSize = LEFT;
		multiline = true;
		text = "FPS: ";
		_color = color;

		times = [];
	}

	var deltaTimeout:Float = 0.0;
	@:noCompletion private var cacheCount:Int;

	// Event Handlers
	private override function __enterFrame(deltaTime:Float):Void
	{
		deltaTimeout += deltaTime;
		times.push(deltaTimeout);

		while (times[0] < deltaTimeout - 1000)
			times.shift();

		var currentCount = times.length;
		var roundedCount = Math.round((currentCount + cacheCount) * 0.5);
		currentFPS = (roundedCount < FlxG.drawFramerate) ? roundedCount : FlxG.drawFramerate;
		updateText();
		cacheCount = currentCount;

		/*if (deltaTimeout > 1000) {
			deltaTimeout = 0.0;
			return;
		}

		var now:Float = haxe.Timer.stamp();
		times.push(now);
		while (times[0] < now - 1000)
			times.shift();

		var currentCount:Int = times.length;
		currentFPS = (currentCount < FlxG.drawFramerate) ? currentCount : FlxG.drawFramerate;
		updateText();
		deltaTimeout += deltaTime;*/
	}

	public dynamic function updateText():Void { // so people can override it in hscript
		text = 'FPS: ${currentFPS}'
		+ '\nMemory: ${flixel.util.FlxStringUtil.formatBytes(memoryMegas)}';
		
		if (changeColor)
			textColor = (currentFPS < FlxG.drawFramerate * 0.5) ? 0xFFFF0000 : _color;
	}

	inline function get_memoryMegas():Float
		return cast(openfl.system.System.totalMemory, UInt);
}
