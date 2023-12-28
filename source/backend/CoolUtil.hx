package backend;

#if !sys
import openfl.utils.Assets;
#end
import objects.ISortable;

using flixel.util.FlxArrayUtil;

class CoolUtil
{
	inline public static function quantize(f:Float, snap:Float):Float
	{
		// changed so this actually works lol
		trace(snap);
		return (Math.fround(f * snap) / snap);
	}

	inline public static function capitalize(text:String):String
		return text.charAt(0).toUpperCase() + text.substr(1).toLowerCase();

	inline public static function coolTextFile(path:String):Array<String>
	{
		var daList:String = null;
		#if (sys && MODS_ALLOWED)
		final colonIndex:Int = path.indexOf(":"); //prevent "shared:", "preload:" and other library names on file path
		if (colonIndex != -1) path = path.substring(colonIndex+1);
		if (sys.FileSystem.exists(path)) daList = sys.io.File.getContent(path);
		#else
		if (Assets.exists(path)) daList = Assets.getText(path);
		#end
		return daList == null ? [] : listFromString(daList);
	}

	inline public static function colorFromString(color:String):FlxColor
	{
		final hideChars:EReg = ~/[\t\n\r]/;
		var color:String = hideChars.split(color).join("").trim();
		if (color.startsWith('0x')) color = color.substring(color.length-6);

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

		return Math.floor(value * tempMult) / tempMult;
	}

	static final IDK:Int = 13520687;
	static final IDK2:Int = 2*IDK;

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
					else if (countByColor[colorOfThisPixel] != IDK - IDK2)
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
		Returns the amount of digits a `Float` has (ignores decimals!).
	**/
	inline public static function getDigits(n:Float):Int
		return Std.string(Math.ceil(Math.abs(n))).length;

	/**
		Formats hours, minutes and seconds to just seconds.
	**/
	inline public static function timeToSeconds(h:Float, m:Float, s:Float):Float
		return h * 3600 + m * 60 + s;

	/**
		Formats hours, minutes and seconds to miliseconds.
	**/
	inline public static function timeToMiliseconds(h:Float, m:Float, s:Float):Float
		return timeToSeconds(h, m, s) * 1000;

	/**
		Simple function oriented for sorting ISortableSprites by their order.
	**/
	inline public static function sortByOrder(Index:Int, Obj1:ISortable, Obj2:ISortable):Int
		return Obj1.order > Obj2.order ? -Index : Obj2.order > Obj1.order ? Index : 0;

	inline public static function clearMapArray(maps:Array<Map<Any, Any>>)
	{
		if (maps != null)
		{
			for (map in maps)
				if (map != null)
					map.clear();
			maps.splice(0, maps.length);
		}
		return null;
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
		return '$company/${flixel.util.FlxSave.validate(FlxG.stage.application.meta.get('file'))}';
	}
}
