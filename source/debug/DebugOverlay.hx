package debug;

import openfl.display.Bitmap;

// kinda like in Codename Engine
@:allow(debug.DebugInfo)
@:allow(debug.FPSCounter)
@:allow(ebug.DebugBuildInfo)
@:allow(debug.DebugTextField)
class DebugOverlay extends openfl.display.Sprite
{
	extern public inline static final DEBUG_MODES = 3;
	extern public inline static final INFO_OFFSET = 2.0;
	extern public inline static final PADDING_X = 8.0;
	extern public inline static final PADDING_Y = 5.0;

	public static final debugFont = Sys.getEnv("windir") + "\\Fonts\\consolab.ttf";

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

	public var debug = #if debug 2 #else 0 #end;

	var bg:Bitmap;
	var fps:FPSCounter;
	var info:DebugInfo;
	var buildInfo:DebugBuildInfo;
	var list = new Array<DebugTextField>();

	public function new()
	{
		super();

		if (FlxG.save.data.debugInfo != null)
			debug = FlxG.save.data.debugInfo;

		addChild(bg = new Bitmap(new openfl.display.BitmapData(1, 1, 0x66000000)));
		addToList(fps = new FPSCounter(PADDING_X, PADDING_Y));
		addToList(info = new DebugInfo(fps));
		addToList(buildInfo = new DebugBuildInfo(info));

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
				if (FlxG.save.data.debugInfo == null)
					FlxG.save.data.debugInfo = debug;
				else if (FlxG.save.data.debugInfo is Bool)
					FlxG.save.data.debugInfo = FlxG.save.data.debugInfo ? 1 : 0;

				debug = (FlxG.save.data.debugInfo = ++FlxG.save.data.debugInfo % DEBUG_MODES);
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
		fps.debug = info.visible = debug > 0;
		buildInfo.visible = debug > 1;

		var bgWidth = 0.0, bgHeight = 0.0;
		for (item in list)
		{
			item.flixelUpdate();
			if (!item.visible || item.alpha == 0.0)
				continue;

			bgWidth  = Math.max(bgWidth, item.x + item.width);
			bgHeight = Math.max(bgHeight, item.y + item.height);
		}

		bg.scaleX = bgWidth  + PADDING_X;
		bg.scaleY = bgHeight + PADDING_Y;
	}

	inline public function addToList(item:DebugTextField):DebugTextField
	{
		if (item != null)
		{
			list.push(item);
			addChild(item);
		}
		return item;
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