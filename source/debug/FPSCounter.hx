package debug;

import flixel.FlxG;

/**
	The FPS class provides an easy-to-use monitor to display
	the current frame rate of an OpenFL project

	from: https://github.com/ShadowMario/FNF-PsychEngine/pull/13591 (merged with new psych lmao)
	UPD: added fix https://github.com/ShadowMario/FNF-PsychEngine/pull/13865
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
	@:noCompletion private var changeColor:Bool;
	@:noCompletion private var _color:Int;

	public function new(x:Float = 10.0, y:Float = 10.0, ?color:Int = 0x000000, ?_changeColor:Bool = true):Void
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
	}

	@:noCompletion private var deltaTimeout:Float = 0.0;
	//@:noCompletion private var cacheCount:Int;

	// Event Handlers
	@:noCompletion override function __enterFrame(deltaTime:Float):Void
	{
		if (!visible || alpha == 0.0) return;

		/*deltaTimeout += deltaTime;
		times.push(deltaTimeout);

		while (times[0] < deltaTimeout - 1000)
			times.shift();

		final currentCount = times.length;
		final roundedCount = Math.round((currentCount + cacheCount) * 0.5);
		currentFPS = (roundedCount < FlxG.updateFramerate) ? roundedCount : FlxG.updateFramerate;
		updateText();
		cacheCount = currentCount;*/
		
		// prevents the overlay from updating every frame, why would you need to anyways
		if (deltaTimeout > 1000.0)
		{
			deltaTimeout = 0.0;
			return;
		}

		final now:Float = haxe.Timer.stamp() * 1000;
		times.push(now);
		while (times[0] < now - 1000.0) times.shift();

		currentFPS = FlxMath.minInt(times.length, FlxG.updateFramerate);
		updateText();
		deltaTimeout += deltaTime;
	}

	/** i was tired of fps text not having a shadow cuz can't see a thing in bright areas **/
	/*@:noCompletion override private function __update(transformOnly:Bool, updateChildren:Bool):Void
	{
		final realColor:Int = textColor;
		final posX:Float = x;
		final posY:Float = y;

		var i:Int = 4;
		var multX:Int = 0;
		var multY:Int = 0;
		textColor = 0x000000;
		while (i-- > 0) // drawing shadow, prob hella expensive but idk (MEMORY LEAKS [✔])
		{
			multX = (i == 3 || i == 1) ? -1 : 1;
			multY = (i == 2 || i == 0) ? -1 : 1;

			x = posX + multX;
			y = posY + multY;
			super.__update(transformOnly, updateChildren);
		}
		x = posX;
		y = posY;
		textColor = realColor;
		super.__update(transformOnly, updateChildren);
	}*/

	public dynamic function updateText():Void // so people can override it in hscript
	{
		text = 'FPS: $currentFPS\nMemory: ${flixel.util.FlxStringUtil.formatBytes(memoryMegas)}';
		
		if (changeColor)
			textColor = (currentFPS < FlxG.drawFramerate * 0.5) ? 0xFFFF0000 : _color;
	}

	inline function get_memoryMegas():Float
		return cast(openfl.system.System.totalMemory, UInt);
}
