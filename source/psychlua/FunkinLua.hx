package psychlua;

import flixel.util.FlxAxes;
import flixel.util.FlxDestroyUtil;
import backend.WeekData;
import backend.Highscore;
import backend.Song;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.math.FlxPoint;
import flixel.util.FlxGradient;
import flixel.addons.transition.FlxTransitionableState;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import cutscenes.DialogueBoxPsych;

import objects.StrumNote;
import objects.Note;
import objects.NoteSplash;
import objects.ExtendedSprite;

import states.MainMenuState;
import states.StoryMenuState;
import states.FreeplayState;

import substates.PauseSubState;
import substates.GameOverSubstate;

import psychlua.LuaUtils;
import psychlua.LuaUtils.LuaTweenOptions;
import psychlua.HScript;

#if LUA_ALLOWED
import llua.*;
import llua.Lua;
#end

class FunkinLua
{
	public static final Function_Stop:Dynamic		 = "##PSYCHLUA_FUNCTIONSTOP";
	public static final Function_Continue:Dynamic	 = "##PSYCHLUA_FUNCTIONCONTINUE";
	public static final Function_StopLua:Dynamic	 = "##PSYCHLUA_FUNCTIONSTOPLUA";
	public static final Function_StopHScript:Dynamic = "##PSYCHLUA_FUNCTIONSTOPHSCRIPT";
	public static final Function_StopAll:Dynamic	 = "##PSYCHLUA_FUNCTIONSTOPALL";

	/*public static final Function_Stop:FunctionReturn		 = STOP;
	public static final Function_Continue:FunctionReturn	 = CONTINUE;
	public static final Function_StopLua:FunctionReturn		 = STOP_LUA;
	public static final Function_StopHScript:FunctionReturn	 = STOP_HSCRIPT;
	public static final Function_StopAll:FunctionReturn		 = STOP_ALL;*/

	#if LUA_ALLOWED
	public var lua:State = null;
	#end
	public var scriptName:String = "";
	public var closed:Bool = false;
	public var hscript:HScript = null;
	
	public var callbacks:Map<String, Dynamic> = [];
	public static var customFunctions:Map<String, Dynamic> = [];

	public function new(scriptName:String)
	{
		#if LUA_ALLOWED
		var times = openfl.Lib.getTimer();
		this.scriptName = scriptName;
		lua = LuaL.newstate();
		LuaL.openlibs(lua);

		final game = PlayState.instance;
		game.luaArray.push(this);

		// Lua shit
		set("Function_StopLua",		 Function_StopLua);
		set("Function_StopHScript",	 Function_StopHScript);
		set("Function_StopAll",		 Function_StopAll);
		set("Function_Stop",		 Function_Stop);
		set("Function_Continue",	 Function_Continue);
		set("luaDebugMode",			 false);
		set("luaDeprecatedWarnings", true);
		set("inChartEditor",		 PlayState.chartingMode); // made it actually usefull now

		// Song/Week shit
		set("curBpm",		Conductor.bpm);
		set("bpm",			PlayState.SONG.bpm);
		set("scrollSpeed",	PlayState.SONG.speed);
		set("crochet",		Conductor.crochet);
		set("stepCrochet",	Conductor.stepCrochet);
		set("songLength",	FlxG.sound.music.length);

		set("songName",			PlayState.SONG.song);
		set("songPath",			Paths.formatToSongPath(PlayState.SONG.song));
		set("startedCountdown",	false);
		set("curStage",			PlayState.SONG.stage);

		set("isStoryMode", PlayState.isStoryMode);
		set("difficulty",  PlayState.storyDifficulty);

		final _diff = Difficulty.getString();
		set("difficultyName",	_diff);
		set("difficultyPath",	Paths.formatToSongPath(_diff));
		set("weekRaw",			PlayState.storyWeek);
		set("week",				WeekData.weeksList[PlayState.storyWeek]);
		set("seenCutscene",		PlayState.seenCutscene);
		set("hasVocals",		PlayState.SONG.needsVoices);

		// Camera poo
		set("cameraX", 0);
		set("cameraY", 0);

		// Screen stuff
		set("screenWidth",  FlxG.width);
		set("screenHeight", FlxG.height);

		// PlayState cringe ass nae nae bullcrap
		set("curSection", 0);
		set("curBeat", 0);
		set("curStep", 0);
		set("curDecBeat", 0);
		set("curDecStep", 0);

		set("score", 0);
		set("misses", 0);
		set("hits", 0);
		set("combo", 0);

		set("rating", 0);
		set("ratingName", "");
		set("ratingFC", "");
		set("version", MainMenuState.psychEngineVersion);

		set("inGameOver",		false);
		set("mustHitSection",	false);
		set("altAnim",			false);
		set("gfSection",		false);

		// Gameplay settings
		set("healthGainMult",	game.healthGain);
		set("healthLossMult",	game.healthLoss);
		#if FLX_PITCH
		set("playbackRate",		game.playbackRate);
		#end
		set("instakillOnMiss",	game.instakillOnMiss);
		set("botPlay",			game.cpuControlled);
		set("practice",			game.practiceMode);

		for (i in 0...4)
		{
			set('defaultPlayerStrumX$i', 0);
			set('defaultPlayerStrumY$i', 0);
			set('defaultOpponentStrumX$i', 0);
			set('defaultOpponentStrumY$i', 0);
		}

		// Default character positions woooo
		set("defaultBoyfriendX",  game.BF_POS.x);
		set("defaultBoyfriendY",  game.BF_POS.y);
		set("defaultOpponentX",   game.DAD_POS.x);
		set("defaultOpponentY",   game.DAD_POS.y);
		set("defaultGirlfriendX", game.GF_POS.x);
		set("defaultGirlfriendY", game.GF_POS.y);

		// Character shit
		set("boyfriendName", PlayState.SONG.player1);
		set("dadName",		 PlayState.SONG.player2);
		set("gfName",		 PlayState.SONG.gfVersion);

		// Some settings, no jokes
		set("downscroll", 			ClientPrefs.data.downScroll);
		set("middlescroll",			ClientPrefs.data.middleScroll);
		set("camScript",			ClientPrefs.data.camScript);
		set("camScriptNote",		ClientPrefs.data.camScriptNote);
		set("framerate",			ClientPrefs.data.framerate);
		set("ghostTapping",			ClientPrefs.data.ghostTapping);
		set("hideHud",				ClientPrefs.data.hideHud);
		set("timeBarType",			ClientPrefs.data.timeBarType);
		set("scoreZoom",			ClientPrefs.data.scoreZoom);
		set("cameraZoomOnBeat",		ClientPrefs.data.camZooms);
		set("flashingLights",		ClientPrefs.data.flashing);
		set("noteOffset",			ClientPrefs.data.noteOffset);
		set("healthBarAlpha",		ClientPrefs.data.healthBarAlpha);
		set("noResetButton",		ClientPrefs.data.noReset);
		set("lowQuality",			ClientPrefs.data.lowQuality);
		set("shadersEnabled", 		ClientPrefs.data.shaders);
		set("scriptName",			scriptName);
		set("currentModDirectory",	Mods.currentModDirectory);

		// Noteskin/Splash
		set("noteSkin",			 ClientPrefs.data.noteSkin);
		set("noteSkinPostfix",	 Note.getNoteSkinPostfix());
		set("splashSkin",		 ClientPrefs.data.splashSkin);
		set("splashSkinPostfix", NoteSplash.getSplashSkinPostfix());
		set("splashAlpha",		 ClientPrefs.data.splashAlpha);
		set("buildTarget",		 LuaUtils.getBuildTarget());

		for (name => func in customFunctions)
			if (func != null)
				set(name, func);

		set("getRunningScripts", () -> [for (script in game.luaArray) script.scriptName]);
		
		addLocalCallback("setOnScripts", (varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) ->
		{
			if (exclusions == null)
				exclusions = [];
			if (ignoreSelf && !exclusions.contains(scriptName))
				exclusions.push(scriptName);

			game.setOnScripts(varName, arg, exclusions);
		});
		addLocalCallback("setOnHScript", (varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) ->
		{
			if (exclusions == null)
				exclusions = [];
			if (ignoreSelf && !exclusions.contains(scriptName))
				exclusions.push(scriptName);

			game.setOnHScript(varName, arg, exclusions);
		});
		addLocalCallback("setOnLuas", (varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) ->
		{
			if (exclusions == null)
				exclusions = [];
			if (ignoreSelf && !exclusions.contains(scriptName))
				exclusions.push(scriptName);

			game.setOnLuas(varName, arg, exclusions);
		});

		addLocalCallback("callOnScripts", (funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true,
				?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) ->
		{
			if (excludeScripts == null)
				excludeScripts = [];
			if (ignoreSelf && !excludeScripts.contains(scriptName))
				excludeScripts.push(scriptName);

			game.callOnScripts(funcName, args, ignoreStops, excludeScripts, excludeValues);
			return true;
		});
		addLocalCallback("callOnLuas", (funcName:String, ?args:Array<Dynamic>, ?ignoreStops = false, ?ignoreSelf = true,
				?excludeScripts:Array<String>, ?excludeValues:Array<Dynamic>) ->
		{
			if (excludeScripts == null)
				excludeScripts = [];
			if (ignoreSelf && !excludeScripts.contains(scriptName))
				excludeScripts.push(scriptName);

			game.callOnLuas(funcName, args, ignoreStops, excludeScripts, excludeValues);
			return true;
		});
		addLocalCallback("callOnHScript", (funcName:String, ?args:Array<Dynamic>, ?ignoreStops = false, ?ignoreSelf = true,
				?excludeScripts:Array<String>, ?excludeValues:Array<Dynamic>) ->
		{
			if (excludeScripts == null)
				excludeScripts = [];
			if (ignoreSelf && !excludeScripts.contains(scriptName))
				excludeScripts.push(scriptName);

			game.callOnHScript(funcName, args, ignoreStops, excludeScripts, excludeValues);
			return true;
		});

		set("callScript", (script:String, funcName:String, ?args:Array<Dynamic> = null) ->
		{
			if (args == null)
				args = [];

			final foundScript = findScript(script);
			if (foundScript != null)
				for (luaInstance in game.luaArray)
					if (luaInstance.scriptName == foundScript)
					{
						luaInstance.call(funcName, args);
						return;
					}
		});

		set("getGlobalFromScript", (luaFile:String, global:String) -> // returns the global from a script
		{
			final foundScript:String = findScript(luaFile);
			if (foundScript != null)
				for (luaInstance in game.luaArray)
					if (luaInstance.scriptName == foundScript)
					{
						Lua.getglobal(luaInstance.lua, global);
						if (Lua.isnumber(luaInstance.lua,-1))
							Lua.pushnumber(lua, Lua.tonumber(luaInstance.lua, -1));
						else if (Lua.isstring(luaInstance.lua,-1))
							Lua.pushstring(lua, Lua.tostring(luaInstance.lua, -1));
						else if (Lua.isboolean(luaInstance.lua,-1))
							Lua.pushboolean(lua, Lua.toboolean(luaInstance.lua, -1));
						else
							Lua.pushnil(lua);

						// TODO: table

						Lua.pop(luaInstance.lua,1); // remove the global

						return;
					}
		});
		set("setGlobalFromScript", (luaFile:String, global:String, val:Dynamic) -> // returns the global from a script
		{
			final foundScript:String = findScript(luaFile);
			if (foundScript != null)
				for (luaInstance in game.luaArray)
					if(luaInstance.scriptName == foundScript)
						luaInstance.set(global, val);
		});
		/*set("getGlobals", (luaFile:String) -> // returns a copy of the specified file's globals
		{
			var foundScript:String = findScript(luaFile);
			if(foundScript != null)
			{
				for (luaInstance in game.luaArray)
				{
					if(luaInstance.scriptName == foundScript)
					{
						Lua.newtable(lua);
						var tableIdx = Lua.gettop(lua);

						Lua.pushvalue(luaInstance.lua, Lua.LUA_GLOBALSINDEX);
						while(Lua.next(luaInstance.lua, -2) != 0) {
							// key = -2
							// value = -1

							var pop:Int = 0;

							// Manual conversion
							// first we convert the key
							if(Lua.isnumber(luaInstance.lua,-2)){
								Lua.pushnumber(lua, Lua.tonumber(luaInstance.lua, -2));
								pop++;
							}else if(Lua.isstring(luaInstance.lua,-2)){
								Lua.pushstring(lua, Lua.tostring(luaInstance.lua, -2));
								pop++;
							}else if(Lua.isboolean(luaInstance.lua,-2)){
								Lua.pushboolean(lua, Lua.toboolean(luaInstance.lua, -2));
								pop++;
							}
							// TODO: table


							// then the value
							if(Lua.isnumber(luaInstance.lua,-1)){
								Lua.pushnumber(lua, Lua.tonumber(luaInstance.lua, -1));
								pop++;
							}else if(Lua.isstring(luaInstance.lua,-1)){
								Lua.pushstring(lua, Lua.tostring(luaInstance.lua, -1));
								pop++;
							}else if(Lua.isboolean(luaInstance.lua,-1)){
								Lua.pushboolean(lua, Lua.toboolean(luaInstance.lua, -1));
								pop++;
							}
							// TODO: table

							if(pop==2)Lua.rawset(lua, tableIdx); // then set it
							Lua.pop(luaInstance.lua, 1); // for the loop
						}
						Lua.pop(luaInstance.lua,1); // end the loop entirely
						Lua.pushvalue(lua, tableIdx); // push the table onto the stack so it gets returned

						return;
					}

				}
			}
		});*/
		set("isRunning", (luaFile:String) ->
		{
			final foundScript:String = findScript(luaFile);
			if (foundScript != null)
				for (luaInstance in game.luaArray)
					if (luaInstance.scriptName == foundScript)
						return true;

			return false;
		});

		set("setVar", game.variables.set);
		set("getVar", game.variables.get);

		set("addLuaScript", (luaFile:String, ?ignoreAlreadyRunning:Bool = false) -> //would be dope asf.
		{
			final foundScript:String = findScript(luaFile);
			if (foundScript != null)
			{
				if (!ignoreAlreadyRunning)
					for (luaInstance in game.luaArray)
						if (luaInstance.scriptName == foundScript)
						{
							luaTrace('addLuaScript: The script "$foundScript" is already running!');
							return;
						}

				new FunkinLua(foundScript);
				return;
			}
			luaTrace("addLuaScript: Script doesn't exist!", false, false, FlxColor.RED);
		});
		set("addHScript", (hxFile:String, ?ignoreAlreadyRunning:Bool = false) ->
		{
			#if HSCRIPT_ALLOWED
			final foundScript:String = findScript(hxFile, ".hx");
			if (foundScript != null)
			{
				if (!ignoreAlreadyRunning)
					for (script in game.hscriptArray)
						if (script.origin == foundScript)
						{
							luaTrace('addHScript: The script "$foundScript" is already running!');
							return;
						}

				game.initHScript(foundScript);
				return;
			}
			luaTrace("addHScript: Script doesn't exist!", false, false, FlxColor.RED);
			#else
			luaTrace("addHScript: HScript is not supported on this platform!", false, false, FlxColor.RED);
			#end
		});
		set("removeLuaScript", (luaFile:String, ?ignoreAlreadyRunning:Bool = false) ->
		{
			final foundScript:String = findScript(luaFile);
			if (foundScript != null)
				if (!ignoreAlreadyRunning)
					for (luaInstance in game.luaArray)
						if (luaInstance.scriptName == foundScript)
						{
							luaInstance.stop();
							trace("Closing script " + luaInstance.scriptName);
							return true;
						}
			luaTrace('removeLuaScript: Script $luaFile isn\'t running!', false, false, FlxColor.RED);
			return false;
		});

		set("loadSong", (?name:String, ?difficultyNum:Int = -1) ->
		{
			if (name == null || name.length == 0)
				name = PlayState.SONG.song;
			if (difficultyNum == -1)
				difficultyNum = PlayState.storyDifficulty;

			Song.loadFromJson(Highscore.formatSong(name, difficultyNum), name, PlayState.SONG);
			PlayState.storyDifficulty = difficultyNum;
			game.persistentUpdate = false;
			LoadingState.loadAndSwitchState(new PlayState());

			FlxG.sound.music.pause();
			FlxG.sound.music.volume = 0;
			game.vocals.pause();
			game.vocals.volume = 0;
			FlxG.camera.followLerp = 0;
		});

		set("loadGraphic", (variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0) ->
		{
			final split = variable.split(".");
			final spr:FlxSprite = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			if (spr != null && image != null && image.length > 0)
				spr.loadGraphic(Paths.image(image), gridX != 0 || gridY != 0, gridX, gridY);
		});
		set("loadFrames", (variable:String, image:String, spriteType:String = "sparrow") ->
		{
			final split = variable.split(".");
			final spr:FlxSprite = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			if (spr != null && image != null && image.length > 0)
				spr.frames = LuaUtils.loadFrames(image, spriteType);
		});

		//shitass stuff for epic coders like me B)  *image of obama giving himself a medal*
		set("getObjectOrder", (obj:String) ->
		{
			final split = obj.split(".");
			final basic:FlxBasic = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			final ret = LuaUtils.getTargetInstance().members.indexOf(basic);
			if (ret == -1)
				luaTrace('getObjectOrder: Object $obj doesn\'t exist!', false, false, FlxColor.RED);

			return ret;
		});
		set("setObjectOrder", (obj:String, position:Int) ->
		{
			final split = obj.split(".");
			final basic:FlxBasic = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			if (basic == null)
			{
				luaTrace('setObjectOrder: Object $obj doesn\'t exist!', false, false, FlxColor.RED);
				return;
			}
			final instance = LuaUtils.getTargetInstance();
			instance.insert(position, instance.remove(basic, true));
		});

		// gay ass tweens
		set("startTween", (tag:String, vars:String, ?values:Any, duration:Float, ?options:Any) ->
		{
			final penisExam:Dynamic = LuaUtils.tweenPrepare(tag, vars);
			final notFound = penisExam == null;
			if (notFound || values == null)
			{
				luaTrace("startTween: " + (notFound ? 'Couldnt find object: $vars' : "No values on 2nd argument!"), false, false, FlxColor.RED);
				return;
			}

			final myOptions = LuaUtils.getLuaTween(options);
			final tweenOptions:TweenOptions = {
				type:		myOptions.type,
				ease:		myOptions.ease,
				startDelay:	myOptions.startDelay,
				loopDelay:	myOptions.loopDelay
			};

			if (myOptions.onUpdate != null)
				tweenOptions.onUpdate = (_) -> game.callOnLuas(myOptions.onUpdate, [tag, vars]);

			if (myOptions.onStart != null)
				tweenOptions.onStart = (_) -> game.callOnLuas(myOptions.onStart, [tag, vars]);

			function removeTween(t:FlxTween, tag:String)
			{
				if (t.type == FlxTweenType.ONESHOT || t.type == FlxTweenType.BACKWARD)
					game.modchartTweens.remove(tag);
			}

			tweenOptions.onComplete = (myOptions.onComplete == null)
				? removeTween.bind(_, tag)
				: (t) -> { game.callOnLuas(myOptions.onComplete, [tag, vars]); removeTween(t, tag); }

			try
			{
				final t = FlxTween.tween(penisExam, values, duration, tweenOptions);
				game.modchartTweens.set(tag, t);
			}
			catch(e)
				luaTrace('startTween: Tween error for $vars: $e', true, false, FlxColor.RED);
		});

		set("doTweenColor", (tag:String, vars:String, targetColor:String, duration:Float, ease:String) ->
		{
			final spr:FlxSprite = LuaUtils.tweenPrepare(tag, vars);
			if (spr == null)
			{
				luaTrace('doTweenColor: Couldnt find object: $vars', false, false, FlxColor.RED);
				return;
			}

			var curColor = spr.color;
			// curColor.alphaFloat = spr.alpha; // um???????
			game.modchartTweens.set(tag, FlxTween.color(spr, duration, curColor, CoolUtil.colorFromString(targetColor),
			{
				ease: LuaUtils.getTweenEaseByString(ease),
				onComplete: (_) ->
				{
					game.modchartTweens.remove(tag);
					game.callOnLuas("onTweenCompleted", [tag, vars]);
				}
			}));	
		});			

		// quick VarTween setup
		for (f in ["x", "y", "angle", "alpha", "zoom"])
		{
			set("doTween" + CoolUtil.capitalize(f), oldTweenFunction.bind(_, _, _, _, _, f));
			set("noteTween" + CoolUtil.capitalize(f), noteTweenFunction.bind(_, _, _, _, _, f));
		}

		set("cancelTween", LuaUtils.cancelTween);

		set("mouseClicked", (button:String) ->
			switch (button)
			{
				case "middle":	FlxG.mouse.justPressedMiddle;
				case "right":	FlxG.mouse.justPressedRight;
				default:		FlxG.mouse.justPressed;
			}
		);
		set("mousePressed", (button:String) ->
			switch (button)
			{
				case "middle":	FlxG.mouse.pressedMiddle;
				case "right":	FlxG.mouse.pressedRight;
				default:		FlxG.mouse.pressed;
			}
		);
		set("mouseReleased", (button:String) ->
			switch (button)
			{
				case "middle":	FlxG.mouse.justReleasedMiddle;
				case "right":	FlxG.mouse.justReleasedRight;
				default:		FlxG.mouse.justReleased;
			}
		);

		set("runTimer", (tag:String, time:Float = 1, loops:Int = 1) ->
		{
			LuaUtils.cancelTimer(tag);
			game.modchartTimers.set(tag, new FlxTimer().start(time, (tmr) ->
			{
				if (tmr.finished)
					game.modchartTimers.remove(tag);
				game.callOnLuas("onTimerCompleted", [tag, tmr.loops, tmr.loopsLeft]);
			}, loops));
		});
		set("cancelTimer", LuaUtils.cancelTimer);

		//stupid bietch ass functions
		set("addScore", (value:Int = 0) ->
		{
			game.songScore += value;
			game.recalculateRating();
		});
		set("addMisses", (value:Int = 0) ->
		{
			game.songMisses += value;
			game.recalculateRating();
		});
		set("addHits", (value:Int = 0) ->
		{
			game.songHits += value;
			game.recalculateRating();
		});
		set("setScore", (value:Int = 0) ->
		{
			game.songScore = value;
			game.recalculateRating();
		});
		set("setMisses", (value:Int = 0) ->
		{
			game.songMisses = value;
			game.recalculateRating();
		});
		set("setHits", (value:Int = 0) ->
		{
			game.songHits = value;
			game.recalculateRating();
		});

		set("getScore",  () -> game.songScore);
		set("getMisses", () -> game.songMisses);
		set("getHits",   () -> game.songHits);

		set("setHealth", (value:Float = 0) -> game.health = value);
		set("addHealth", (value:Float = 0) -> game.health += value);
		set("getHealth", 				() -> game.health);

		// Identical functions
		set("FlxColor", 			FlxColor.fromString);
		set("getColorFromName", 	FlxColor.fromString);
		set("getColorFromString", 	FlxColor.fromString);
		set("getColorFromHex", 		(color:String) -> FlxColor.fromString('#$color'));

		// precaching
		set("addCharacterToList", (name:String, type:String) ->
			game.addCharacterToList(name,
				switch (type.toLowerCase())
				{
					case "dad" | "opponent" | "1":	1;
					case "gf" | "girlfriend" | "2":	2;
					default:						0;
				})
		);
		set("precacheImage", Paths.image);
		set("precacheSound", Paths.sound);
		set("precacheMusic", Paths.music);

		// others
		set("triggerEvent", (name:String, arg1:Any, arg2:Any) -> game.triggerEvent(name, arg1, arg2));

		set("startCountdown", game.startCountdown);
		set("endSong", () ->
		{
			game.KillNotes();
			return game.endSong();
		});
		set("restartSong", (?skipTransition:Bool = false) ->
		{
			game.persistentUpdate = false;
			// FlxG.camera.followLerp = 0;
			PauseSubState.restartSong(skipTransition);
			return true;
		});
		set("exitSong", (?skipTransition:Bool = false) ->
		{
			if (skipTransition)
				FlxTransitionableState.skipNextTransIn = FlxTransitionableState.skipNextTransOut = true;

			PlayState.cancelMusicFadeTween();
			MusicBeatState.switchState(PlayState.isStoryMode ? StoryMenuState.new : FreeplayState.new);
			#if hxdiscord_rpc
			DiscordClient.resetClientID();
			#end

			FlxG.sound.playMusic(Paths.music("freakyMenu"));
			PlayState.changedDifficulty = false;
			PlayState.chartingMode = false;
			game.transitioning = true;
			// FlxG.camera.followLerp = 0;
			Mods.loadTopMod();
			return true;
		});
		set("getSongPosition", () -> Conductor.songPosition);

		set("getCharacterX", (type:String) ->
			switch (type.toLowerCase())
			{
				case "dad" | "opponent" | "1":	 game.dadGroup.x;
				case "gf" | "girlfriend" | "2":	 game.gfGroup.x;
				default:						 game.boyfriendGroup.x;
			}
		);
		set("setCharacterX", (type:String, value:Float) ->
			switch (type.toLowerCase())
			{
				case "dad" | "opponent" | "1":	game.dadGroup.x = value;
				case "gf" | "girlfriend" | "2":	game.gfGroup.x = value;
				default:						game.boyfriendGroup.x = value;
			}
		);
		set("getCharacterY", (type:String) ->
			switch (type.toLowerCase())
			{
				case "dad" | "opponent" | "1":	 game.dadGroup.y;
				case "gf" | "girlfriend" | "2":	 game.gfGroup.y;
				default:						 game.boyfriendGroup.y;
			}
		);
		set("setCharacterY", (type:String, value:Float) ->
			switch (type.toLowerCase())
			{
				case "dad" | "opponent" | "1":	 game.dadGroup.y = value;
				case "gf" | "girlfriend" | "2":	 game.gfGroup.y = value;
				default:						 game.boyfriendGroup.y = value;
			}
		);

		set("cameraSetTarget", game.moveCamera);
		set("cameraShake", (camera:String, intensity:Float, duration:Float) ->
			LuaUtils.cameraFromString(camera).shake(intensity, duration)
		);
		set("cameraFlash", (camera:String, color:LuaColor, duration:Float,forced:Bool) ->
			LuaUtils.cameraFromString(camera).flash(LuaUtils.resolveColor(color), duration, forced)
		);
		set("cameraFade", (camera:String, color:LuaColor, duration:Float, forced:Bool, fadeIn:Bool) ->
			LuaUtils.cameraFromString(camera).fade(LuaUtils.resolveColor(color), duration, fadeIn, forced)
		);

		set("setRatingPercent",		(value:Float)  -> game.ratingPercent = value);
		set("setRatingName",		(value:String) -> game.ratingName = value);
		set("setRatingFC",			(value:String) -> game.ratingFC = value);

		set("getMouseX",			LuaUtils.getMousePoint.bind(_, false));
		set("getMouseY",			LuaUtils.getMousePoint.bind(_, true));

		set("getMidpointX",			LuaUtils.getPoint.bind(_, 0, false));
		set("getMidpointY",			LuaUtils.getPoint.bind(_, 0, true));
		set("getGraphicMidpointX",	LuaUtils.getPoint.bind(_, 1, false));
		set("getGraphicMidpointY",	LuaUtils.getPoint.bind(_, 1, true));
		set("getScreenPositionX",	LuaUtils.getPoint.bind(_, 2, false, _));
		set("getScreenPositionY",	LuaUtils.getPoint.bind(_, 2, true,  _));

		set("characterDance", (character:String, force:Bool = false) ->
		{
			final char = switch (character.toLowerCase())
			{
				case "dad" | "opponent" | "1":	game.dad;
				case "gf" | "girlfriend" | "2":	game.gf;
				default:						game.boyfriend;
			}
			if (char != null)
				char.dance(force);
		});

		set("makeLuaSprite", (tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?animated:Bool = false, ?spriteType:String = "sparrow") ->
		{
			tag = tag.replace(".", "");
			LuaUtils.resetSpriteTag(tag);
			final spr = new ExtendedSprite(x, y, image);
			if (animated)
				spr.frames = LuaUtils.loadFrames(image, spriteType);

			game.modchartSprites.set(tag, spr);
		});
		set("makeAnimatedLuaSprite", (tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?spriteType:String = "sparrow") ->
		{
			FunkinLua.luaTrace("makeAnimatedLuaSprite is deprecated! Use makeLuaSprite instead", false, true); // just wanted to merge them
			tag = tag.replace(".", "");
			LuaUtils.resetSpriteTag(tag);
			final spr = new ExtendedSprite(x, y);
			spr.frames = LuaUtils.loadFrames(image, spriteType);
			game.modchartSprites.set(tag, spr);
		});

		set("makeGraphic", (obj:String, width:Int = 256, height:Int = 256, ?color:LuaColor) ->
		{
			final spr:FlxSprite = LuaUtils.getObjectDirectly(obj, false);
			if (spr != null)
				spr.makeGraphic(width, height, color == null ? FlxColor.WHITE : LuaUtils.resolveColor(color));
		});
		set("makeGradient", (obj:String, width:Int = 256, height:Int = 256, ?colors:Array<LuaColor>, angle:Int = 90, chunkSize:Int = 1, interpolate:Bool = false) ->
		{
			final spr:FlxSprite = LuaUtils.getObjectDirectly(obj, false);
			if (spr == null)
				return;

			if (colors == null || colors.length < 2)
				colors = [FlxColor.WHITE, FlxColor.BLACK];
			spr.pixels = FlxGradient.createGradientBitmapData(width, height, [for (penis in colors) LuaUtils.resolveColor(penis)], chunkSize, angle, interpolate);
		});

		set("addAnimationByPrefix", (obj:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true) ->
		{
			final spr:FlxSprite = LuaUtils.getObjectDirectly(obj, false);
			if (spr == null)
				return false;

			spr.animation.addByPrefix(name, prefix, framerate, loop);
			if (spr.animation.curAnim == null)
				(spr is ExtendedSprite ? cast (spr, ExtendedSprite).playAnim : spr.animation.play)(name, true);

			return true;
		});

		set("addAnimation", (obj:String, name:String, frames:Array<Int>, framerate:Int = 24, loop:Bool = true) ->
		{
			final spr:FlxSprite = LuaUtils.getObjectDirectly(obj, false);
			if (spr == null)
				return false;

			spr.animation.add(name, frames, framerate, loop);
			if (spr.animation.curAnim == null)
				(spr is ExtendedSprite ? cast (spr, ExtendedSprite).playAnim : spr.animation.play)(name, true);

			return true;
		});

		set("addAnimationByIndices", LuaUtils.addAnimByIndices);

		set("playAnim", (obj:String, name:String, forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0) ->
		{
			final spr:FlxSprite = LuaUtils.getObjectDirectly(obj, false);
			(spr is ExtendedSprite ? cast (spr, ExtendedSprite).playAnim : spr.animation.play)(name, forced, reverse, startFrame);
			return true;
		});
		set("addOffset", (obj:String, anim:String, x:Float, y:Float) ->
		{
			final spr:ExtendedSprite = LuaUtils.getObjectDirectly(obj, false);
			if (spr == null)
				return false;

			spr.addOffset(anim, x, y);
			return true;
		});
		set("setOffset", (obj:String, ?x:Float, ?y:Float) ->
		{
			final spr:FlxSprite = LuaUtils.getObjectDirectly(obj, false);
			if (spr == null)
				return false;

			final setX = x != null;
			final setY = y != null;

			if (setX)
				spr.offset.x = x;
			if (setY)
				spr.offset.y = y;

			return (setX || setY);
		});

		set("setScrollFactor", (obj:String, scrollX:Float, scrollY:Float) ->
		{
			var object:FlxObject = game.getLuaObject(obj,false);
			if (object != null)
			{
				object.scrollFactor.set(scrollX, scrollY);
				return;
			}

			object = Reflect.getProperty(LuaUtils.getTargetInstance(), obj);
			if (object != null)
				object.scrollFactor.set(scrollX, scrollY);
		});
		set("addLuaSprite", (tag:String, front:Bool = false) ->
		{
			if (!game.modchartSprites.exists(tag))
				return;

			final spr:ExtendedSprite = game.modchartSprites.get(tag);
			if (front)
				LuaUtils.getTargetInstance().add(spr);
			else
			{
				if (game.isDead)
					GameOverSubstate.instance.insert(GameOverSubstate.instance.members.indexOf(GameOverSubstate.instance.boyfriend), spr);
				else
					game.insert(game.members.indexOf(LuaUtils.getLowestCharacterGroup()), spr);
			}
		});
		set("setGraphicSize", (obj:String, x:Int, y:Int = 0, updateHitbox:Bool = true) ->
		{
			var spr:FlxSprite = game.getLuaObject(obj);
			if (spr != null)
			{
				spr.setGraphicSize(x, y);
				if (updateHitbox)
					spr.updateHitbox();
				return;
			}

			final split = obj.split(".");
			spr = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			if (spr != null)
			{
				spr.setGraphicSize(x, y);
				if (updateHitbox)
					spr.updateHitbox();
				return;
			}
			luaTrace('setGraphicSize: Couldnt find object: $obj', false, false, FlxColor.RED);
		});
		set("scaleObject", (obj:String, x:Float, y:Float, updateHitbox:Bool = true) ->
		{
			var spr:FlxSprite = game.getLuaObject(obj);
			if (spr != null)
			{
				spr.scale.set(x, y);
				if (updateHitbox)
					spr.updateHitbox();
				return;
			}

			final split = obj.split(".");
			spr = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			if (spr != null)
			{
				spr.scale.set(x, y);
				if (updateHitbox)
					spr.updateHitbox();
				return;
			}
			luaTrace('scaleObject: Couldnt find object: $obj', false, false, FlxColor.RED);
		});
		set("updateHitbox", (obj:String) ->
		{
			var spr:FlxSprite = game.getLuaObject(obj);
			if (spr != null)
				return spr.updateHitbox();

			spr = Reflect.getProperty(LuaUtils.getTargetInstance(), obj);
			if (spr != null)
				return spr.updateHitbox();

			luaTrace('updateHitbox: Couldnt find object: $obj', false, false, FlxColor.RED);
		});
		set("updateHitboxFromGroup", (group:String, index:Int) ->
		{
			final obj:Dynamic = Reflect.getProperty(LuaUtils.getTargetInstance(), group);
			if (obj == null)
				return;

			final isSpriteGroup = obj is FlxTypedSpriteGroup;
			if ((obj is FlxTypedGroup) || isSpriteGroup)
			{
				final members = (isSpriteGroup ? cast (obj, FlxTypedSpriteGroup<Dynamic>).group : cast (obj, FlxTypedGroup<Dynamic>)).members;
				return cast (members[index], FlxSprite).updateHitbox();
			}
			cast (cast (obj, Array<Dynamic>)[index], FlxSprite).updateHitbox();
		});

		set("removeLuaSprite", (tag:String, destroy:Bool = true) ->
		{
			if (!game.modchartSprites.exists(tag))
				return;

			final spr:ExtendedSprite = game.modchartSprites.get(tag);
			LuaUtils.getTargetInstance().remove(spr, true);
			if (destroy)
			{
				spr.destroy();
				game.modchartSprites.remove(tag);
			}
		});

		set("luaSpriteExists",	game.modchartSprites.exists);
		set("luaTextExists",	game.modchartTexts.exists);
		set("luaSoundExists",	game.modchartSounds.exists);

		set("setHealthBarColors", (left:String, right:String) -> game.healthBar.setColors(CoolUtil.colorFromString(left), CoolUtil.colorFromString(right)));
		set("setTimeBarColors",	  (left:String, right:String) -> game.timeBar.setColors(CoolUtil.colorFromString(left), CoolUtil.colorFromString(right))); 

		set("setObjectCamera", (obj:String, camera:String = "") ->
		{
			var basic:FlxBasic = game.getLuaObject(obj);
			if (basic != null)
			{
				basic.cameras = [LuaUtils.cameraFromString(camera)];
				return true;
			}

			final split = obj.split(".");
			basic = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			if (basic != null)
			{
				basic.cameras = [LuaUtils.cameraFromString(camera)];
				return true;
			}
			luaTrace('setObjectCamera: Object $obj doesn\'t exist!', false, false, FlxColor.RED);
			return false;
		});
		set("setBlendMode", (obj:String, blend:String = "") ->
		{
			var spr:FlxSprite = game.getLuaObject(obj);
			if (spr != null)
			{
				spr.blend = LuaUtils.blendModeFromString(blend);
				return true;
			}

			final split:Array<String> = obj.split(".");
			spr = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			if (spr != null)
			{
				spr.blend = LuaUtils.blendModeFromString(blend);
				return true;
			}
			luaTrace('setBlendMode: Object $obj doesn\'t exist!', false, false, FlxColor.RED);
			return false;
		});
		set("screenCenter", (obj:String, pos:String = "xy") ->
		{
			var spr:FlxSprite = game.getLuaObject(obj);
			if (spr == null)
			{
				final split:Array<String> = obj.split(".");
				spr = (split.length > 1)
					? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
					: LuaUtils.getObjectDirectly(split[0]);
			}

			if (spr != null)
			{
				var axis = XY;
				try { axis = FlxAxes.fromString(pos.trim().toLowerCase()); }
				catch(e) trace('screenCenter: $e');
				spr.screenCenter(axis);
			}

			luaTrace('screenCenter: Object $obj doesn\'t exist!', false, false, FlxColor.RED);
		});
		set("objectsOverlap", (obj1:String, obj2:String) ->
		{
			final basic1:FlxBasic = game.getLuaObject(obj1) ?? Reflect.getProperty(LuaUtils.getTargetInstance(), obj1);
			final basic2:FlxBasic = game.getLuaObject(obj2) ?? Reflect.getProperty(LuaUtils.getTargetInstance(), obj2);
			return (!(basic1 == null || basic2 == null) && FlxG.overlap(basic1, basic2));
		});
		set("getPixelColor", (obj:String, x:Int, y:Int) ->
		{
			final split = obj.split(".");
			final spr:FlxSprite = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			return spr == null ? FlxColor.BLACK : spr.pixels.getPixel32(x, y);
		});
		set("startDialogue", (dialogueFile:String, ?music:String) ->
		{
			var path:String;
			#if MODS_ALLOWED
			path = Paths.modsJson(Paths.formatToSongPath(PlayState.SONG.song) + '/$dialogueFile');
			if (!FileSystem.exists(path))
			#end
				path = Paths.json(Paths.formatToSongPath(PlayState.SONG.song) + '/$dialogueFile');

			luaTrace('startDialogue: Trying to load dialogue: $path');

			#if MODS_ALLOWED
			if (!FileSystem.exists(path))
			#else
			if (!Assets.exists(path))
			#end
			{
				luaTrace("startDialogue: Dialogue file not found", false, false, FlxColor.RED);
				(game.endingSong ? game.endSong : game.startCountdown)();
				return false;
			}

			final parsed = DialogueBoxPsych.parseDialogue(path);
			if (parsed.dialogue.length == 0)
			{
				luaTrace("startDialogue: Your dialogue file is badly formatted!", false, false, FlxColor.RED);
				return false;
			}
			game.startDialogue(parsed, music);
			luaTrace("startDialogue: Successfully loaded dialogue", false, false, FlxColor.GREEN);
			return true;
		});
		set("startVideo", (videoFile:String, antialias:Bool = true) ->
		{
			final ret = game.startVideo(videoFile, antialias);
			#if VIDEOS_ALLOWED
			if (!ret)
				luaTrace('startVideo: Video file not found: $videoFile', false, false, FlxColor.RED);
			#end
			return ret;
		});

		set("playMusic", (sound:String, volume:Float = 1, loop:Bool = false) -> FlxG.sound.playMusic(Paths.music(sound), volume, loop));
		set("playSound", (sound:String, volume:Float = 1, ?tag:String) ->
		{
			if (tag == null || tag.length == 0)
			{
				FlxG.sound.play(Paths.sound(sound), volume);
				return;
			}

			tag = tag.replace(".", "");
			if (game.modchartSounds.exists(tag))
				game.modchartSounds.get(tag).stop(); 

			game.modchartSounds.set(tag, FlxG.sound.play(Paths.sound(sound), volume, false, () ->
			{
				game.modchartSounds.remove(tag);
				game.callOnLuas("onSoundFinished", [tag]);
			}));
		});
		set("stopSound", (tag:String) ->
		{
			if (game.modchartSounds.exists(tag))
			{
				game.modchartSounds.get(tag).stop();
				game.modchartSounds.remove(tag);
			}
		});
		set("pauseSound", (tag:String) ->
			if (game.modchartSounds.exists(tag))
				game.modchartSounds.get(tag).pause()
		);
		set("resumeSound", (tag:String) ->
			if (game.modchartSounds.exists(tag))
				game.modchartSounds.get(tag).play()
		);
		set("soundFadeIn", (tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1) ->
		{
			if (tag == null || tag.length == 0)
				FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			else if (game.modchartSounds.exists(tag))
				game.modchartSounds.get(tag).fadeIn(duration, fromValue, toValue);
		});
		set("soundFadeOut", (tag:String, duration:Float, toValue:Float = 0) ->
		{
			if (tag == null || tag.length == 0)
				FlxG.sound.music.fadeOut(duration, toValue);
			else if (game.modchartSounds.exists(tag))
				game.modchartSounds.get(tag).fadeOut(duration, toValue);
		});
		set("soundFadeCancel", (tag:String) ->
		{
			if (tag == null || tag.length == 0)
			{
				if (FlxG.sound.music.fadeTween != null)
					FlxG.sound.music.fadeTween.cancel();
			}
			else if (game.modchartSounds.exists(tag))
			{
				final theSound = game.modchartSounds.get(tag);
				if (theSound.fadeTween != null)
				{
					theSound.fadeTween.cancel();
					game.modchartSounds.remove(tag);
				}
			}
		});
		set("getSoundVolume", (tag:String) ->
		{
			if (tag == null || tag.length == 0)
			{
				if (FlxG.sound.music != null)
					return FlxG.sound.music.volume;
			}
			else if (game.modchartSounds.exists(tag))
				return game.modchartSounds.get(tag).volume;

			return 0;
		});
		set("setSoundVolume", (tag:String, value:Float) ->
		{
			if (tag == null || tag.length == 0)
			{
				if (FlxG.sound.music != null)
					FlxG.sound.music.volume = value;
			}
			else if (game.modchartSounds.exists(tag))
				game.modchartSounds.get(tag).volume = value;
		});
		set("getSoundTime", (tag:String) -> game.modchartSounds.exists(tag) ? game.modchartSounds.get(tag).time : 0);
		set("setSoundTime", (tag:String, value:Float) ->
		{
			if (!game.modchartSounds.exists(tag))
				return;

			final theSound = game.modchartSounds.get(tag);
			if (theSound != null)
			{
				final wasResumed = theSound.playing;
				theSound.pause();
				theSound.time = value;
				if (wasResumed)
					theSound.play();
			}
		});

		#if FLX_PITCH
		set("getSoundPitch", (tag:String) -> game.modchartSounds.exists(tag) ? game.modchartSounds.get(tag).pitch : 0);
		set("setSoundPitch", (tag:String, value:Float, doPause:Bool = false) ->
		{
			if (!game.modchartSounds.exists(tag))
				return;

			final theSound = game.modchartSounds.get(tag);
			if (theSound != null)
			{
				final wasResumed = theSound.playing;
				if (doPause)
					theSound.pause();
				theSound.pitch = value;
				if (doPause && wasResumed)
					theSound.play();
			}
		});
		#end

		set("debugPrint", (t:Dynamic, ?c:LuaColor) -> game.addTextToDebug(t, c == null ? FlxColor.WHITE : LuaUtils.resolveColor(c)));
		
		addLocalCallback("close", () ->
		{
			trace('Closing script $scriptName');
			return closed = true;
		});

		#if hxdiscord_rpc
		DiscordClient.implement(this);
		#end
		#if ACHIEVEMENTS_ALLOWED
		backend.Achievements.implement(this);
		#end
		HScript.implement(this);
		ReflectionFunctions.implement(this);
		TextFunctions.implement(this);
		ExtraFunctions.implement(this);
		CustomSubstate.implement(this);
		ShaderFunctions.implement(this);
		DeprecatedFunctions.implement(this);
		
		try
		{
			final result:Dynamic = LuaL.dofile(lua, scriptName);
			final resultStr:String = Lua.tostring(lua, result);
			if (resultStr != null && result != 0)
			{
				trace(resultStr);
				#if windows
				lime.app.Application.current.window.alert(resultStr, "Error on lua script!");
				#else
				luaTrace('$scriptName\n$resultStr', true, false, FlxColor.RED);
				#end
				lua = null;
				return;
			}
		}
		catch(e)
		{
			trace(e);
			return;
		}
		call("onCreate", []);
		times = openfl.Lib.getTimer() - times;
		trace('lua file loaded succesfully: $scriptName [' + (times == 0 ? "instantly" : times + "ms") + "]");
		#end
	}

	//main
	public var lastCalledFunction:String = "";
	public static var lastCalledScript:FunkinLua = null;
	public function call(func:String, args:Array<Dynamic>):Dynamic
	{
		#if LUA_ALLOWED
		if (closed)
			return Function_Continue;

		lastCalledFunction = func;
		lastCalledScript = this;
		try
		{
			if (lua == null)
				return Function_Continue;

			Lua.getglobal(lua, func);
			final type:Int = Lua.type(lua, -1);

			if (type != Lua.LUA_TFUNCTION)
			{
				if (type > Lua.LUA_TNIL)
					luaTrace('ERROR ($func): attempt to call a ' + LuaUtils.typeToString(type) + " value", false, false, FlxColor.RED);

				Lua.pop(lua, 1);
				return Function_Continue;
			}

			for (arg in args)
				Convert.toLua(lua, arg);
			final status = Lua.pcall(lua, args.length, 1, 0);

			// Checks if it's not successful, then show a error.
			if (status != Lua.LUA_OK)
			{
				final error = getErrorMessage(status);
				luaTrace('ERROR ($func): $error', false, false, FlxColor.RED);
				return Function_Continue;
			}

			// If successful, pass and then return the result.
			var result:Dynamic = cast Convert.fromLua(lua, -1);
			if (result == null)
				result = Function_Continue;

			Lua.pop(lua, 1);
			if (closed)
				stop();
			return result;
		}
		catch (e) trace(e);
		#end
		return Function_Continue;
	}
	
	public function set(variable:String, data:Dynamic)
	{
		#if LUA_ALLOWED
		if (lua == null)
			return;

		if (Type.typeof(data) == TFunction)
		{
			Lua_helper.add_callback(lua, variable, data);
			return;
		}

		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
		#end
	}

	public function stop()
	{
		#if LUA_ALLOWED
		PlayState.instance.luaArray.remove(this);
		closed = true;

		if (lua == null)
			return;

		Lua.close(lua);
		lua = null;
		if (hscript != null)
		{
			hscript.active = false;
			hscript.destroy();
			hscript = null;
		}
		#end
	}

	function oldTweenFunction(tag:String, vars:String, tweenValue:Any, duration:Float, ease:String, field:String)
	{
		#if LUA_ALLOWED
		final target:Dynamic = LuaUtils.tweenPrepare(tag, vars);
		if (target == null)
		{
			luaTrace("doTween" + CoolUtil.capitalize(field) + ': Couldnt find object: $vars', false, false, FlxColor.RED);
			return;
		}

		LuaUtils.cancelTween(tag);
		final realTweenValue:Dynamic = {};
		Reflect.setField(realTweenValue, field, tweenValue);

		PlayState.instance.modchartTweens.set(tag, FlxTween.tween(target, realTweenValue, duration, {ease: LuaUtils.getTweenEaseByString(ease),
		onComplete: (_) ->
		{
			PlayState.instance.modchartTweens.remove(tag);
			PlayState.instance.callOnLuas("onTweenCompleted", [tag, vars]);
		}}));
		#end
	}

	function noteTweenFunction(tag:String, note:Int, tweenValue:Any, duration:Float, ease:String, field:String)
	{
		LuaUtils.cancelTween(tag);
		final testicle = PlayState.instance.strumLineNotes.members[FlxMath.maxInt(0, note) % PlayState.instance.strumLineNotes.length];

		final realTweenValue:Dynamic = {};
		Reflect.setField(realTweenValue, field, tweenValue);

		// if (testicle != null)
		// {
		PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, realTweenValue, duration,
		{
			ease: LuaUtils.getTweenEaseByString(ease),
			onComplete: (_) ->
			{
				PlayState.instance.callOnLuas("onTweenCompleted", [tag]);
				PlayState.instance.modchartTweens.remove(tag);
			}
		}));
		// }
	}
	
	public static function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:FlxColor = FlxColor.WHITE, ?pos:haxe.PosInfos)
	{
		#if LUA_ALLOWED
		if (ignoreCheck || getBool("luaDebugMode"))
		{
			if (deprecated && !getBool("luaDeprecatedWarnings"))
				return;

			PlayState.instance.addTextToDebug(text, color, pos);
		}
		#end
	}
	
	#if LUA_ALLOWED
	public static function getBool(variable:String)
	{
		if (lastCalledScript == null)
			return false;

		final lua:State = lastCalledScript.lua;
		if (lua == null)
			return false;

		Lua.getglobal(lua, variable);
		final result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);

		return result == null ? false : result == "true";
	}
	#end

	function findScript(scriptFile:String, ext:String = ".lua")
	{
		if (!scriptFile.endsWith(ext))
			scriptFile += ext;

		final preloadPath = Paths.getSharedPath(scriptFile);
		#if MODS_ALLOWED
		final path = Paths.modFolders(scriptFile);
		if (FileSystem.exists(scriptFile))
			return scriptFile;
		else if (FileSystem.exists(path))
			return path;
	
		if (FileSystem.exists(preloadPath))
		#else
		if (Assets.exists(preloadPath))
		#end
		{
			return preloadPath;
		}
		return null;
	}

	public function getErrorMessage(status:Int):String
	{
		#if LUA_ALLOWED
		var v = Lua.tostring(lua, -1);
		Lua.pop(lua, 1);

		if (v != null)
			v = v.trim();

		if (v == null || v == "")
		{
			return switch(status)
			{
				case Lua.LUA_ERRRUN:	"Runtime Error";
				case Lua.LUA_ERRMEM:	"Memory Allocation Error";
				case Lua.LUA_ERRERR:	"Critical Error";
				default:				"Unknown Error";
			}
		}

		return v;
		#end
		return null;
	}

	public function addLocalCallback(name:String, myFunction:Dynamic)
	{
		#if LUA_ALLOWED
		callbacks.set(name, myFunction);
		Lua_helper.add_callback(lua, name, null); // just so that it gets called
		#end
	}
	
	#if (MODS_ALLOWED && !flash && sys)
	public var runtimeShaders = new Map<String, RuntimeShaderData>();
	#end
	public function initLuaShader(name:String, ?glslVersion:Int = 120)
	{
		if (!ClientPrefs.data.shaders)
			return false;

		#if (MODS_ALLOWED && !flash && sys)
		if (runtimeShaders.exists(name))
		{
			luaTrace('Shader $name was already initialized!');
			return true;
		}

		final foldersToCheck = [Paths.mods("shaders/")];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length != 0)
			foldersToCheck.unshift(Paths.mods(Mods.currentModDirectory + "/shaders/"));

		for (mod in Mods.getGlobalMods())
			foldersToCheck.unshift(Paths.mods('$mod/shaders/'));
		
		for (folder in foldersToCheck)
			if (FileSystem.exists(folder))
			{
				var frag = '$folder$name.frag';
				var vert = '$folder$name.vert';

				frag = FileSystem.exists(frag) ? File.getContent(frag) : null;
				vert = FileSystem.exists(vert) ? File.getContent(vert) : null;

				if (!(frag == null && vert == null))
				{
					runtimeShaders.set(name, [frag, vert]);
					return true;
				}
			}

		luaTrace('Missing shader $name .frag AND .vert files!', false, false, FlxColor.RED);
		#else
		luaTrace("This platform doesn\'t support Runtime Shaders!", false, false, FlxColor.RED);
		#end
		return false;
	}
}