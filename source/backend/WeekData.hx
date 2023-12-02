package backend;

#if MODS_ALLOWED
import sys.FileSystem;
#end

typedef WeekFile = {
	// JSON variables
	var ?realSongs:Array<SongData>;
	var ?songs:Array<Dynamic>; // for backward compability!!!!
	var weekCharacters:Array<String>;
	var weekBackground:String;
	var weekBefore:String;
	var storyName:String;
	var weekName:String;
	var freeplayColor:Array<Int>;
	var startUnlocked:Bool;
	var hiddenUntilUnlocked:Bool;
	var hideStoryMode:Bool;
	var hideFreeplay:Bool;
	var difficulties:String;
}

// instead of dynamic array
typedef SongData = {name:String, icon:String, colors:Array<Int>}

class WeekData
{
	public static var weeksLoaded:Map<String, WeekData> = [];
	public static var weeksList:Array<String> = [];
	public var folder:String = '';
	
	// JSON variables
	public var songs:Array<SongData>;
	public var weekCharacters:Array<String>;
	public var weekBackground:String;
	public var weekBefore:String;
	public var storyName:String;
	public var weekName:String;
	public var freeplayColor:Array<Int>;
	public var startUnlocked:Bool;
	public var hiddenUntilUnlocked:Bool;
	public var hideStoryMode:Bool;
	public var hideFreeplay:Bool;
	public var difficulties:String;

	public var fileName:String;

	public static final DEFAULT_WEEK:WeekFile = {
		realSongs: [
			{name: "Bopeebo",    icon: "dad", colors: [146, 113, 253]},
			{name: "Fresh",      icon: "dad", colors: [146, 113, 253]},
			{name: "Dad Battle", icon: "dad", colors: [146, 113, 253]}
		],
		weekCharacters: ['dad', 'bf', 'gf'],
		weekBackground: 'stage',
		weekBefore: 'tutorial',
		storyName: 'Your New Week',
		weekName: 'Custom Week',
		freeplayColor: [146, 113, 253],
		startUnlocked: true,
		hiddenUntilUnlocked: false,
		hideStoryMode: false,
		hideFreeplay: false,
		difficulties: ''
	};

	inline public static function createWeekFile():WeekFile return DEFAULT_WEEK;

	inline public static function fixWeek(Week:WeekFile):WeekFile
	{
		// GETTING RID OF DYNAMIC ARRAY SINCE ITS SHIIIIITT
		if (Week?.songs != null)
		{
			Week.realSongs = [for (shit in Week.songs) {name: shit[0], icon: shit[1], colors: shit[2]}];
			Reflect.deleteField(Week, "songs"); // i hope this won't backfire in like 2 seconds :clueless:
		}
		return Week;
	}

	// HELP: Is there any way to convert a WeekFile to WeekData without having to put all variables there manually? I'm kind of a noob in haxe lmao
	public function new(weekFile:WeekFile, fileName:String)
	{
		songs = weekFile.realSongs;
		weekCharacters = weekFile.weekCharacters;
		weekBackground = weekFile.weekBackground;
		weekBefore = weekFile.weekBefore;
		storyName = weekFile.storyName;
		weekName = weekFile.weekName;
		freeplayColor = weekFile.freeplayColor;
		startUnlocked = weekFile.startUnlocked;
		hiddenUntilUnlocked = weekFile.hiddenUntilUnlocked;
		hideStoryMode = weekFile.hideStoryMode;
		hideFreeplay = weekFile.hideFreeplay;
		difficulties = weekFile.difficulties;

		this.fileName = fileName;
	}

	public static function reloadWeekFiles(isStoryMode:Null<Bool> = false)
	{
		weeksList = [];
		weeksLoaded.clear();
		#if MODS_ALLOWED
		final directories:Array<String> = [Paths.mods(), Paths.getPreloadPath()];
		final originalLength:Int = directories.length;

		for (mod in Mods.parseList().enabled)
			directories.push(Paths.mods('$mod/'));
		#else
		final directories:Array<String> = [Paths.getPreloadPath()];
		final originalLength:Int = directories.length;
		#end

		final sexList:Array<String> = CoolUtil.coolTextFile(Paths.getPreloadPath('weeks/weekList.txt'));
		for (i in 0...sexList.length)
		{
			for (j in 0...directories.length)
			{
				final fileToCheck:String = directories[j] + 'weeks/' + sexList[i] + '.json';
				if (!weeksLoaded.exists(sexList[i]))
				{
					final week:WeekFile = getWeekFile(fileToCheck);
					if (week != null)
					{
						final weekFile:WeekData = new WeekData(week, sexList[i]);

						#if MODS_ALLOWED
						if (j >= originalLength)
							weekFile.folder = directories[j].substring(Paths.mods().length, directories[j].length-1);
						#end

						if (weekFile != null && (isStoryMode == null || (isStoryMode && !weekFile.hideStoryMode) || (!isStoryMode && !weekFile.hideFreeplay))) {
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
			final week:WeekFile = getWeekFile(path);
			if (week != null)
			{
				final weekFile:WeekData = new WeekData(week, weekToCheck);
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

		if (rawJson != null && rawJson.length > 0)
			return fixWeek(cast haxe.Json.parse(rawJson));

		return null;
	}

	//   FUNCTIONS YOU WILL PROBABLY NEVER NEED TO USE

	//To use on PlayState.hx or Highscore stuff
	inline public static function getWeekFileName():String
		return weeksList[PlayState.storyWeek];

	//Used on LoadingState, nothing really too relevant
	inline public static function getCurrentWeek():WeekData
		return weeksLoaded.get(weeksList[PlayState.storyWeek]);

	inline public static function setDirectoryFromWeek(?data:WeekData)
		return Mods.currentModDirectory = data != null && data.folder != null && data.folder.length > 0 ? data.folder : '';
}