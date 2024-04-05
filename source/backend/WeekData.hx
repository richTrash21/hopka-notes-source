package backend;

#if MODS_ALLOWED
import sys.FileSystem;
#end

import haxe.extern.EitherType;

typedef WeekFile = {
	// JSON variables
	var songs:Array<WeekSongData>;
	var weekCharacters:Array<String>;
	var weekBackground:String;
	var weekBefore:String;
	var storyName:String;
	var weekName:String;
	// var freeplayColor:Array<Int>;
	var startUnlocked:Bool;
	var hiddenUntilUnlocked:Bool;
	var hideStoryMode:Bool;
	var hideFreeplay:Bool;
	var difficulties:String;
}

abstract WeekSongData(Array<EitherType<String, Array<Int>>>) from Array<EitherType<String, Array<Int>>> to Array<EitherType<String, Array<Int>>>
{
	public var songName(get, set):String;
	public var iconName(get, set):String;
	public var bgColor(get, set):FlxColor;

	@:noCompletion inline function get_songName():String	return this[0];
	@:noCompletion inline function get_iconName():String	return this[1];
	@:noCompletion inline function get_bgColor():FlxColor	return this[2] == null ? 0xFF9271FD :FlxColor.fromRGB(this[2][0], this[2][1], this[2][2]);

	@:noCompletion inline function set_songName(v:String):String	return this[0] = v;
	@:noCompletion inline function set_iconName(v:String):String	return this[1] = v;
	@:noCompletion inline function set_bgColor(v:FlxColor):FlxColor
	{
		if (this[2] == null)
			this[2] = [v.red, v.green, v.blue];
		else
		{
			this[2][0] = v.red;
			this[2][1] = v.green;
			this[2][2] = v.blue;
		}
		return v;
	}
}

class WeekData
{
	public static var weeksLoaded:Map<String, WeekData> = [];
	public static var weeksList:Array<String> = [];
	
	// JSON variables
	public var songs:Array<WeekSongData>;
	public var weekCharacters:Array<String>;
	public var weekBackground:String;
	public var weekBefore:String;
	public var storyName:String;
	public var weekName:String;
	// public var freeplayColor:Array<Int>;
	public var startUnlocked:Bool;
	public var hiddenUntilUnlocked:Bool;
	public var hideStoryMode:Bool;
	public var hideFreeplay:Bool;
	public var difficulties:String;

	public var folder:String = "";
	public var fileName:String = "";

	public static final DEFAULT_WEEK:WeekFile = {
		songs: [
			["Bopeebo",	   "dad", [146, 113, 253]],
			["Fresh",	   "dad", [146, 113, 253]],
			["Dad Battle", "dad", [146, 113, 253]]
		],
		weekCharacters: ['dad', 'bf', 'gf'],
		weekBackground: 'stage',
		weekBefore: 'tutorial',
		storyName: 'Your New Week',
		weekName: 'Custom Week',
		// freeplayColor: [146, 113, 253],
		startUnlocked: true,
		hiddenUntilUnlocked: false,
		hideStoryMode: false,
		hideFreeplay: false,
		difficulties: ""
	};

	inline public static function createWeekFile():WeekFile return DEFAULT_WEEK;

	public function new(weekFile:WeekFile, fileName:String)
	{
		// doesn't need that
		if (Reflect.hasField(weekFile, "freeplayColor"))
			Reflect.deleteField(weekFile, "freeplayColor");

		// by MiguelItsOut
		for (field in Reflect.fields(weekFile))
			Reflect.setField(this, field, Reflect.field(weekFile, field));

		this.fileName = fileName;
	}

	public static function reloadWeekFiles(?isStoryMode:Bool = false)
	{
		weeksList = [];
		weeksLoaded.clear();
		#if MODS_ALLOWED
		final directories:Array<String> = [Paths.mods(), Paths.getSharedPath()];
		final originalLength:Int = directories.length;

		for (mod in Mods.parseList().enabled)
			directories.push(Paths.mods('$mod/'));
		#else
		final directories:Array<String> = [Paths.getSharedPath()];
		final originalLength:Int = directories.length;
		#end

		final sexList:Array<String> = CoolUtil.coolTextFile(Paths.getSharedPath('weeks/weekList.txt'));
		for (i in 0...sexList.length)
		{
			for (j in 0...directories.length)
			{
				final fileToCheck:String = directories[j] + 'weeks/' + sexList[i] + '.json';
				if (!weeksLoaded.exists(sexList[i]))
				{
					final week = getWeekFile(fileToCheck);
					if (week != null)
					{
						final weekFile = new WeekData(week, sexList[i]);
						#if MODS_ALLOWED
						if (j >= originalLength)
							weekFile.folder = directories[j].substring(Paths.mods().length, directories[j].length-1);
						#end

						if ((isStoryMode && !weekFile.hideStoryMode) || (!isStoryMode && !weekFile.hideFreeplay))
						{
							weeksLoaded.set(sexList[i], weekFile);
							weeksList.push(sexList[i]);
						}
					}
				}
			}
		}

		#if MODS_ALLOWED
		for (i in 0...directories.length)
		{
			final directory:String = directories[i] + 'weeks/';
			if (FileSystem.exists(directory))
			{
				final listOfWeeks:Array<String> = CoolUtil.coolTextFile(directory + 'weekList.txt');
				for (daWeek in listOfWeeks)
				{
					final path:String = directory + 'daWeek.json';
					if (sys.FileSystem.exists(path))
						addWeek(daWeek, path, directories[i], i, originalLength);
				}

				for (file in FileSystem.readDirectory(directory))
				{
					final path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
						addWeek(file.substr(0, file.length - 5), path, directories[i], i, originalLength);
				}
			}
		}
		#end
	}

	private static function addWeek(weekToCheck:String, path:String, directory:String, i:Int, originalLength:Int)
	{
		if (!weeksLoaded.exists(weekToCheck))
		{
			final week = getWeekFile(path);
			if (week != null)
			{
				final weekFile = new WeekData(week, weekToCheck);
				if (i >= originalLength)
				{
					#if MODS_ALLOWED
					weekFile.folder = directory.substring(Paths.mods().length, directory.length-1);
					#end
				}
				if ((PlayState.isStoryMode && !weekFile.hideStoryMode) || (!PlayState.isStoryMode && !weekFile.hideFreeplay))
				{
					weeksLoaded.set(weekToCheck, weekFile);
					weeksList.push(weekToCheck);
				}
			}
		}
	}

	inline private static function getWeekFile(path:String):WeekFile
	{
		var rawJson:String = null;
		#if MODS_ALLOWED
		if (FileSystem.exists(path))
			rawJson = sys.io.File.getContent(path);
		#else
		if (openfl.utils.Assets.exists(path))
			rawJson = lime.utils.Assets.getText(path);
		#end

		return rawJson?.length > 0 ? cast haxe.Json.parse(rawJson) : null;
	}

	//   FUNCTIONS YOU WILL PROBABLY NEVER NEED TO USE

	//To use on PlayState.hx or Highscore stuff
	inline public static function getWeekFileName():String
	{
		return weeksList[PlayState.storyWeek];
	}

	//Used on LoadingState, nothing really too relevant
	inline public static function getCurrentWeek():WeekData
	{
		return weeksLoaded.get(weeksList[PlayState.storyWeek]);
	}

	inline public static function setDirectoryFromWeek(?data:WeekData)
	{
		return Mods.currentModDirectory = data?.folder?.length > 0 ? data.folder : "";
	}
}