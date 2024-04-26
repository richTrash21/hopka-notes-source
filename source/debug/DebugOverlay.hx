package debug;

import openfl.utils.Object;
import openfl.display.Bitmap;

// kinda like in Codename Engine
@:allow(debug.DebugInfo)
@:allow(debug.FPSCounter)
@:allow(debug.DebugTextField)
class DebugOverlay extends openfl.display.Sprite
{
	extern inline static final INFO_OFFSET = 2.0;
	extern inline static final PADDING_X = 8.0;
	extern inline static final PADDING_Y = 5.0;

	static final debugFont = Sys.getEnv("windir") + "\\Fonts\\consolab.ttf";

	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(get, never):Int;

	/**
		The current memory usage (WARNING: this is NOT your total program memory usage, rather it shows the garbage collector memory)
	**/
	public var memoryMegas(get, never):Int;

	/**
		**BETA**
		The current memory usage of GPU. (WARNING: this show ALL of GPU memory usage, not just for the game)
	**/
	// public var memoryMegasGPU(get, never):Int;

	public var debug = #if debug true #else false #end;

	var bg:Bitmap;
	var fps:FPSCounter;
	var info:DebugInfo;

	public function new()
	{
		super();

		addChild(bg = new Bitmap(new openfl.display.BitmapData(1, 1, 0x66000000)));
		addChild(fps = new FPSCounter(PADDING_X, PADDING_Y));
		addChild(info = new DebugInfo(PADDING_X));

		FlxG.signals.preUpdate.add(flixelUpdate);
		// scale overlay down if game was sized down
		FlxG.signals.gameResized.add((_, _) ->
		{
			scaleX = Math.min(FlxG.scaleMode.scale.x, 1.0);
			scaleY = Math.min(FlxG.scaleMode.scale.y, 1.0);
		});
		FlxG.stage.addEventListener(openfl.events.KeyboardEvent.KEY_DOWN, (e) ->
			if (e.keyCode == flixel.input.keyboard.FlxKey.F4)
			{
				debug = FlxG.save.data.debugInfo = !FlxG.save.data.debugInfo;
				FlxG.save.flush();
			});
	}

	@:access(openfl.text.StyleSheet.__styles)
	public function watch(label:String, value:Dynamic, ?field:String)
	{
		var id = -1;
		for (i => data in info.__extraData)
			if (data.label == label)
			{
				id = i;
				break;
			}

		if (field != null)
			value = Reflect.getProperty.bind(value, field);
		if (id == -1)
			info.__extraData.push([label, value]);
		else
			info.__extraData[id].value = value;
	}

	function flixelUpdate()
	{
		fps.flixelUpdate();
		info.flixelUpdate();
	}

	@:noCompletion override function __enterFrame(dt:Int)
	{
		fps.debug = info.visible = debug;
		super.__enterFrame(dt);

		var bgScaleX = PADDING_X * 2.0;
		var bgScaleY = PADDING_Y * 2.0;
		if (debug)
		{
			final infoY = fps.y + fps.height + INFO_OFFSET;
			info.y = infoY;
			bgScaleX += Math.max(fps.width, info.width);
			bgScaleY += Math.max(fps.height, infoY + info.height);
		}
		else
		{
			bgScaleX += fps.width;
			bgScaleY += fps.height;
		}
		bg.scaleX = bgScaleX;
		bg.scaleY = bgScaleY;
	}

	@:noCompletion inline function get_currentFPS():Int
	{
		return fps.currentFPS;
	}

	@:noCompletion inline function get_memoryMegas():Int
	{
		return fps.memoryMegas;
	}

	/*@:noCompletion inline function get_memoryMegasGPU():Int
	{
		return fps.memoryMegasGPU;
	}*/
}