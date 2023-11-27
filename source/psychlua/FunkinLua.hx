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

import states.MainMenuState;
import states.StoryMenuState;
import states.FreeplayState;

import substates.PauseSubState;
import substates.GameOverSubstate;

import psychlua.LuaUtils;
import psychlua.LuaUtils.LuaTweenOptions;
import psychlua.HScript;
import psychlua.ModchartSprite;

#if LUA_ALLOWED
import llua.*;
import llua.Lua;
#end

class FunkinLua
{
	public static final Function_Stop:Dynamic = "##PSYCHLUA_FUNCTIONSTOP";
	public static final Function_Continue:Dynamic = "##PSYCHLUA_FUNCTIONCONTINUE";
	public static final Function_StopLua:Dynamic = "##PSYCHLUA_FUNCTIONSTOPLUA";
	public static final Function_StopHScript:Dynamic = "##PSYCHLUA_FUNCTIONSTOPHSCRIPT";
	public static final Function_StopAll:Dynamic = "##PSYCHLUA_FUNCTIONSTOPALL";

	#if LUA_ALLOWED
	public var lua:State = null;
	#end
	public var scriptName:String = '';
	public var closed:Bool = false;
	public var hscript:HScript = null;
	
	public var callbacks:Map<String, Dynamic> = new Map<String, Dynamic>();
	public static var customFunctions:Map<String, Dynamic> = new Map<String, Dynamic>();

	// for functions taht get point from stuff (aka optimisation)
	final _lePoint:FlxPoint = FlxPoint.get();

	public function new(scriptName:String)
	{
		#if LUA_ALLOWED
		final times:Float = Date.now().getTime();
		this.scriptName = scriptName;
		lua = LuaL.newstate();
		LuaL.openlibs(lua);

		final game:PlayState = PlayState.instance;
		game.luaArray.push(this);

		// Lua shit
		set('Function_StopLua', Function_StopLua);
		set('Function_StopHScript', Function_StopHScript);
		set('Function_StopAll', Function_StopAll);
		set('Function_Stop', Function_Stop);
		set('Function_Continue', Function_Continue);
		set('luaDebugMode', false);
		set('luaDeprecatedWarnings', true);
		set('inChartEditor', PlayState.chartingMode); // made it actually usefull now

		// Song/Week shit
		set('curBpm', Conductor.bpm);
		set('bpm', PlayState.SONG.bpm);
		set('scrollSpeed', PlayState.SONG.speed);
		set('crochet', Conductor.crochet);
		set('stepCrochet', Conductor.stepCrochet);
		set('songLength', FlxG.sound.music.length);
		set('songName', PlayState.SONG.song);
		set('songPath', Paths.formatToSongPath(PlayState.SONG.song));
		set('startedCountdown', false);
		set('curStage', PlayState.SONG.stage);

		set('isStoryMode', PlayState.isStoryMode);
		set('difficulty', PlayState.storyDifficulty);

		set('difficultyName', Difficulty.getString());
		set('difficultyPath', Paths.formatToSongPath(Difficulty.getString()));
		set('weekRaw', PlayState.storyWeek);
		set('week', WeekData.weeksList[PlayState.storyWeek]);
		set('seenCutscene', PlayState.seenCutscene);
		set('hasVocals', PlayState.SONG.needsVoices);

		// Camera poo
		set('cameraX', 0);
		set('cameraY', 0);

		// Screen stuff
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);

		// PlayState cringe ass nae nae bullcrap
		set('curSection', 0);
		set('curBeat', 0);
		set('curStep', 0);
		set('curDecBeat', 0);
		set('curDecStep', 0);

		set('score', 0);
		set('misses', 0);
		set('hits', 0);
		set('combo', 0);

		set('rating', 0);
		set('ratingName', '');
		set('ratingFC', '');
		set('version', MainMenuState.psychEngineVersion);

		set('inGameOver', false);
		set('mustHitSection', false);
		set('altAnim', false);
		set('gfSection', false);

		// Gameplay settings
		set('healthGainMult', game.healthGain);
		set('healthLossMult', game.healthLoss);
		#if FLX_PITCH set('playbackRate', game.playbackRate); #end
		set('instakillOnMiss', game.instakillOnMiss);
		set('botPlay', game.cpuControlled);
		set('practice', game.practiceMode);

		for (i in 0...4) {
			set('defaultPlayerStrumX$i', 0);
			set('defaultPlayerStrumY$i', 0);
			set('defaultOpponentStrumX$i', 0);
			set('defaultOpponentStrumY$i', 0);
		}

		// Default character positions woooo
		set('defaultBoyfriendX',  game.BF_POS.x);
		set('defaultBoyfriendY',  game.BF_POS.y);
		set('defaultOpponentX',   game.DAD_POS.x);
		set('defaultOpponentY',   game.DAD_POS.y);
		set('defaultGirlfriendX', game.GF_POS.x);
		set('defaultGirlfriendY', game.GF_POS.y);

		// Character shit
		set('boyfriendName', PlayState.SONG.player1);
		set('dadName', PlayState.SONG.player2);
		set('gfName', PlayState.SONG.gfVersion);

		// Some settings, no jokes
		set('downscroll', ClientPrefs.data.downScroll);
		set('middlescroll', ClientPrefs.data.middleScroll);
		set('camScript', ClientPrefs.data.camScript);
		set('camScriptNote', ClientPrefs.data.camScriptNote);
		set('framerate', ClientPrefs.data.framerate);
		set('ghostTapping', ClientPrefs.data.ghostTapping);
		set('hideHud', ClientPrefs.data.hideHud);
		set('timeBarType', ClientPrefs.data.timeBarType);
		set('scoreZoom', ClientPrefs.data.scoreZoom);
		set('cameraZoomOnBeat', ClientPrefs.data.camZooms);
		set('flashingLights', ClientPrefs.data.flashing);
		set('noteOffset', ClientPrefs.data.noteOffset);
		set('healthBarAlpha', ClientPrefs.data.healthBarAlpha);
		set('noResetButton', ClientPrefs.data.noReset);
		set('lowQuality', ClientPrefs.data.lowQuality);
		set('shadersEnabled', ClientPrefs.data.shaders);
		set('scriptName', scriptName);
		set('currentModDirectory', Mods.currentModDirectory);

		// Noteskin/Splash
		set('noteSkin', ClientPrefs.data.noteSkin);
		set('noteSkinPostfix', Note.getNoteSkinPostfix());
		set('splashSkin', ClientPrefs.data.splashSkin);
		set('splashSkinPostfix', NoteSplash.getSplashSkinPostfix());
		set('splashAlpha', ClientPrefs.data.splashAlpha);

		set('buildTarget', getBuildTarget());

		for (name => func in customFunctions) if(func != null) set(name, func);

		set("getRunningScripts", function() return [for (script in game.luaArray) script.scriptName]);
		
		addLocalCallback("setOnScripts", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			if(ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);
			game.setOnScripts(varName, arg, exclusions);
		});
		addLocalCallback("setOnHScript", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			if(ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);
			game.setOnHScript(varName, arg, exclusions);
		});
		addLocalCallback("setOnLuas", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			if(ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);
			game.setOnLuas(varName, arg, exclusions);
		});

		addLocalCallback("callOnScripts", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(excludeScripts == null) excludeScripts = [];
			if(ignoreSelf && !excludeScripts.contains(scriptName)) excludeScripts.push(scriptName);
			game.callOnScripts(funcName, args, ignoreStops, excludeScripts, excludeValues);
			return true;
		});
		addLocalCallback("callOnLuas", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(excludeScripts == null) excludeScripts = [];
			if(ignoreSelf && !excludeScripts.contains(scriptName)) excludeScripts.push(scriptName);
			game.callOnLuas(funcName, args, ignoreStops, excludeScripts, excludeValues);
			return true;
		});
		addLocalCallback("callOnHScript", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(excludeScripts == null) excludeScripts = [];
			if(ignoreSelf && !excludeScripts.contains(scriptName)) excludeScripts.push(scriptName);
			game.callOnHScript(funcName, args, ignoreStops, excludeScripts, excludeValues);
			return true;
		});

		set("callScript", function(script:String, funcName:String, ?args:Array<Dynamic> = null) {
			if(args == null) args = [];

			final foundScript:String = findScript(script);
			if(foundScript != null)
				for (luaInstance in game.luaArray)
					if(luaInstance.scriptName == foundScript)
					{
						luaInstance.call(funcName, args);
						return;
					}
		});

		set("getGlobalFromScript", function(luaFile:String, global:String) { // returns the global from a script
			final foundScript:String = findScript(luaFile);
			if(foundScript != null)
				for (luaInstance in game.luaArray)
					if(luaInstance.scriptName == foundScript)
					{
						Lua.getglobal(luaInstance.lua, global);
						if(Lua.isnumber(luaInstance.lua,-1))
							Lua.pushnumber(lua, Lua.tonumber(luaInstance.lua, -1));
						else if(Lua.isstring(luaInstance.lua,-1))
							Lua.pushstring(lua, Lua.tostring(luaInstance.lua, -1));
						else if(Lua.isboolean(luaInstance.lua,-1))
							Lua.pushboolean(lua, Lua.toboolean(luaInstance.lua, -1));
						else
							Lua.pushnil(lua);

						// TODO: table

						Lua.pop(luaInstance.lua,1); // remove the global

						return;
					}
		});
		set("setGlobalFromScript", function(luaFile:String, global:String, val:Dynamic) { // returns the global from a script
			final foundScript:String = findScript(luaFile);
			if(foundScript != null)
				for (luaInstance in game.luaArray)
					if(luaInstance.scriptName == foundScript)
						luaInstance.set(global, val);
		});
		/*set("getGlobals", function(luaFile:String) { // returns a copy of the specified file's globals
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
		set("isRunning", function(luaFile:String)
		{
			final foundScript:String = findScript(luaFile);
			if(foundScript != null)
				for (luaInstance in game.luaArray)
					if(luaInstance.scriptName == foundScript)
						return true;
			return false;
		});

		set("setVar", function(varName:String, value:Dynamic)
		{
			PlayState.instance.variables.set(varName, value);
			return value;
		});
		set("getVar", PlayState.instance.variables.get);

		set("addLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false) { //would be dope asf.
			final foundScript:String = findScript(luaFile);
			if(foundScript != null)
			{
				if(!ignoreAlreadyRunning)
					for (luaInstance in game.luaArray)
						if(luaInstance.scriptName == foundScript)
						{
							luaTrace('addLuaScript: The script "$foundScript" is already running!');
							return;
						}

				new FunkinLua(foundScript);
				return;
			}
			luaTrace("addLuaScript: Script doesn't exist!", false, false, FlxColor.RED);
		});
		set("addHScript", function(hxFile:String, ?ignoreAlreadyRunning:Bool = false) {
			#if HSCRIPT_ALLOWED
			final foundScript:String = findScript(hxFile, '.hx');
			if(foundScript != null)
			{
				if(!ignoreAlreadyRunning)
					for (script in game.hscriptArray)
						if(script.origin == foundScript)
						{
							luaTrace('addHScript: The script "$foundScript" is already running!');
							return;
						}

				PlayState.instance.initHScript(foundScript);
				return;
			}
			luaTrace("addHScript: Script doesn't exist!", false, false, FlxColor.RED);
			#else
			luaTrace("addHScript: HScript is not supported on this platform!", false, false, FlxColor.RED);
			#end
		});
		set("removeLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false) {
			final foundScript:String = findScript(luaFile);
			if(foundScript != null)
				if(!ignoreAlreadyRunning)
					for (luaInstance in game.luaArray)
						if(luaInstance.scriptName == foundScript)
						{
							luaInstance.stop();
							trace('Closing script ' + luaInstance.scriptName);
							return true;
						}
			luaTrace('removeLuaScript: Script $luaFile isn\'t running!', false, false, FlxColor.RED);
			return false;
		});

		set("loadSong", function(?name:String = null, ?difficultyNum:Int = -1) {
			if(name == null || name.length < 1)
				name = PlayState.SONG.song;
			if (difficultyNum == -1)
				difficultyNum = PlayState.storyDifficulty;

			PlayState.SONG = Song.loadFromJson(Highscore.formatSong(name, difficultyNum), name);
			PlayState.storyDifficulty = difficultyNum;
			game.persistentUpdate = false;
			LoadingState.loadAndSwitchState(new PlayState());

			FlxG.sound.music.pause();
			FlxG.sound.music.volume = 0;
			game.vocals.pause();
			game.vocals.volume = 0;
			FlxG.camera.followLerp = 0;
		});

		set("loadGraphic", function(variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0) {
			final split:Array<String> = variable.split('.');
			final spr:FlxSprite = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			if(spr != null && image != null && image.length > 0)
				spr.loadGraphic(Paths.image(image), gridX != 0 || gridY != 0, gridX, gridY);
		});
		set("loadFrames", function(variable:String, image:String, spriteType:String = "sparrow") {
			final split:Array<String> = variable.split('.');
			final spr:FlxSprite = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			if(spr != null && image != null && image.length > 0)
				spr.frames = LuaUtils.loadFrames(image, spriteType);
		});

		//shitass stuff for epic coders like me B)  *image of obama giving himself a medal*
		set("getObjectOrder", function(obj:String) {
			final split:Array<String> = obj.split('.');
			final leObj:FlxBasic = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			if(leObj != null)
				return LuaUtils.getTargetInstance().members.indexOf(leObj);

			luaTrace("getObjectOrder: Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
			return -1;
		});
		set("setObjectOrder", function(obj:String, position:Int) {
			final split:Array<String> = obj.split('.');
			final leObj:FlxBasic = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			if(leObj != null) {
				LuaUtils.getTargetInstance().remove(leObj, true);
				LuaUtils.getTargetInstance().insert(position, leObj);
				return;
			}
			luaTrace("setObjectOrder: Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
		});

		// gay ass tweens
		set("startTween", function(tag:String, vars:String, values:Any = null, duration:Float, options:Any = null) {
			final penisExam:Dynamic = LuaUtils.tweenPrepare(tag, vars);
			if(penisExam != null) {
				if(values != null) {
					final myOptions:LuaTweenOptions = LuaUtils.getLuaTween(options);
					game.modchartTweens.set(tag, FlxTween.tween(penisExam, values, duration, {
						type: myOptions.type,
						ease: myOptions.ease,
						startDelay: myOptions.startDelay,
						loopDelay: myOptions.loopDelay,

						onUpdate: function(twn:FlxTween)
							if(myOptions.onUpdate != null) game.callOnLuas(myOptions.onUpdate, [tag, vars]),

						onStart: function(twn:FlxTween)
							if(myOptions.onStart != null) game.callOnLuas(myOptions.onStart, [tag, vars]),
						
						onComplete: function(twn:FlxTween) {
							if(myOptions.onComplete != null) game.callOnLuas(myOptions.onComplete, [tag, vars]);
							if(twn.type == FlxTweenType.ONESHOT || twn.type == FlxTweenType.BACKWARD) game.modchartTweens.remove(tag);
						}
					}));
				} else {
					luaTrace('startTween: No values on 2nd argument!', false, false, FlxColor.RED);
				}
			} else luaTrace('startTween: Couldnt find object: ' + vars, false, false, FlxColor.RED);
		});

		set("doTweenX", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String)
			oldTweenFunction(tag, vars, {x: value}, duration, ease, 'doTweenX')
		);
		set("doTweenY", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String)
			oldTweenFunction(tag, vars, {y: value}, duration, ease, 'doTweenY')
		);
		set("doTweenAngle", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String)
			oldTweenFunction(tag, vars, {angle: value}, duration, ease, 'doTweenAngle')
		);
		set("doTweenAlpha", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String)
			oldTweenFunction(tag, vars, {alpha: value}, duration, ease, 'doTweenAlpha')
		);
		set("doTweenZoom", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String)
			oldTweenFunction(tag, vars, {zoom: value}, duration, ease, 'doTweenZoom')
		);
		set("doTweenColor", function(tag:String, vars:String, targetColor:String, duration:Float, ease:String) {
			var penisExam:Dynamic = LuaUtils.tweenPrepare(tag, vars);
			if(penisExam != null) {
				var curColor:FlxColor = penisExam.color;
				curColor.alphaFloat = penisExam.alpha;
				game.modchartTweens.set(tag, FlxTween.color(penisExam, duration, curColor, CoolUtil.colorFromString(targetColor), {ease: LuaUtils.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						game.modchartTweens.remove(tag);
						game.callOnLuas('onTweenCompleted', [tag, vars]);
					}
				}));
			} else
				luaTrace('doTweenColor: Couldnt find object: ' + vars, false, false, FlxColor.RED);
		});

		//Tween shit, but for strums
		set("noteTweenX", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String)
			noteTweenFunction(tag, note, {x: value}, duration, ease)
		);
		set("noteTweenY", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String) 
			noteTweenFunction(tag, note, {y: value}, duration, ease)
		);
		set("noteTweenAngle", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String)
			noteTweenFunction(tag, note, {angle: value}, duration, ease)
		);
		set("noteTweenDirection", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String)
			noteTweenFunction(tag, note, {direction: value}, duration, ease)
		);
		set("noteTweenAlpha", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String)
			noteTweenFunction(tag, note, {alpha: value}, duration, ease)
		);
		set("cancelTween", LuaUtils.cancelTween);

		set("mouseClicked", function(button:String)
			return switch(button)
				{
					case 'middle':	FlxG.mouse.justPressedMiddle;
					case 'right':	FlxG.mouse.justPressedRight;
					default:		FlxG.mouse.justPressed;
				}
		);
		set("mousePressed", function(button:String)
			return switch(button)
				{
					case 'middle':	FlxG.mouse.pressedMiddle;
					case 'right':	FlxG.mouse.pressedRight;
					default:		FlxG.mouse.pressed;
				}
		);
		set("mouseReleased", function(button:String)
			return switch(button)
				{
					case 'middle':	FlxG.mouse.justReleasedMiddle;
					case 'right':	FlxG.mouse.justReleasedRight;
					default:		FlxG.mouse.justReleased;
				}
		);

		set("runTimer", function(tag:String, time:Float = 1, loops:Int = 1) {
			LuaUtils.cancelTimer(tag);
			game.modchartTimers.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer) {
				if(tmr.finished) game.modchartTimers.remove(tag);
				game.callOnLuas('onTimerCompleted', [tag, tmr.loops, tmr.loopsLeft]);
			}, loops));
		});
		set("cancelTimer", LuaUtils.cancelTimer);

		//stupid bietch ass functions
		set("addScore", function(value:Int = 0) {
			game.songScore += value;
			game.RecalculateRating();
		});
		set("addMisses", function(value:Int = 0) {
			game.songMisses += value;
			game.RecalculateRating();
		});
		set("addHits", function(value:Int = 0) {
			game.songHits += value;
			game.RecalculateRating();
		});
		set("setScore", function(value:Int = 0) {
			game.songScore = value;
			game.RecalculateRating();
		});
		set("setMisses", function(value:Int = 0) {
			game.songMisses = value;
			game.RecalculateRating();
		});
		set("setHits", function(value:Int = 0) {
			game.songHits = value;
			game.RecalculateRating();
		});
		set("getScore",  function() return game.songScore);
		set("getMisses", function() return game.songMisses);
		set("getHits",   function() return game.songHits);

		set("setHealth", function(value:Float = 0)	return game.health = value);
		set("addHealth", function(value:Float = 0)	return game.health += value);
		set("getHealth", function()					return game.health);

		//Identical functions
		set("FlxColor", 			FlxColor.fromString);
		set("getColorFromName", 	FlxColor.fromString);
		set("getColorFromString", 	FlxColor.fromString);
		set("getColorFromHex", 		function(color:String) return FlxColor.fromString('#$color'));

		// precaching
		set("addCharacterToList", function(name:String, type:String)
			game.addCharacterToList(name,
				switch(type.toLowerCase())
				{
					case 'dad': 				1;
					case 'gf' | 'girlfriend':	2;
					default:					0;
				})
		);
		set("precacheImage", Paths.image);
		set("precacheSound", Paths.sound);
		set("precacheMusic", Paths.music);

		// others
		set("triggerEvent", function(name:String, arg1:Any, arg2:Any) game.triggerEvent(name, Std.string(arg1), Std.string(arg2)));

		set("startCountdown", game.startCountdown);
		set("endSong", function() {
			game.KillNotes();
			return game.endSong();
		});
		set("restartSong", function(?skipTransition:Bool = false) {
			game.persistentUpdate = false;
			FlxG.camera.followLerp = 0;
			PauseSubState.restartSong(skipTransition);
			return true;
		});
		set("exitSong", function(?skipTransition:Bool = false) {
			if(skipTransition)
			{
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
			}

			PlayState.cancelMusicFadeTween();
			CustomFadeTransition.nextCamera = !FlxTransitionableState.skipNextTransIn ? game.camOther : null;
			MusicBeatState.switchState(PlayState.isStoryMode ? new StoryMenuState() : new FreeplayState());
			
			#if desktop DiscordClient.resetClientID(); #end

			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			PlayState.changedDifficulty = false;
			PlayState.chartingMode = false;
			game.transitioning = true;
			FlxG.camera.followLerp = 0;
			Mods.loadTopMod();
			return true;
		});
		set("getSongPosition", function() return Conductor.songPosition);

		set("getCharacterX", function(type:String)
			return switch(type.toLowerCase())
				{
					case 'dad' | 'opponent':	game.dadGroup.x;
					case 'gf' | 'girlfriend':	game.gfGroup.x;
					default:					game.boyfriendGroup.x;
				}
		);
		set("setCharacterX", function(type:String, value:Float)
			return switch(type.toLowerCase())
			{
				case 'dad' | 'opponent':	game.dadGroup.x = value;
				case 'gf' | 'girlfriend':	game.gfGroup.x = value;
				default:					game.boyfriendGroup.x = value;
			}
		);
		set("getCharacterY", function(type:String)
			return switch(type.toLowerCase())
				{
					case 'dad' | 'opponent':	game.dadGroup.y;
					case 'gf' | 'girlfriend':	game.gfGroup.y;
					default:					game.boyfriendGroup.y;
				}
		);
		set("setCharacterY", function(type:String, value:Float)
			return switch(type.toLowerCase())
			{
				case 'dad' | 'opponent':	game.dadGroup.y = value;
				case 'gf' | 'girlfriend':	game.gfGroup.y = value;
				default:					game.boyfriendGroup.y = value;
			}
		);
		set("cameraSetTarget", game.moveCamera);
		set("cameraShake", function(camera:String, intensity:Float, duration:Float)
			LuaUtils.cameraFromString(camera).shake(intensity, duration)
		);
		set("cameraFlash", function(camera:String, color:String, duration:Float,forced:Bool)
			LuaUtils.cameraFromString(camera).flash(CoolUtil.colorFromString(color), duration, null,forced)
		);
		set("cameraFade", function(camera:String, color:String, duration:Float,forced:Bool)
			LuaUtils.cameraFromString(camera).fade(CoolUtil.colorFromString(color), duration, false,null,forced)
		);

		set("setRatingPercent",	function(value:Float)	return game.ratingPercent = value);
		set("setRatingName",	function(value:String)	return game.ratingName = value);
		set("setRatingFC",		function(value:String)	return game.ratingFC = value);

		set("getMouseX", function(camera:String) return getMousePoint(camera, 'x'));
		set("getMouseY", function(camera:String) return getMousePoint(camera, 'y'));

		set("getMidpointX",			function(variable:String)					return getPoint(variable, 'midpoint', 'x'));
		set("getMidpointY",			function(variable:String)					return getPoint(variable, 'midpoint', 'y'));
		set("getGraphicMidpointX",	function(variable:String)					return getPoint(variable, 'graphic', 'x'));
		set("getGraphicMidpointY",	function(variable:String)					return getPoint(variable, 'graphic', 'y'));
		set("getScreenPositionX",	function(variable:String, ?camera:String)	return getPoint(variable, 'screen', 'x', camera));
		set("getScreenPositionY",	function(variable:String, ?camera:String)	return getPoint(variable, 'screen', 'y', camera));

		set("characterDance", function(character:String, force:Bool = false) {
			switch(character.toLowerCase()) {
				case 'dad':					game.dad.dance(force);
				case 'gf' | 'girlfriend':	if(game.gf != null) game.gf.dance(force);
				default:					game.boyfriend.dance(force);
			}
		});

		set("makeLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?animated:Bool = false, ?spriteType:String = "sparrow") {
			tag = tag.replace('.', '');
			LuaUtils.resetSpriteTag(tag);
			final leSprite:ModchartSprite = new ModchartSprite(x, y, (!animated && image != null && image.length > 0) ? Paths.image(image) : null);
			if(animated) leSprite.frames = LuaUtils.loadFrames(image, spriteType);
			//leSprite.active = animated;
			game.modchartSprites.set(tag, leSprite);
		});
		set("makeAnimatedLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?spriteType:String = "sparrow") {
			FunkinLua.luaTrace("makeAnimatedLuaSprite is deprecated! Use makeLuaSprite instead", false, true); // just wanted to merge them
			tag = tag.replace('.', '');
			LuaUtils.resetSpriteTag(tag);
			final leSprite:ModchartSprite = new ModchartSprite(x, y);
			leSprite.frames = LuaUtils.loadFrames(image, spriteType);
			game.modchartSprites.set(tag, leSprite);
		});

		set("makeGraphic", function(obj:String, width:Int = 256, height:Int = 256, color:String = 'FFFFFF') {
			final spr:FlxSprite = LuaUtils.getObjectDirectly(obj, false);
			if(spr != null) spr.makeGraphic(width, height, CoolUtil.colorFromString(color));
		});
		set("makeGradient", function(obj:String, width:Int = 256, height:Int = 256, colors:Array<String>, angle:Int = 90, chunkSize:Int = 1, interpolate:Bool = false) {
			final spr:FlxSprite = LuaUtils.getObjectDirectly(obj, false);
			if(spr != null) {
				if(colors == null || colors.length < 2) colors = ['FFFFFF', '000000'];
				spr.pixels = FlxGradient.createGradientBitmapData(width, height, [for(penis in colors) CoolUtil.colorFromString(penis)], chunkSize, angle, interpolate);
			}
		});

		set("addAnimationByPrefix", function(obj:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true) {
			final obj:Dynamic = LuaUtils.getObjectDirectly(obj, false);
			if(obj != null && obj.animation != null)
			{
				obj.animation.addByPrefix(name, prefix, framerate, loop);
				if(obj.animation.curAnim == null)
				{
					if(obj.playAnim != null) obj.playAnim(name, true);
					else obj.animation.play(name, true);
				}
				return true;
			}
			return false;
		});

		set("addAnimation", function(obj:String, name:String, frames:Array<Int>, framerate:Int = 24, loop:Bool = true) {
			final obj:Dynamic = LuaUtils.getObjectDirectly(obj, false);
			if(obj != null && obj.animation != null)
			{
				obj.animation.add(name, frames, framerate, loop);
				if(obj.animation.curAnim == null) obj.animation.play(name, true);
				return true;
			}
			return false;
		});

		set("addAnimationByIndices", function(obj:String, name:String, prefix:String, indices:Any = null, framerate:Int = 24, loop:Bool = false)
			return LuaUtils.addAnimByIndices(obj, name, prefix, indices, framerate, loop)
		);

		set("playAnim", function(obj:String, name:String, forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0)
		{
			final obj:Dynamic = LuaUtils.getObjectDirectly(obj, false);
			if(obj.playAnim != null)
			{
				obj.playAnim(name, forced, reverse, startFrame);
				return true;
			}
			obj.animation.play(name, forced, reverse, startFrame);
			return true;
		});
		set("addOffset", function(obj:String, anim:String, x:Float, y:Float) {
			final obj:Dynamic = LuaUtils.getObjectDirectly(obj, false);
			if(obj != null && obj.addOffset != null)
			{
				obj.addOffset(anim, x, y);
				return true;
			}
			return false;
		});
		set("setOffset", function(obj:String, ?x:Float, ?y:Float) {
			final obj:Dynamic = LuaUtils.getObjectDirectly(obj, false);
			if(obj != null)
			{
				if(x != null) obj.offset.x = x;
				if(y != null) obj.offset.y = y;
				return (x != null || y != null);
			}
			return false;
		});

		set("setScrollFactor", function(obj:String, scrollX:Float, scrollY:Float) {
			final luaObj:FlxSprite = game.getLuaObject(obj,false);
			if(luaObj!=null) {
				luaObj.scrollFactor.set(scrollX, scrollY);
				return;
			}

			final object:FlxObject = Reflect.getProperty(LuaUtils.getTargetInstance(), obj);
			if(object != null) object.scrollFactor.set(scrollX, scrollY);
		});
		set("addLuaSprite", function(tag:String, front:Bool = false) {
			if(game.modchartSprites.exists(tag)) {
				var shit:ModchartSprite = game.modchartSprites.get(tag);
				(front)
					? LuaUtils.getTargetInstance().add(shit)
					: (!game.isDead)
						? game.insert(game.members.indexOf(LuaUtils.getLowestCharacterGroup()), shit)
						: GameOverSubstate.instance.insert(GameOverSubstate.instance.members.indexOf(GameOverSubstate.instance.boyfriend), shit);
			}
		});
		set("setGraphicSize", function(obj:String, x:Int, y:Int = 0, updateHitbox:Bool = true) {
			final shit:FlxSprite = game.getLuaObject(obj);
			if(shit!=null) {
				shit.setGraphicSize(x, y);
				if(updateHitbox) shit.updateHitbox();
				return;
			}

			final split:Array<String> = obj.split('.');
			final poop:FlxSprite = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			if(poop != null) {
				poop.setGraphicSize(x, y);
				if(updateHitbox) poop.updateHitbox();
				return;
			}
			luaTrace('setGraphicSize: Couldnt find object: ' + obj, false, false, FlxColor.RED);
		});
		set("scaleObject", function(obj:String, x:Float, y:Float, updateHitbox:Bool = true) {
			final shit:FlxSprite = game.getLuaObject(obj);
			if(shit!=null) {
				shit.scale.set(x, y);
				if(updateHitbox) shit.updateHitbox();
				return;
			}

			final split:Array<String> = obj.split('.');
			final poop:FlxSprite = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			if(poop != null) {
				poop.scale.set(x, y);
				if(updateHitbox) poop.updateHitbox();
				return;
			}
			luaTrace('scaleObject: Couldnt find object: ' + obj, false, false, FlxColor.RED);
		});
		set("updateHitbox", function(obj:String) {
			final shit:FlxSprite = game.getLuaObject(obj);
			if(shit!=null) {
				shit.updateHitbox();
				return;
			}

			final poop:FlxSprite = Reflect.getProperty(LuaUtils.getTargetInstance(), obj);
			if(poop != null) {
				poop.updateHitbox();
				return;
			}
			luaTrace('updateHitbox: Couldnt find object: ' + obj, false, false, FlxColor.RED);
		});
		set("updateHitboxFromGroup", function(group:String, index:Int) {
			final obj:Dynamic = Reflect.getProperty(LuaUtils.getTargetInstance(), group);
			if(Std.isOfType(obj, FlxTypedGroup)) {
				obj.members[index].updateHitbox();
				return;
			}
			obj[index].updateHitbox();
		});

		set("removeLuaSprite", function(tag:String, destroy:Bool = true) {
			if(!game.modchartSprites.exists(tag)) return;

			final pee:ModchartSprite = game.modchartSprites.get(tag);
			if(destroy) pee.kill();

			LuaUtils.getTargetInstance().remove(pee, true);
			if(destroy) {
				pee.destroy();
				game.modchartSprites.remove(tag);
			}
		});

		set("luaSpriteExists",	game.modchartSprites.exists);
		set("luaTextExists",	game.modchartTexts.exists);
		set("luaSoundExists",	game.modchartSounds.exists);

		set("setHealthBarColors",	function(left:String, right:String) game.healthBar.setColors(CoolUtil.colorFromString(left), CoolUtil.colorFromString(right)));
		set("setTimeBarColors",		function(left:String, right:String) game.timeBar.setColors(CoolUtil.colorFromString(left), CoolUtil.colorFromString(right)));

		set("setObjectCamera", function(obj:String, camera:String = '') {
			final real = game.getLuaObject(obj);
			if(real!=null){
				real.cameras = [LuaUtils.cameraFromString(camera)];
				return true;
			}

			final split:Array<String> = obj.split('.');
			final object:FlxSprite = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			if(object != null) {
				object.cameras = [LuaUtils.cameraFromString(camera)];
				return true;
			}
			luaTrace("setObjectCamera: Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		set("setBlendMode", function(obj:String, blend:String = '') {
			final real = game.getLuaObject(obj);
			if(real != null) {
				real.blend = LuaUtils.blendModeFromString(blend);
				return true;
			}

			final split:Array<String> = obj.split('.');
			final spr:FlxSprite = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			if(spr != null) {
				spr.blend = LuaUtils.blendModeFromString(blend);
				return true;
			}
			luaTrace("setBlendMode: Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		set("screenCenter", function(obj:String, pos:String = 'xy') {
			var spr:FlxSprite = game.getLuaObject(obj);

			if(spr==null){
				final split:Array<String> = obj.split('.');
				spr = (split.length > 1)
					? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
					: LuaUtils.getObjectDirectly(split[0]);
			}

			if(spr != null)
			{
				final axis:FlxAxes = switch(pos.trim().toLowerCase())
					{
						case 'x':	X;
						case 'y':	Y;
						default:	XY;
					}
				spr.screenCenter(axis);
			}
			luaTrace("screenCenter: Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
		});
		set("objectsOverlap", function(obj1:String, obj2:String) {
			final namesArray:Array<String> = [obj1, obj2];
			final objectsArray:Array<FlxSprite> = [];
			for (i in 0...namesArray.length)
			{
				final real = game.getLuaObject(namesArray[i]);
				objectsArray.push((real != null) ? real : Reflect.getProperty(LuaUtils.getTargetInstance(), namesArray[i]));
			}

			return (!objectsArray.contains(null) && FlxG.overlap(objectsArray[0], objectsArray[1]));
		});
		set("getPixelColor", function(obj:String, x:Int, y:Int) {
			final split:Array<String> = obj.split('.');
			final spr:FlxSprite = (split.length > 1)
				? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
				: LuaUtils.getObjectDirectly(split[0]);

			if(spr != null) return spr.pixels.getPixel32(x, y);
			return FlxColor.BLACK;
		});
		set("startDialogue", function(dialogueFile:String, music:String = null) {
			var path:String;
			#if MODS_ALLOWED
			path = Paths.modsJson(Paths.formatToSongPath(PlayState.SONG.song) + '/' + dialogueFile);
			if(!FileSystem.exists(path))
			#end
				path = Paths.json(Paths.formatToSongPath(PlayState.SONG.song) + '/' + dialogueFile);

			luaTrace('startDialogue: Trying to load dialogue: ' + path);

			#if MODS_ALLOWED
			if(FileSystem.exists(path))
			#else
			if(Assets.exists(path))
			#end
			{
				final shit:DialogueFile = DialogueBoxPsych.parseDialogue(path);
				if(shit.dialogue.length > 0) {
					game.startDialogue(shit, music);
					luaTrace('startDialogue: Successfully loaded dialogue', false, false, FlxColor.GREEN);
					return true;
				} else {
					luaTrace('startDialogue: Your dialogue file is badly formatted!', false, false, FlxColor.RED);
				}
			} else {
				luaTrace('startDialogue: Dialogue file not found', false, false, FlxColor.RED);
				(game.endingSong) ? game.endSong() : game.startCountdown();
			}
			return false;
		});
		set("startVideo", function(videoFile:String, subtitles:Bool = false, antialias:Bool = true) {
			#if VIDEOS_ALLOWED
			if(FileSystem.exists(Paths.video(videoFile))) {
				game.startVideo(videoFile, subtitles, antialias);
				return true;
			} else {
				luaTrace('startVideo: Video file not found: ' + videoFile, false, false, FlxColor.RED);
			}
			return false;

			#else
			(game.endingSong) ? game.endSong() : game.startCountdown();
			return true;
			#end
		});

		set("playMusic", function(sound:String, volume:Float = 1, loop:Bool = false) FlxG.sound.playMusic(Paths.music(sound), volume, loop));
		set("playSound", function(sound:String, volume:Float = 1, ?tag:String = null) {
			if(tag != null && tag.length > 0) {
				tag = tag.replace('.', '');
				if(game.modchartSounds.exists(tag)) game.modchartSounds.get(tag).stop(); 
				game.modchartSounds.set(tag, FlxG.sound.play(Paths.sound(sound), volume, false, function() {
					game.modchartSounds.remove(tag);
					game.callOnLuas('onSoundFinished', [tag]);
				}));
				return;
			}
			FlxG.sound.play(Paths.sound(sound), volume);
		});
		set("stopSound", function(tag:String) {
			if(tag != null && tag.length > 1 && game.modchartSounds.exists(tag)) {
				game.modchartSounds.get(tag).stop();
				game.modchartSounds.remove(tag);
			}
		});
		set("pauseSound", function(tag:String)
			if(tag != null && tag.length > 1 && game.modchartSounds.exists(tag))
				game.modchartSounds.get(tag).pause()
		);
		set("resumeSound", function(tag:String)
			if(tag != null && tag.length > 1 && game.modchartSounds.exists(tag))
				game.modchartSounds.get(tag).play()
		);
		set("soundFadeIn", function(tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			if(tag == null || tag.length < 1)
				FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			else if(game.modchartSounds.exists(tag))
				game.modchartSounds.get(tag).fadeIn(duration, fromValue, toValue);
		});
		set("soundFadeOut", function(tag:String, duration:Float, toValue:Float = 0) {
			if(tag == null || tag.length < 1)
				FlxG.sound.music.fadeOut(duration, toValue);
			else if(game.modchartSounds.exists(tag))
				game.modchartSounds.get(tag).fadeOut(duration, toValue);
		});
		set("soundFadeCancel", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music.fadeTween != null) {
					FlxG.sound.music.fadeTween.cancel();
				}
			} else if(game.modchartSounds.exists(tag)) {
				final theSound:FlxSound = game.modchartSounds.get(tag);
				if(theSound.fadeTween != null) {
					theSound.fadeTween.cancel();
					game.modchartSounds.remove(tag);
				}
			}
		});
		set("getSoundVolume", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) {
					return FlxG.sound.music.volume;
				}
			} else if(game.modchartSounds.exists(tag)) {
				return game.modchartSounds.get(tag).volume;
			}
			return 0;
		});
		set("setSoundVolume", function(tag:String, value:Float) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) {
					FlxG.sound.music.volume = value;
				}
			} else if(game.modchartSounds.exists(tag)) {
				game.modchartSounds.get(tag).volume = value;
			}
		});
		set("getSoundTime", function(tag:String) {
			if(tag != null && tag.length > 0 && game.modchartSounds.exists(tag))
				return game.modchartSounds.get(tag).time;

			return 0;
		});
		set("setSoundTime", function(tag:String, value:Float) {
			if(tag != null && tag.length > 0 && game.modchartSounds.exists(tag)) {
				final theSound:FlxSound = game.modchartSounds.get(tag);
				if(theSound != null) {
					var wasResumed:Bool = theSound.playing;
					theSound.pause();
					theSound.time = value;
					if(wasResumed) theSound.play();
				}
			}
		});

		#if FLX_PITCH
		set("getSoundPitch", function(tag:String) return (tag != null && tag.length > 0 && game.modchartSounds.exists(tag)) ? game.modchartSounds.get(tag).pitch : 0);
		set("setSoundPitch", function(tag:String, value:Float, doPause:Bool = false) {
			if(tag != null && tag.length > 0 && game.modchartSounds.exists(tag)) {
				final theSound:FlxSound = game.modchartSounds.get(tag);
				if(theSound != null) {
					var wasResumed:Bool = theSound.playing;
					if (doPause) theSound.pause();
					theSound.pitch = value;
					if (doPause && wasResumed) theSound.play();
				}
			}
		});
		#end

		set("debugPrint", function(text:Dynamic = '', color:String = 'WHITE') PlayState.instance.addTextToDebug(text, CoolUtil.colorFromString(color)));
		
		addLocalCallback("close", function() {
			closed = true;
			trace('Closing script $scriptName');
			return closed;
		});

		#if desktop DiscordClient.implement(this); #end
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
				lime.app.Application.current.window.alert(resultStr, 'Error on lua script!');
				#else
				luaTrace('$scriptName\n$resultStr', true, false, FlxColor.RED);
				#end
				lua = null;
				return;
			}
		}
		catch(e:Dynamic)
		{
			trace(e);
			return;
		}
		call('onCreate', []);
		trace('lua file loaded succesfully: $scriptName (${Std.int(Date.now().getTime() - times)}ms)');
		#end
	}

	inline function getMousePoint(camera:String, axis:String):Float
	{
		FlxG.mouse.getScreenPosition(LuaUtils.cameraFromString(camera), _lePoint);
		return axis == 'y' ? _lePoint.y : _lePoint.x;
	}

	inline function getPoint(leVar:String, type:String, axis:String, ?camera:String):Float
	{
		final split:Array<String> = leVar.split('.');
		final obj:FlxSprite = (split.length > 1)
			? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1])
			: LuaUtils.getObjectDirectly(split[0]);

		if (obj != null)
		{
			switch(type)
			{
				case 'graphic':	obj.getGraphicMidpoint(_lePoint);
				case 'screen':	obj.getScreenPosition(_lePoint, LuaUtils.cameraFromString(camera));
				default:		obj.getMidpoint(_lePoint);
			};
			return axis == 'y' ? _lePoint.y : _lePoint.x;
		}
		return 0;
	}

	//main
	public var lastCalledFunction:String = '';
	public static var lastCalledScript:FunkinLua = null;
	public function call(func:String, args:Array<Dynamic>):Dynamic {
		#if LUA_ALLOWED
		if(closed) return Function_Continue;

		lastCalledFunction = func;
		lastCalledScript = this;
		try {
			if(lua == null) return Function_Continue;

			Lua.getglobal(lua, func);
			final type:Int = Lua.type(lua, -1);

			if (type != Lua.LUA_TFUNCTION) {
				if (type > Lua.LUA_TNIL)
					luaTrace("ERROR (" + func + "): attempt to call a " + LuaUtils.typeToString(type) + " value", false, false, FlxColor.RED);

				Lua.pop(lua, 1);
				return Function_Continue;
			}

			for (arg in args) Convert.toLua(lua, arg);
			final status:Int = Lua.pcall(lua, args.length, 1, 0);

			// Checks if it's not successful, then show a error.
			if (status != Lua.LUA_OK) {
				final error:String = getErrorMessage(status);
				luaTrace("ERROR (" + func + "): " + error, false, false, FlxColor.RED);
				return Function_Continue;
			}

			// If successful, pass and then return the result.
			var result:Dynamic = cast Convert.fromLua(lua, -1);
			if (result == null) result = Function_Continue;

			Lua.pop(lua, 1);
			if(closed) stop();
			return result;
		}
		catch (e:Dynamic) trace(e);
		#end
		return Function_Continue;
	}
	
	public function set(variable:String, data:Dynamic)
	{
		#if LUA_ALLOWED
		if(lua == null) return;

		if (Type.typeof(data) == TFunction)
		{
			Lua_helper.add_callback(lua, variable, data);
			return;
		}

		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
		#end
	}

	public function stop() {
		#if LUA_ALLOWED
		PlayState.instance.luaArray.remove(this);
		closed = true;

		if(lua == null) return;
		Lua.close(lua);
		lua = null;
		if(hscript != null)
		{
			hscript.active = false;
			hscript.destroy();
			hscript = null;
		}
		#end
		_lePoint.put();
	}

	//clone functions
	inline public static function getBuildTarget():String
		return	#if windows		'windows'
				#elseif linux	'linux'
				#elseif mac		'mac'
				#elseif html5	'browser'
				#elseif android	'android'
				#elseif switch	'switch'
				#else			'unknown' #end;

	function oldTweenFunction(tag:String, vars:String, tweenValue:Any, duration:Float, ease:String, funcName:String)
	{
		#if LUA_ALLOWED
		final target:Dynamic = LuaUtils.tweenPrepare(tag, vars);
		(target != null)
			? PlayState.instance.modchartTweens.set(tag, FlxTween.tween(target, tweenValue, duration, {ease: LuaUtils.getTweenEaseByString(ease),
				onComplete: function(twn:FlxTween) {
					PlayState.instance.modchartTweens.remove(tag);
					PlayState.instance.callOnLuas('onTweenCompleted', [tag, vars]);
				}}))
			: luaTrace('$funcName: Couldnt find object: $vars', false, false, FlxColor.RED);
		#end
	}

	function noteTweenFunction(tag:String, note:Int, tweenValue:Any, duration:Float, ease:String)
	{
		LuaUtils.cancelTween(tag);
		if(note < 0) note = 0;
		final testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

		if(testicle != null) {
			PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, tweenValue, duration, {ease: LuaUtils.getTweenEaseByString(ease),
				onComplete: function(twn:FlxTween) {
					PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
					PlayState.instance.modchartTweens.remove(tag);
				}
			}));
		}
	}
	
	public static function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:FlxColor = FlxColor.WHITE) {
		#if LUA_ALLOWED
		if(ignoreCheck || getBool('luaDebugMode')) {
			if(deprecated && !getBool('luaDeprecatedWarnings')) return;
			PlayState.instance.addTextToDebug(text, color);
			trace(text);
		}
		#end
	}
	
	#if LUA_ALLOWED
	public static function getBool(variable:String) {
		if(lastCalledScript == null) return false;

		final lua:State = lastCalledScript.lua;
		if(lua == null) return false;

		Lua.getglobal(lua, variable);
		final result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);

		if(result == null) return false;
		return (result == 'true');
	}
	#end

	function findScript(scriptFile:String, ext:String = '.lua')
	{
		if(!scriptFile.endsWith(ext)) scriptFile += ext;
		final preloadPath:String = Paths.getPreloadPath(scriptFile);
		#if MODS_ALLOWED
		final path:String = Paths.modFolders(scriptFile);
		if(FileSystem.exists(scriptFile)) return scriptFile;
		else if(FileSystem.exists(path))  return path;
	
		if(FileSystem.exists(preloadPath))
		#else
		if(Assets.exists(preloadPath))
		#end
		{
			return preloadPath;
		}
		return null;
	}

	public function getErrorMessage(status:Int):String {
		#if LUA_ALLOWED
		var v:String = Lua.tostring(lua, -1);
		Lua.pop(lua, 1);

		if (v != null) v = v.trim();
		if (v == null || v == "") {
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
		Lua_helper.add_callback(lua, name, null); //just so that it gets called
		#end
	}
	
	#if (MODS_ALLOWED && !flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();
	#end
	public function initLuaShader(name:String, ?glslVersion:Int = 120)
	{
		if(!ClientPrefs.data.shaders) return false;

		#if (MODS_ALLOWED && !flash && sys)
		if(runtimeShaders.exists(name))
		{
			luaTrace('Shader $name was already initialized!');
			return true;
		}

		final foldersToCheck:Array<String> = [Paths.mods('shaders/')];
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Mods.currentModDirectory + '/shaders/'));

		for(mod in Mods.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));
		
		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				var frag:String = folder + name + '.frag';
				var vert:String = folder + name + '.vert';
				var found:Bool = false;
				if(FileSystem.exists(frag))
				{
					frag = File.getContent(frag);
					found = true;
				}
				else frag = null;

				if(FileSystem.exists(vert))
				{
					vert = File.getContent(vert);
					found = true;
				}
				else vert = null;

				if(found)
				{
					runtimeShaders.set(name, [frag, vert]);
					//trace('Found shader $name!');
					return true;
				}
			}
		}
		luaTrace('Missing shader $name .frag AND .vert files!', false, false, FlxColor.RED);
		#else
		luaTrace('This platform doesn\'t support Runtime Shaders!', false, false, FlxColor.RED);
		#end
		return false;
	}
}