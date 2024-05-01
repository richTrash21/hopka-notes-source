package backend;

#if ACHIEVEMENTS_ALLOWED
import objects.AchievementPopup;

#if LUA_ALLOWED
import psychlua.FunkinLua;
#end

/*typedef Achievement =
{
	var name:String;
	var description:String;
	@:optional var hidden:Bool;
	@:optional var maxScore:Float;
	@:optional var maxDecimals:Int;

	// handled automatically, ignore these two
	@:optional var mod:String;
	@:optional var ID:Int;
}*/

@:structInit class Achievement
{
	public var name:String = "Achievement Name";
	public var description:String = "Achievement Description";
	@:optional public var hidden:Bool;
	@:optional public var maxScore:Float;
	@:optional public var maxDecimals:Int;

	// handled automatically, ignore these two
	@:optional public var mod:String;
	@:optional public var ID:Int;
}

class Achievements
{
	static function init()
	{
		createAchievement('friday_night_play',		{name: "Freaky on a Friday Night", description: "Play on a Friday... Night.", hidden: true});
		createAchievement('week1_nomiss',			{name: "She Calls Me Daddy Too", description: "Beat Week 1 on Hard with no Misses."});
		createAchievement('week2_nomiss',			{name: "No More Tricks", description: "Beat Week 2 on Hard with no Misses."});
		createAchievement('week3_nomiss',			{name: "Call Me The Hitman", description: "Beat Week 3 on Hard with no Misses."});
		createAchievement('week4_nomiss',			{name: "Lady Killer", description: "Beat Week 4 on Hard with no Misses."});
		createAchievement('week5_nomiss',			{name: "Missless Christmas", description: "Beat Week 5 on Hard with no Misses."});
		createAchievement('week6_nomiss',			{name: "Highscore!!", description: "Beat Week 6 on Hard with no Misses."});
		createAchievement('week7_nomiss',			{name: "God Effing Damn It!", description: "Beat Week 7 on Hard with no Misses."});
		createAchievement('ur_bad',					{name: "What a Funkin' Disaster!", description: "Complete a Song with a rating lower than 20%."});
		createAchievement('ur_good',				{name: "Perfectionist", description: "Complete a Song with a rating of 100%."});
		createAchievement('roadkill_enthusiast',	{name: "Roadkill Enthusiast", description: "Watch the Henchmen die 50 times.", maxScore: 50, maxDecimals: 0});
		createAchievement('oversinging', 			{name: "Oversinging Much...?", description: "Sing for 10 seconds without going back to Idle."});
		createAchievement('hype',					{name: "Hyperactive", description: "Finish a Song without going back to Idle."});
		createAchievement('two_keys',				{name: "Just the Two of Us", description: "Finish a Song pressing only two keys."});
		createAchievement('toastie',				{name: "Toaster Gamer", description: "Have you tried to run the game on a toaster?"});
		createAchievement('debugger',				{name: "Debugger", description: "Beat the \"Test\" Stage from the Chart Editor.", hidden: true});
		
		// dont delete this thing below
		_originalLength = ++_sortID;
	}

	public static var achievements:Map<String, Achievement> = [];
	public static var achievementsUnlocked:Array<String> = [];
	public static var variables:Map<String, Float> = [];
	static var _firstLoad = true;

	inline public static function get(name:String):Achievement
	{
		return achievements.get(name);
	}

	inline public static function exists(name:String):Bool
	{
		return achievements.exists(name);
	}

	public static function load():Void
	{
		if (!_firstLoad)
			return;

		if (_originalLength < 0)
			init();

		if (!FlxG.save.data.isEmpty())
		{
			if (FlxG.save.data.achievementsUnlocked != null)
				achievementsUnlocked = cast FlxG.save.data.achievementsUnlocked;

			final savedMap:Map<String, Float> = cast FlxG.save.data.achievementsVariables;
			if (savedMap != null)
				for (key => value in savedMap)
					variables.set(key, value);

			_firstLoad = false;
		}
	}

	inline public static function save():Void
	{
		FlxG.save.data.achievementsUnlocked = achievementsUnlocked;
		FlxG.save.data.achievementsVariables = variables;
	}
	
	inline public static function getScore(name:String):Float
	{
		return _scoreFunc(name, 0);
	}

	inline public static function setScore(name:String, value:Float, saveIfNotUnlocked = true):Float
	{
		return _scoreFunc(name, 1, value, saveIfNotUnlocked);
	}

	inline public static function addScore(name:String, value = 1., saveIfNotUnlocked = true):Float
	{
		return _scoreFunc(name, 2, value, saveIfNotUnlocked);
	}

	// mode 0 = get, 1 = set, 2 = add
	static function _scoreFunc(name:String, mode = 0, addOrSet = 1., saveIfNotUnlocked = true):Float
	{
		if (!variables.exists(name))
			variables.set(name, 0);

		if (!achievements.exists(name))
			return -1;

		final achievement = achievements.get(name);
		if (achievement.maxScore < 1)
			throw 'Achievement has score disabled or is incorrectly configured: $name';

		if (achievementsUnlocked.contains(name))
			return achievement.maxScore;

		if (mode == 0) // get
			return variables.get(name);

		var val = addOrSet;
		if (mode == 2) // add
			val += variables.get(name);

		if (val >= achievement.maxScore)
		{
			unlock(name);
			val = achievement.maxScore;
		}
		variables.set(name, val);

		Achievements.save();
		if (saveIfNotUnlocked || val == achievement.maxScore)
			FlxG.save.flush();

		return val;
	}

	static var _lastUnlock:Int = -999;
	public static function unlock(name:String, autoStartPopup:Bool = true):String
	{
		if (!achievements.exists(name))
		{
			FlxG.log.error('Achievement "$name" does not exists!');
			throw 'Achievement "$name" does not exists!';
		}

		if (Achievements.isUnlocked(name))
			return null;

		GameLog.notice('Completed achievement "$name"');
		achievementsUnlocked.push(name);

		// earrape prevention
		final time = openfl.Lib.getTimer();
		if (Math.abs(time - _lastUnlock) >= 100) // If last unlocked happened in less than 100 ms (0.1s) ago, then don't play sound
		{
			final sound = FlxG.sound.play(Paths.sound("confirmMenu"));
			sound.persist = true;
			sound.onComplete = () -> sound.persist = false;
			_lastUnlock = time;
		}

		Achievements.save();
		FlxG.save.flush();

		if (autoStartPopup)
			startPopup(name);

		return name;
	}

	inline public static function isUnlocked(name:String):Bool
	{
		return achievementsUnlocked.contains(name);
	}

	@:allow(objects.AchievementPopup)
	private static var _popups:Array<AchievementPopup> = [];

	public static var showingPopups(get, never):Bool;
	inline public static function get_showingPopups():Bool
	{
		return _popups.length > 0;
	}

	public static function startPopup(achieve:String/*, ?endFunc:()->Void*/)
	{
		for (popup in _popups)
			if (popup != null)
				popup.intendedY += 150;

		_popups.push(new AchievementPopup(achieve/*, endFunc*/));
		// GameLog.notice('Giving achievement ' + achieve);
	}

	// Map sorting cuz haxe is physically incapable of doing that by itself
	static var _sortID = 0;
	static var _originalLength = -1;
	public static function createAchievement(name:String, data:Achievement, ?mod:String)
	{
		data.ID = _sortID++;
		data.mod = mod;
		achievements.set(name, data);
	}

	#if MODS_ALLOWED
	public static function reloadList()
	{
		// remove modded achievements
		if (++_sortID > _originalLength)
			for (key => value in achievements)
				if (value.mod != null)
					achievements.remove(key);

		_sortID = _originalLength - 1;

		final modLoaded = Mods.currentModDirectory;
		Mods.currentModDirectory = null;
		loadAchievementJson(Paths.mods("data/achievements.json"));
		for (i => mod in Mods.parseList().enabled)
		{
			Mods.currentModDirectory = mod;
			loadAchievementJson(Paths.mods('$mod/data/achievements.json'));
		}
		Mods.currentModDirectory = modLoaded;
	}

	inline static function loadAchievementJson(path:String, addMods:Bool = true)
	{
		var retVal:Array<Dynamic> = null;
		if (sys.FileSystem.exists(path))
		{
			try
			{
				final rawJson = sys.io.File.getContent(path).trim();
				if (rawJson?.length > 0)
					retVal = haxe.Json.parse(rawJson);
				
				if (addMods && retVal != null)
				{
					for (i in 0...retVal.length)
					{
						final achieve:Dynamic = retVal[i];
						if (achieve == null)
						{
							final errorTitle = "Mod name: " + (Mods.currentModDirectory ?? "None");
							final errorMsg = 'Achievement #${i+1} is invalid.';
							#if windows
							lime.app.Application.current.window.alert(errorMsg, errorTitle);
							#end
							GameLog.error('$errorTitle - $errorMsg');
							continue;
						}

						var key:String = achieve.save;
						if (key == null || key.trim().length < 1)
						{
							var errorTitle = "Error on Achievement: " + (achieve.name ?? achieve.save);
							var errorMsg = 'Missing valid "save" value.';
							#if windows
							lime.app.Application.current.window.alert(errorMsg, errorTitle);
							#end
							GameLog.error('$errorTitle - $errorMsg');
							continue;
						}
						key = key.trim();
						if (achievements.exists(key))
							continue;

						createAchievement(key, achieve, Mods.currentModDirectory);
					}
				}
			}
			catch(e)
			{
				final errorTitle = "Mod name: " + (Mods.currentModDirectory ?? "None");
				final errorMsg = 'Error loading achievements.json: $e';
				#if windows
				lime.app.Application.current.window.alert(errorMsg, errorTitle);
				#end
				GameLog.error('$errorTitle - $errorMsg');
			}
		}
		return retVal;
	}
	#end

	#if LUA_ALLOWED
	public static function implement(lua:FunkinLua)
	{
		lua.set("getAchievementScore", (name:String) ->
		{
			if (achievements.exists(name))
				return getScore(name);

			FunkinLua.luaTrace('getAchievementScore: Couldnt find achievement: $name', false, false, FlxColor.RED);
			return -1;
		});
		lua.set("setAchievementScore", (name:String, ?value:Float = 1, ?saveIfNotUnlocked:Bool = true) ->
		{
			if (achievements.exists(name))
				return setScore(name, value, saveIfNotUnlocked);

			FunkinLua.luaTrace('setAchievementScore: Couldnt find achievement: $name', false, false, FlxColor.RED);
			return -1;
		});
		lua.set("addAchievementScore", (name:String, ?value:Float = 1, ?saveIfNotUnlocked:Bool = true) ->
		{
			if (achievements.exists(name))
				return addScore(name, value, saveIfNotUnlocked);

			FunkinLua.luaTrace('addAchievementScore: Couldnt find achievement: $name', false, false, FlxColor.RED);
			return -1;
		});
		lua.set("unlockAchievement", (name:String) ->
		{
			if (achievements.exists(name))
				return unlock(name);

			FunkinLua.luaTrace('unlockAchievement: Couldnt find achievement: $name', false, false, FlxColor.RED);
			return null;
		});
		lua.set("isAchievementUnlocked", (name:String) ->
		{
			if (!achievements.exists(name))
				FunkinLua.luaTrace('isAchievementUnlocked: Couldnt find achievement: $name', false, false, FlxColor.RED);

			return isUnlocked(name);
		});
		lua.set("achievementExists", achievements.exists);
	}
	#end
}
#end