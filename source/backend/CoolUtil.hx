package backend;

#if !sys
import openfl.utils.Assets;
#end

class CoolUtil
{
	/**
		Global game speed. Can be controlled outside of PlatState.
	**/
	public static var globalSpeed(get, set):Float;
	static var _globalSpeed:Float = 1.0; // internal tracker, for use outside of PlayState

	@:noCompletion inline static function get_globalSpeed():Float
		return (PlayState.instance != null ? PlayState.instance.playbackRate : _globalSpeed);

	@:noCompletion inline static function set_globalSpeed(speed:Float):Float
		return (PlayState.instance != null ? PlayState.instance.playbackRate : _globalSpeed = speed); // won't allow to set variable if camera placed in PlayState

	inline public static function quantize(f:Float, snap:Float):Float
	{
		// changed so this actually works lol
		final m:Float = Math.fround(f * snap);
		trace(snap);
		return (m / snap);
	}

	inline public static function capitalize(text:String):String
		return text.charAt(0).toUpperCase() + text.substr(1).toLowerCase();

	inline public static function coolTextFile(path:String):Array<String>
	{
		var daList:String = null;
		#if (sys && MODS_ALLOWED)
		final formatted:Array<String> = path.split(':'); //prevent "shared:", "preload:" and other library names on file path
		path = formatted[formatted.length-1];
		if (sys.FileSystem.exists(path)) daList = sys.io.File.getContent(path);
		#else
		if (Assets.exists(path)) daList = Assets.getText(path);
		#end
		return daList != null ? listFromString(daList) : [];
	}

	inline public static function colorFromString(color:String):FlxColor
	{
		final hideChars:EReg = ~/[\t\n\r]/;
		var color:String = hideChars.split(color).join('').trim();
		if (color.startsWith('0x')) color = color.substring(color.length - 6);

		final colorNum:Null<FlxColor> = FlxColor.fromString(color) ?? FlxColor.fromString('#$color');
		return colorNum ?? FlxColor.WHITE;
	}

	inline public static function listFromString(string:String):Array<String>
	{
		final daList:Array<String> = string.trim().split('\n');
		for (i in 0...daList.length) daList[i] = daList[i].trim();
		return daList;
	}

	public static function floorDecimal(value:Float, decimals:Int):Float
	{
		if (decimals < 1) return Math.floor(value);

		var tempMult:Float = 1;
		for (i in 0...decimals) tempMult *= 10;

		final newValue:Float = Math.floor(value * tempMult);
		return newValue / tempMult;
	}
	
	inline public static function dominantColor(sprite:flixel.FlxSprite):Int
	{
		final countByColor:Map<Int, Int> = [];
		for (col in 0...sprite.frameWidth)
			for (row in 0...sprite.frameHeight)
			{
				final colorOfThisPixel:Int = sprite.pixels.getPixel32(col, row);
				if (colorOfThisPixel != 0)
				{
					if (countByColor.exists(colorOfThisPixel))
						countByColor[colorOfThisPixel] = countByColor[colorOfThisPixel] + 1;
					else if (countByColor[colorOfThisPixel] != 13520687 - (2*13520687))
						countByColor[colorOfThisPixel] = 1;
				}
			}

		var maxCount:Int = 0;
		var maxKey:Int = 0; //after the loop this will store the max color
		countByColor[FlxColor.BLACK] = 0;
		for (key => color in countByColor)
			if (color >= maxCount)
			{
				maxCount = color;
				maxKey = key;
			}

		countByColor.clear();
		return maxKey;
	}

	inline public static function browserLoad(site:String)
	{
		#if linux
		Sys.command('/usr/bin/xdg-open', [site]);
		#else
		FlxG.openURL(site);
		#end
	}

	/**
		Helper Function to Fix Save Files for Flixel 5
		-- EDIT: [November 29, 2023] --
		this function is used to get the save path, period.
		since newer flixel versions are being enforced anyways.
		@crowplexus
	**/
	@:access(flixel.util.FlxSave.validate)
	inline public static function getSavePath():String
	{
		final company:String = FlxG.stage.application.meta.get('company');
		return '${company}/${flixel.util.FlxSave.validate(FlxG.stage.application.meta.get('file'))}';
	}
}
