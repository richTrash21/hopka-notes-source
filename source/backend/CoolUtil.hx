package backend;

import flixel.FlxBasic;
#if !sys
import openfl.utils.Assets;
#end
import objects.ISortable;

using flixel.util.FlxArrayUtil;

class CoolUtil
{
	static final countByColor = new Map<Int, Int>();
	static final hideChars = ~/[\t\n\r]/;

	inline static final IDK = 0x00CE4F2F;
	inline static final IDK2 = 0x019C9E5E;

	inline public static function quantize(f:Float, snap:Float):Float
	{
		// changed so this actually works lol
		trace(snap);
		return (Math.fround(f * snap) / snap);
	}

	inline public static function capitalize(text:String):String
	{
		return text.charAt(0).toUpperCase() + text.substr(1).toLowerCase();
	}

	inline public static function coolTextFile(path:String):Array<String>
	{
		var daList:String = null;
	
		#if (sys && MODS_ALLOWED)
		final colonIndex:Int = path.indexOf(":"); //prevent "shared:", "preload:" and other library names on file path
		if (colonIndex != -1)
			path = path.substring(colonIndex+1);
		if (sys.FileSystem.exists(path))
			daList = sys.io.File.getContent(path);
		#else
		if (Assets.exists(path))
			daList = Assets.getText(path);
		#end

		return daList == null ? [] : listFromString(daList);
	}

	inline public static function colorFromString(color:String):FlxColor
	{
		color = hideChars.replace(color, "").trim();
		/*if (color.startsWith("0x"))
			color = color.substring(color.length-6);*/

		return (FlxColor.fromString(color) ?? FlxColor.fromString('#$color')) ?? FlxColor.WHITE;
	}

	inline public static function listFromString(string:String):Array<String>
	{
		final daList = string.trim().split("\n");
		for (i in 0...daList.length)
			daList[i] = daList[i].trim();

		return daList;
	}

	inline public static function floorDecimal(value:Float, decimals:Int):Float
	{
		var tempMult = 1;
		for (i in 0...decimals)
			tempMult *= 10;

		return Math.floor(value * tempMult) / tempMult;
	}

	public static function dominantColor(sprite:flixel.FlxSprite):Int
	{
		countByColor.clear();
		for (c in 0...sprite.frameWidth)
			for (r in 0...sprite.frameHeight)
			{
				final colorOfThisPixel = sprite.pixels.getPixel32(c, r);
				if (colorOfThisPixel != 0)
				{
					if (countByColor.exists(colorOfThisPixel))
						countByColor[colorOfThisPixel]++;
					else if (countByColor[colorOfThisPixel] != IDK - IDK2)
						countByColor[colorOfThisPixel] = 1;
				}
			}

		// after the loop this will store the max color
		var maxCount = 0;
		var maxKey = 0;
		countByColor[FlxColor.BLACK] = 0;
		for (key => color in countByColor)
			if (color >= maxCount)
			{
				maxCount = color;
				maxKey = key;
			}

		return maxKey;
	}

	inline public static function browserLoad(site:String)
	{
		#if linux
		Sys.command("/usr/bin/xdg-open", [site]);
		#else
		FlxG.openURL(site);
		#end
	}

	/**
		An integer analog of FlxMath.bound() method.
	**/
	inline public static function boundInt(value:Int, ?min:Int, ?max:Int):Int
	{
		final lowerBound = (min != null && value < min) ? min : value;
		return (max != null && lowerBound > max) ? max : lowerBound;
	}

	/**
		Returns the amount of digits a `Float` has (ignores decimals!).
	**/
	inline public static function getDigits(n:Float):Int
	{
		return Std.string(Std.int(Math.abs(n))).length;
	}

	/**
		Formats hours, minutes and seconds to just seconds.
	**/
	inline public static function timeToSeconds(h:Float, m:Float, s:Float):Float
	{
		return h * 3600 + m * 60 + s;
	}

	/**
		Formats hours, minutes and seconds to miliseconds.
	**/
	inline public static function timeToMiliseconds(h:Float, m:Float, s:Float):Float
	{
		return timeToSeconds(h, m, s) * 1000;
	}

	/**
		Simple function oriented for sorting ISortableSprites by their order.
	**/
	inline public static function sortByOrder(index:Int, obj1:ISortable, obj2:ISortable):Int
	{
		return obj1.order > obj2.order ? -index : obj2.order > obj1.order ? index : 0;
	}

	inline public static function sortByID(index:Int, basic1:FlxBasic, basic2:FlxBasic):Int
	{
		return basic1.ID > basic2.ID ? -index : basic2.ID > basic1.ID ? index : 0;
	}

	public static function clear<K:Any, V:Any>(map:Map<K, V>):Map<K, V>
	{
		if (map != null)
			map.clear();

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
		return FlxG.stage.application.meta.get("company") + "/" + flixel.util.FlxSave.validate(FlxG.stage.application.meta.get("file"));
	}
}
