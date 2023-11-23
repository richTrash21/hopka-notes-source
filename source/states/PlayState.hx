package states;

// If you want to add your stage to the game, copy states/stages/Template.hx,
// and put your stage code there, then, on PlayState, search for
// "switch (curStage)", and add your stage to that list.

// If you want to code Events, you can either code it on a Stage file or on PlayState, if you're doing the latter, search for:
// "function eventPushed" - Only called *one time* when the game loads, use it for precaching events that use the same assets, no matter the values
// "function eventPushedUnique" - Called one time per event, use it for precaching events that uses different assets based on its values
// "function eventEarlyTrigger" - Used for making your event start a few MILLISECONDS earlier
// "function triggerEvent" - Called when the song hits your event's timestamp, this is probably what you were looking for

#if ACHIEVEMENTS_ALLOWED
import backend.Achievements;
#end
import backend.Highscore;
import backend.StageData;
import backend.WeekData;
import backend.Song;
import backend.Section.SwagSection;
import backend.Rating;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.math.FlxPoint;
import flixel.addons.transition.FlxTransitionableState;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
#if !MODS_ALLOWED
import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
#end
import openfl.events.KeyboardEvent;

import cutscenes.DialogueBoxPsych;

import states.StoryMenuState;
import states.FreeplayState;
import states.editors.ChartingState;
import states.editors.CharacterEditorState;

import substates.PauseSubState;
import substates.GameOverSubstate;

#if !flash 
import flixel.addons.display.FlxRuntimeShader;
#end

#if sys
import sys.FileSystem;
import sys.io.File;
#end

#if VIDEOS_ALLOWED 
//import hxvlc.flixel.FlxVideo as VideoHandler;
#if (hxCodec >= "3.0.0")
import hxcodec.flixel.FlxVideo as VideoHandler;
#elseif (hxCodec >= "2.6.1") import hxcodec.VideoHandler;
#elseif (hxCodec == "2.6.0") import VideoHandler;
#else import vlc.MP4Handler as VideoHandler; #end
#end

import objects.Note;
import objects.*;
//import states.stages.objects.*;

#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.FunkinLua;
import psychlua.LuaUtils;
import psychlua.HScript;
#end

#if (SScript >= "3.0.0")
import tea.SScript;
#end

class PlayState extends MusicBeatState
{
	public static var STRUM_X:Float = 42.0;
	public static var STRUM_X_MIDDLESCROLL:Float = -278.0;

	public static var ratingStuff:Array<Dynamic> = [
		['You Suck!', 0.2],	  // From 0% to 19%
		['Shit',	  0.4],	  // From 20% to 39%
		['Bad', 	  0.5],	  // From 40% to 49%
		['Bruh',	  0.6],	  // From 50% to 59%
		['Meh', 	  0.69],  // From 60% to 68%
		['Nice',	  0.7],	  // 69% :trollface:
		['Good',	  0.8],	  // From 70% to 79%
		['Great', 	  0.9],	  // From 80% to 89%
		['Sick!', 	  1],	  // From 90% to 99%
		['Perfect!!', 1]	  // The value on this one isn't used actually, since Perfect is always "1"
	];

	//event variables
	public var isCameraOnForcedPos:Bool = false;

	public var boyfriendMap:Map<String, Character> = [];
	public var dadMap:Map<String, Character> = [];
	public var gfMap:Map<String, Character> = [];
	public var variables:Map<String, Dynamic> = [];
	
	#if HSCRIPT_ALLOWED public var hscriptArray:Array<HScript> = []; #end

	#if LUA_ALLOWED
	public var modchartTweens:Map<String, FlxTween> = [];
	public var modchartSprites:Map<String, ModchartSprite> = [];
	public var modchartTimers:Map<String, FlxTimer> = [];
	public var modchartSounds:Map<String, FlxSound> = [];
	public var modchartTexts:Map<String, FlxText> = [];
	public var modchartSaves:Map<String, FlxSave> = [];
	#end

	public var BF_POS:FlxPoint	= FlxPoint.get(770.0, 100.0);
	public var DAD_POS:FlxPoint	= FlxPoint.get(100.0, 100.0);
	public var GF_POS:FlxPoint	= FlxPoint.get(400.0, 130.0);

	// DEPRECATED!!!
	/*extern*/ public var BF_X(get, set):Float;
	/*extern*/ public var BF_Y(get, set):Float;
	/*extern*/ public var DAD_X(get, set):Float;
	/*extern*/ public var DAD_Y(get, set):Float;
	/*extern*/ public var GF_X(get, set):Float;
	/*extern*/ public var GF_Y(get, set):Float;

	inline function get_BF_X():Float	return BF_POS.x;
	inline function get_BF_Y():Float	return BF_POS.y;
	inline function get_DAD_X():Float	return DAD_POS.x;
	inline function get_DAD_Y():Float	return DAD_POS.y;
	inline function get_GF_X():Float	return GF_POS.x;
	inline function get_GF_Y():Float	return GF_POS.y;

	inline function set_BF_X(v:Float):Float		return BF_POS.x  = v;
	inline function set_BF_Y(v:Float):Float		return BF_POS.y  = v;
	inline function set_DAD_X(v:Float):Float	return DAD_POS.x = v;
	inline function set_DAD_Y(v:Float):Float	return DAD_POS.y = v;
	inline function set_GF_X(v:Float):Float		return GF_POS.x  = v;
	inline function set_GF_Y(v:Float):Float		return GF_POS.y  = v;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1.0;
	public var songSpeedType:String = "multiplicative";
	public static var noteKillOffset:Float = 350;

	public var playbackRate(default, set):Float = 1.0;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;

	public static var curStage:String = '';
	public var curStageObj:BaseStage = null; // tracker for last loaded hard coded stage

	public static var isPixelStage(get, never):Bool;
	public static var stageUI:String = "normal";
	public var introSoundsSuffix:String = '';
	public var uiPrefix:String = '';
	public var uiSuffix:String = '';

	@:noCompletion inline static function get_isPixelStage():Bool
		return stageUI == "pixel" || stageUI.endsWith("-pixel");

	public static var SONG:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	static final spawnTime:Float = 2000.0;

	public var inst:FlxSound;
	public var vocals:FlxSound;

	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Character = null;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];

	public var camFollow:FlxObject;
	private static var prevCamFollow:FlxObject;

	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	// for score popups recycling
	public var scoreGroup:FlxTypedSpriteGroup<PopupSprite>;

	public var camZooming(default, set):Bool = false;
	public var camZoomingMult:Float = 1.0;
	public var camZoomingDecay(default, set):Float = 1.0;
	public var curSong:String = "";

	@:noCompletion inline function set_camZoomingDecay(decay:Float):Float
		return camZoomingDecay = camGame.zoomDecay = camHUD.zoomDecay = decay;

	@:noCompletion inline function set_camZooming(bool:Bool):Bool
		return camZooming = camGame.updateZoom = camHUD.updateZoom = bool;

	public var gfSpeed:Int = 1;
	public var combo:Int = 0;
	public var health(default, set):Float = 1.0;
	@:noCompletion function set_health(value:Float):Float {
		health = Math.min(value, healthBar.bounds.max) /*FlxMath.bound(value, null, healthBar.bounds.max)*/;
		doDeathCheck();
		return health;
	}
		
	public var healthBar:Bar;
	public var timeBar:Bar;
	public var healthBarFlip(get, set):Bool;
	@:noCompletion inline function get_healthBarFlip():Bool
		return healthBar.leftToRight;
	@:noCompletion function set_healthBarFlip(value:Bool):Bool {
		if(healthBarFlip != value) {
			healthBar.leftToRight = value;
			healthBar.setColors(healthBar.rightBar.color, healthBar.leftBar.color);
			iconP1.animation.curAnim.flipX = !value;
			iconP2.animation.curAnim.flipX = value;
		}
		return value;
	}

	public var ratingsData:Array<Rating> = Rating.loadDefault();

	private var generatedMusic:Bool = false;
	public var endingSong:Bool = false;
	public var startingSong:Bool = false;
	private var updateTime:Bool = true;
	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;

	//Gameplay settings
	public var healthGain:Float = 1.0;
	public var healthLoss:Float = 1.0;
	public var practiceMode:Bool = false;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled(default, set):Bool = false;

	public var botplaySine:Float = 0.0;
	public var botplayTxt:FlxText;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var iconBoping(default, set):Bool = true;
	public var iconBopSpeed(default, set):Float = 1.0;

	@:noCompletion inline function set_iconBoping(bool:Bool):Bool
		return iconP2.lerpScale = iconP1.lerpScale = iconBoping = bool;

	@:noCompletion inline function set_iconBopSpeed(speed:Float):Float
		return iconP2.lerpSpeed = iconP1.lerpSpeed = iconBopSpeed = speed;

	public var camHUD:GameCamera;
	public var camGame:GameCamera;
	public var camOther:GameCamera;
	public var cameraSpeed(default, set):Float = 1.0;

	@:noCompletion inline function set_cameraSpeed(speed:Float):Float
		return cameraSpeed = camGame.cameraSpeed = speed;

	public var songScore:Int = 0;
	public var songHits:Int = 0;
	public var songMisses:Int = 0;
	public var scoreTxt:FlxText;
	var timeTxt:FlxText;
	var scoreTxtTween:FlxTween;

	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public var defaultCamZoom(default, set):Float = 1.05;
	public var defaultHUDZoom(default, set):Float = 1.0;

	@:noCompletion inline function set_defaultCamZoom(zoom:Float):Float
		return defaultCamZoom = camGame.defaultZoom = zoom;
	@:noCompletion inline function set_defaultHUDZoom(zoom:Float):Float
		return defaultCamZoom = camHUD.defaultZoom = zoom;

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6.0;

	public var playingVideo:Bool = false;
	public var inCutscene(default, set):Bool = false;
	public var skipCountdown:Bool = false;

	@:noCompletion inline function set_inCutscene(bool:Bool):Bool
		return inCutscene = camGame.paused = bool;

	var songLength(default, null):Float = 0.0;
	var songPercent(default, null):Float = 0.0;

	// i have no fucking idea why i made this - richTrash21
	public var bfCamOffset:FlxPoint = null;
	public var dadCamOffset:FlxPoint = null;
	public var gfCamOffset:FlxPoint = null;

	// DEPRECATED!!!
	/*extern*/ public var boyfriendCameraOffset(get, set):Array<Float>;
	/*extern*/ public var opponentCameraOffset(get, set):Array<Float>;
	/*extern*/ public var girlfriendCameraOffset(get, set):Array<Float>;

	inline function get_boyfriendCameraOffset():Array<Float>
		return bfCamOffset != null ? [bfCamOffset.x, bfCamOffset.y] : null;

	inline function get_opponentCameraOffset():Array<Float>
		return dadCamOffset != null ? [dadCamOffset.x, dadCamOffset.y] : null;

	inline function get_girlfriendCameraOffset():Array<Float>
		return gfCamOffset != null ? [gfCamOffset.x, gfCamOffset.y] : null;

	inline function set_boyfriendCameraOffset(a:Array<Float>):Array<Float> {
		if (a != null)
			bfCamOffset != null ? bfCamOffset.set(a[0], a[1]) : bfCamOffset = FlxPoint.get(a[0], a[1]);
		return a;
	}
	inline function set_opponentCameraOffset(a:Array<Float>):Array<Float> {
		if (a != null)
			dadCamOffset != null ? dadCamOffset.set(a[0], a[1]) : dadCamOffset = FlxPoint.get(a[0], a[1]);
		return a;
	}
	inline function set_girlfriendCameraOffset(a:Array<Float>):Array<Float> {
		if (a != null)
			gfCamOffset != null ? gfCamOffset.set(a[0], a[1]) : gfCamOffset = FlxPoint.get(a[0], a[1]);
		return a;
	}

	#if desktop
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	#if ACHIEVEMENTS_ALLOWED
	//Achievement shit
	var keysPressed:Array<Int> = [];
	var boyfriendIdleTime(default, set):Float = 0.0;
	var boyfriendIdled:Bool = false;

	@:noCompletion function set_boyfriendIdleTime(time:Float):Float {
		// Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
		if(time >= 0.15) boyfriendIdled = true;
		return boyfriendIdleTime = time;
	}
	#end

	// Lua shit
	public static var instance(default, null):PlayState; // по приколу :) - Redar13
	public var luaArray:Array<FunkinLua> = [];
	#if LUA_ALLOWED
	private var luaDebugGroup:FlxTypedSpriteGroup<DebugLuaText>;
	#end

	// Less laggy controls
	private static final keysArray:Array<String> = ['note_left', 'note_down', 'note_up', 'note_right'];
	private static final singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public var precacheList:Map<String, String> = [];
	public var songName(default, null):String;

	// Callbacks for stages
	public var startCallback:()->Void = null;
	public var endCallback:()->Void = null;

	override public function create()
	{
		Paths.clearStoredMemory();

		startCallback = startCountdown;
		endCallback = endSong;

		// for lua
		instance = this;

		PauseSubState.songName = null; //Reset to default
		playbackRate = ClientPrefs.getGameplaySetting('songspeed');

		if (FlxG.sound.music != null) FlxG.sound.music.stop();

		// Gameplay settings
		healthGain = ClientPrefs.getGameplaySetting('healthgain');
		healthLoss = ClientPrefs.getGameplaySetting('healthloss');
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill');
		practiceMode = ClientPrefs.getGameplaySetting('practice');
		cpuControlled = ClientPrefs.getGameplaySetting('botplay') || ClientPrefs.getGameplaySetting('showcase');

		camGame = new GameCamera(0, 0, true);
		camHUD = new GameCamera(0, 0);
		camOther = new GameCamera(0, 0);
		//camHUD.bgColor.alpha = 0;
		//camOther.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		CustomFadeTransition.nextCamera = camOther;	

		persistentUpdate = true;
		persistentDraw = true;

		if (SONG == null) SONG = Song.loadFromJson('test');

		Conductor.mapBPMChanges(SONG);
		Conductor.bpm = SONG.bpm;

		#if desktop
		storyDifficultyText = Difficulty.getString();
		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		detailsText = isStoryMode ? "Story Mode: " + WeekData.getCurrentWeek().weekName : "Freeplay";
		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;
		#end

		songName = Paths.formatToSongPath(SONG.song);
		if(SONG.stage == null || SONG.stage.length < 1)
			SONG.stage = StageData.vanillaSongStage(songName);
		curStage = SONG.stage;

		var stageData:StageFile = StageData.getStageFile(curStage);
		if(stageData == null) //Stage couldn't be found, create a dummy stage for preventing a crash
			stageData = StageData.dummy();

		defaultCamZoom = stageData.defaultZoom;

		stageUI = (stageData.isPixelStage) ? "pixel" : "normal";
		if (#if (haxe > "4.2.5") stageData.stageUI?.trim().length #else stageData.stageUI != null && stageData.stageUI.trim().length #end > 0)
			stageUI = stageData.stageUI;

		if (stageUI != "normal")
		{
			introSoundsSuffix = '-$stageUI';
			uiSuffix = '-$stageUI';
			uiPrefix = '${stageUI}UI/';
		}

		BF_POS.set(stageData.boyfriend[0],  stageData.boyfriend[1]);
		GF_POS.set(stageData.girlfriend[0], stageData.girlfriend[1]);
		DAD_POS.set(stageData.opponent[0],  stageData.opponent[1]);

		cameraSpeed = #if (haxe > "4.2.5") stageData.camera_speed ?? 1 #else stageData.camera_speed != null ? stageData.camera_speed : 1 #end;

		bfCamOffset = (stageData.camera_boyfriend == null) //Fucks sake should have done it since the start :rolling_eyes:
			? FlxPoint.get(0, 0)
			: FlxPoint.get(stageData.camera_boyfriend[0], stageData.camera_boyfriend[1]);

		dadCamOffset = (stageData.camera_opponent == null)
			? FlxPoint.get(0, 0)
			: FlxPoint.get(stageData.camera_opponent[0], stageData.camera_opponent[1]);

		gfCamOffset = (stageData.camera_girlfriend == null)
			? FlxPoint.get(0, 0)
			: FlxPoint.get(stageData.camera_girlfriend[0], stageData.camera_girlfriend[1]);

		boyfriendGroup = new FlxSpriteGroup(BF_POS.x, BF_POS.y);
		dadGroup = new FlxSpriteGroup(DAD_POS.x, DAD_POS.y);
		gfGroup = new FlxSpriteGroup(GF_POS.x, GF_POS.y);
		//gfGroup.scrollFactor.set(0.95, 0.95); // fixed gf paralax lmao

		switch (curStage) //lol
		{
			case 'stage': curStageObj = new states.stages.StageWeek1(); //Week 1
		}

		add(gfGroup);
		add(dadGroup);
		add(boyfriendGroup);

		// for character precaching
		GameOverSubstate.resetVariables(SONG);

		#if LUA_ALLOWED
		luaDebugGroup = new FlxTypedSpriteGroup<DebugLuaText>(0, Main.fpsVar.visible ? 20 : 0); // for better visibility duhh
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);
		#end

		// "GLOBAL" SCRIPTS
		#if LUA_ALLOWED
		var foldersToCheck:Array<String> = Mods.directoriesWithFile(Paths.getPreloadPath(), 'scripts/');
		for (folder in foldersToCheck)
			for (file in FileSystem.readDirectory(folder))
			{
				if(file.toLowerCase().endsWith('.lua')) new FunkinLua(folder + file);
				#if HSCRIPT_ALLOWED if(file.toLowerCase().endsWith('.hx')) initHScript(folder + file); #end
			}
		#end

		// STAGE SCRIPTS
		#if LUA_ALLOWED		startLuasNamed('stages/' + curStage + '.lua'); #end
		#if HSCRIPT_ALLOWED	startHScriptsNamed('stages/' + curStage + '.hx'); #end

		if (!stageData.hide_girlfriend)
		{
			if(SONG.gfVersion == null || SONG.gfVersion.length < 1) SONG.gfVersion = 'gf'; //Fix for the Chart Editor
			gf = new Character(0, 0, SONG.gfVersion);
			startCharacterPos(gf);
			gfGroup.add(gf);
			startCharacterScripts(gf.curCharacter);
			charList.push(gf);
		}

		dad = new Character(0, 0, SONG.player2);
		startCharacterPos(dad, true);
		dadGroup.add(dad);
		startCharacterScripts(dad.curCharacter);
		charList.push(dad);

		boyfriend = new Character(0, 0, SONG.player1, true);
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
		startCharacterScripts(boyfriend.curCharacter);
		charList.push(boyfriend);

		final camPos:FlxPoint = FlxPoint.get(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if(gf != null) {
			final gfMidpoint:FlxPoint = gf.getGraphicMidpoint().add(gf.cameraPosition[0], gf.cameraPosition[1]);
			camPos.addPoint(gfMidpoint);
			gfMidpoint.put();
		}

		if(dad.curCharacter.startsWith('gf')) {
			dad.setPosition(GF_POS.x, GF_POS.y);
			if(gf != null) gf.visible = false;
		}
		stagesFunc(function(stage:BaseStage) stage.createPost());

		Conductor.songPosition = -5000 / Conductor.songPosition;
		var showTime:Bool = (ClientPrefs.data.timeBarType != 'Disabled');
		timeTxt = new FlxText(/*STRUM_X + (FlxG.width * 0.5) - 248*/ 0, 19, 400, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.screenCenter(X);
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = updateTime = showTime;
		if(ClientPrefs.data.downScroll) timeTxt.y = FlxG.height - 44;

		timeBar = new Bar(0, timeTxt.y + (timeTxt.height * 0.25), 'timeBar', function() return songPercent);
		timeBar.antialiasing = !isPixelStage;
		timeBar.screenCenter(X);
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		add(timeBar);
		add(timeTxt);

		if(ClientPrefs.data.timeBarType == 'Song Name')
		{
			timeTxt.text = SONG.song;
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		timeBar.updateCallback = function(value:Float, percent:Float) {
			if (ClientPrefs.data.timeBarType != 'Song Name' && !paused){
				var curTime:Float = songLength * (percent * 0.01);
				var songCalc:Float = ClientPrefs.data.timeBarType == 'Time Elapsed' ? curTime : songLength - curTime;
				var newText:String = FlxStringUtil.formatTime(FlxMath.bound(Math.floor(songCalc * 0.001), 0), false);
				timeTxt.text = newText;
			}
		}

		scoreGroup = new FlxTypedSpriteGroup<PopupSprite>();
		strumLineNotes = new FlxTypedGroup<StrumNote>();
		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		add(scoreGroup);
		add(strumLineNotes);
		add(grpNoteSplashes);

		var splash:NoteSplash = new NoteSplash();
		grpNoteSplashes.add(splash);
		splash.alpha = 0.000001; //cant make it invisible or it won't allow precaching

		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();

		generateSong(SONG.song);

		if (prevCamFollow != null) {
			camFollow = prevCamFollow;
			prevCamFollow = null;
		} else 
			camFollow = new FlxObject(camPos.x, camPos.y, 1, 1);
		add(camFollow);
		camPos.put();

		camGame.follow(camFollow, LOCKON, 0);
		camGame.zoom = defaultCamZoom;
		camGame.snapToTarget();
		camHUD.visible = !ClientPrefs.getGameplaySetting('showcase');

		// will give pixel stages more pixelated look (???????????????????)
		// dont ask why its down here idfk
		// nvmd have almost no effect
		//FlxG.camera.pixelPerfectRender = isPixelStage;
		//camHUD.pixelPerfectRender = isPixelStage;

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);
		moveCameraSection();

		healthBar = new Bar(0, FlxG.height * (!ClientPrefs.data.downScroll ? 0.89 : 0.11), 'healthBar', function() return health, 0, 2);
		healthBar.antialiasing = !isPixelStage;
		healthBar.screenCenter(X);
		healthBar.leftToRight = false;
		healthBar.visible = !ClientPrefs.data.hideHud;
		healthBar.alpha = ClientPrefs.data.healthBarAlpha;
		reloadHealthBarColors();
		add(healthBar);

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.data.hideHud;
		iconP1.alpha = ClientPrefs.data.healthBarAlpha;
		iconP1.lerpScale = true;
		add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !ClientPrefs.data.hideHud;
		iconP2.alpha = ClientPrefs.data.healthBarAlpha;
		iconP2.lerpScale = true;
		add(iconP2);

		healthBar.updateCallback = function(value:Float, percent:Float) {
			iconP1.animation.curAnim.curFrame = percent < 20.0 ? 1 : 0;
			iconP2.animation.curAnim.curFrame = percent > 80.0 ? 1 : 0;
		}

		scoreTxt = new FlxText(0, healthBar.y + 40, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.data.hideHud;
		add(scoreTxt);

		botplayTxt = new FlxText(0, timeBar.y + 55, FlxG.width - 800, "PUSSY", 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		botplayTxt.screenCenter(X);
		add(botplayTxt);
		if(ClientPrefs.data.downScroll) botplayTxt.y = timeBar.y - 78;
		
		scoreGroup.cameras	=	strumLineNotes.cameras	=	grpNoteSplashes.cameras	=
		notes.cameras		=	healthBar.cameras		=	iconP1.cameras			=
		iconP2.cameras		=	scoreTxt.cameras 		=	botplayTxt.cameras		=
		timeBar.cameras		=	timeTxt.cameras			=	[camHUD];	// i love haxe <3

		startingSong = true;
		
		#if LUA_ALLOWED
		for (notetype in noteTypes) startLuasNamed('custom_notetypes/' + notetype + '.lua');
		for (event in eventsPushed) startLuasNamed('custom_events/' + event + '.lua');
		#end

		#if HSCRIPT_ALLOWED
		for (notetype in noteTypes) startHScriptsNamed('custom_notetypes/' + notetype + '.hx');
		for (event in eventsPushed) startHScriptsNamed('custom_events/' + event + '.hx');
		#end
		noteTypes = null;
		eventsPushed = null;

		if(eventNotes.length > 1)
		{
			for (event in eventNotes) event.strumTime -= eventEarlyTrigger(event);
			eventNotes.sort(sortByTime);
		}

		// SONG SPECIFIC SCRIPTS
		#if LUA_ALLOWED
		var foldersToCheck:Array<String> = Mods.directoriesWithFile(Paths.getPreloadPath(), 'data/' + songName + '/');
		for (folder in foldersToCheck)
			for (file in FileSystem.readDirectory(folder))
			{
				if (file.toLowerCase().endsWith('.lua')) new FunkinLua(folder + file);
				#if HSCRIPT_ALLOWED if (file.toLowerCase().endsWith('.hx')) initHScript(folder + file); #end
			}
		#end

		startCallback();
		RecalculateRating();

		//PRECACHING MISS SOUNDS BECAUSE I THINK THEY CAN LAG PEOPLE AND FUCK THEM UP IDK HOW HAXE WORKS
		if(ClientPrefs.data.hitsoundVolume > 0) precacheList.set('hitsound', 'sound');
		precacheList.set('missnote1', 'sound');
		precacheList.set('missnote2', 'sound');
		precacheList.set('missnote3', 'sound');

		if(PauseSubState.songName != null)				precacheList.set(PauseSubState.songName, 'music');
		else if(ClientPrefs.data.pauseMusic != 'None')	precacheList.set(Paths.formatToSongPath(ClientPrefs.data.pauseMusic), 'music');

		precacheList.set('alphabet', 'image');
		resetRPC();

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		callOnScripts('onCreatePost');

		cacheCountdown();
		cachePopUpScore();

		for (key => type in precacheList)
			switch(type)
			{
				case 'image': Paths.image(key);
				case 'sound': Paths.sound(key);
				case 'music': Paths.music(key);
			}

		super.create();
		Paths.clearUnusedMemory();
		
		CustomFadeTransition.nextCamera = camOther;
		if(eventNotes.length < 1) checkEventNote();
	}

	// yes i am a nerd!! 🤓🤓
	function set_cpuControlled(value:Bool):Bool
	{
		if (botplayTxt != null)
		{
			botplayTxt.visible = value;
			botplayTxt.alpha = 1;
			botplaySine = 0;
		}
		if (!changedDifficulty && value) changedDifficulty = true;
		setOnScripts('botPlay', value);
		return cpuControlled = value;
	}

	function set_songSpeed(value:Float):Float
	{
		if(generatedMusic)
		{
			var ratio:Float = value / songSpeed; //funny word huh
			if (ratio != 1)
			{
				for (note in notes.members) note.resizeByRatio(ratio);
				for (note in unspawnNotes)  note.resizeByRatio(ratio);
			}
		}
		songSpeed = value;
		noteKillOffset = Math.max(Conductor.stepCrochet, 350 / songSpeed * playbackRate);
		return value;
	}

	function set_playbackRate(value:Float):Float
	{
		#if FLX_PITCH
		if(generatedMusic)
		{
			/*if (SONG.needsVoices)*/ vocals.pitch = value;
			FlxG.sound.music.pitch = value;

			var ratio:Float = playbackRate / value; //funny word huh
			if(ratio != 1)
			{
				for (note in notes.members) note.resizeByRatio(ratio);
				for (note in unspawnNotes)  note.resizeByRatio(ratio);
			}
		}
		playbackRate = value;
		FlxG.animationTimeScale = value;
		Conductor.safeZoneOffset = (ClientPrefs.data.safeFrames / 60) * 1000 * value;
		setOnScripts('playbackRate', playbackRate);
		#else
		playbackRate = 1.0; // ensuring -Crow
		#end
		return value;
	}

	public function addTextToDebug(text:String, color:FlxColor) {
		#if LUA_ALLOWED
		if (!isDead) { // ACTUALLY CAN CAUSES MEMORY LEAK!!!
			if (luaDebugGroup == null) {
				trace("can't add debug text - 'luaDebugGroup' is null!!!");
				return;
			}
			var newText:DebugLuaText = luaDebugGroup.recycle(DebugLuaText);
			newText.text = text;
			newText.color = color;
			newText.setPosition(10, 8 - newText.height);

			luaDebugGroup.forEachAlive(function(spr:DebugLuaText) spr.y += newText.height + 2);
			luaDebugGroup.add(newText);
		}
		#end
	}

	public function reloadHealthBarColors() {
		healthBar.setColors(FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]),
			FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]));
	}

	public function addCharacterToList(newCharacter:String, type:Int) {
		switch(type) {
			case 0:
				if(!boyfriendMap.exists(newCharacter)) {
					var newBoyfriend:Character = new Character(0, 0, newCharacter, true);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterScripts(newBoyfriend.curCharacter);
				}

			case 1:
				if(!dadMap.exists(newCharacter)) {
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterScripts(newDad.curCharacter);
				}

			case 2:
				if(gf != null && !gfMap.exists(newCharacter)) {
					var newGf:Character = new Character(0, 0, newCharacter);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterScripts(newGf.curCharacter);
				}
		}
	}

	function startCharacterScripts(name:String)
	{
		// Lua
		#if LUA_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = 'characters/' + name + '.lua';
		#if MODS_ALLOWED
		var replacePath:String = Paths.modFolders(luaFile);
		if(FileSystem.exists(replacePath))
		{
			luaFile = replacePath;
			doPush = true;
		}
		else
		{
			luaFile = Paths.getPreloadPath(luaFile);
			doPush = FileSystem.exists(luaFile);
		}
		#else
		luaFile = Paths.getPreloadPath(luaFile);
		if(Assets.exists(luaFile)) doPush = true;
		#end

		if(doPush)
		{
			for (script in luaArray)
			{
				if(script.scriptName == luaFile)
				{
					doPush = false;
					break;
				}
			}
			if(doPush) new FunkinLua(luaFile);
		}
		#end

		// HScript
		#if HSCRIPT_ALLOWED
		var doPush:Bool = false;
		var scriptFile:String = 'characters/' + name + '.hx';
		var replacePath:String = Paths.modFolders(scriptFile);
		if(FileSystem.exists(replacePath))
		{
			scriptFile = replacePath;
			doPush = true;
		}
		else
		{
			scriptFile = Paths.getPreloadPath(scriptFile);
			doPush = FileSystem.exists(scriptFile);
		}
		
		if(doPush && !SScript.global.exists(scriptFile)) initHScript(scriptFile);
		#end
	}

	public function getLuaObject(tag:String, text:Bool=true):FlxSprite {
		#if LUA_ALLOWED
		if (modchartSprites.exists(tag))		return modchartSprites.get(tag);
		if (text && modchartTexts.exists(tag))	return modchartTexts.get(tag);
		if (variables.exists(tag))				return variables.get(tag);
		#end
		return null;
	}

	function startCharacterPos(char:Character, ?gfCheck:Bool = false) {
		if(gfCheck && char.curCharacter.startsWith('gf')) { //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_POS.x, GF_POS.y);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	private var video:VideoHandler = null;
	public function startVideo(name:String, subtitles:Bool = false, antialias:Bool = true) // TODO: actual subtitles
	{
		#if VIDEOS_ALLOWED
			inCutscene = true;

			var filepath:String = Paths.video(name);
			#if sys
			if(!FileSystem.exists(filepath))
			#else
			if(!OpenFlAssets.exists(filepath))
			#end
			{
				FlxG.log.warn('Couldnt find video file: ' + name);
				startAndEnd();
				return;
			}

			playingVideo = true;
			video = new VideoHandler(/*antialias*/);
			//video.play(filepath);
			//video.onEndReached.add(endVideo);
			#if (hxCodec >= "3.0.0")
				// Recent versions
				video.play(filepath);
				video.onEndReached.add(endVideo, true);
			#else
				// Older versions
				video.playVideo(filepath);
				video.finishCallback = endVideo;
			#end
		#else
			FlxG.log.warn('Platform not supported!');
			startAndEnd();
			return;
		#end
	}

	function endVideo()
	{
		#if VIDEOS_ALLOWED
		playingVideo = false;
		video.stop();
		//video.dispose();
		#if (hxCodec >= "3.0.0") video.dispose(); #end
		startAndEnd();
		video = null;
		//return;
		#end
	}

	function startAndEnd() endingSong ? endSong() : startCountdown();

	var dialogueCount:Int = 0;
	public var psychDialogue:DialogueBoxPsych;
	//You don't have to add a song, just saying. You can just do "startDialogue(DialogueBoxPsych.parseDialogue(Paths.json(songName + '/dialogue')))" and it should load dialogue.json
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null)
	{
		// TO DO: Make this more flexible, maybe?
		if(psychDialogue != null) return;

		if(dialogueFile.dialogue.length > 0) {
			inCutscene = true;
			precacheList.set('dialogue', 'sound');
			precacheList.set('dialogueClose', 'sound');
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.finishThing = function() {
				psychDialogue = null;
				endingSong ? endSong() : startCountdown();
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		} else {
			FlxG.log.warn('Your dialogue file is badly formatted!');
			startAndEnd();
		}
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;
	public static var startOnTime:Float = 0.0;

	function cacheCountdown()
	{
		// no more useless maps!!!
		Paths.image(uiPrefix + 'ready' + uiSuffix);
		Paths.image(uiPrefix + 'set' + uiSuffix);
		Paths.image(uiPrefix + 'go' + uiSuffix);
		
		Paths.sound('intro3'  + introSoundsSuffix);
		Paths.sound('intro2'  + introSoundsSuffix);
		Paths.sound('intro1'  + introSoundsSuffix);
		Paths.sound('introGo' + introSoundsSuffix);
	}

	public function startCountdown()
	{
		if(startedCountdown) {
			callOnScripts('onStartCountdown');
			return false;
		}

		seenCutscene = true;
		inCutscene = false;
		var ret:Dynamic = callOnScripts('onStartCountdown', null, true);
		if(ret != FunkinLua.Function_Stop) {
			if (skipCountdown || startOnTime > 0) skipArrowStartTween = true;

			generateStaticArrows(0);
			generateStaticArrows(1);
			for (i in 0...playerStrums.length)
			{
				setOnScripts('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				setOnScripts('defaultPlayerStrumY' + i, playerStrums.members[i].y);
			}
			for (i in 0...opponentStrums.length)
			{
				setOnScripts('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				setOnScripts('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
			}

			startedCountdown = true;
			Conductor.songPosition = -Conductor.crochet * 5;
			setOnScripts('startedCountdown', true);
			callOnScripts('onCountdownStarted');

			if (startOnTime > 0) {
				clearNotesBefore(startOnTime);
				setSongTime(startOnTime - 350);
				return true;
			}
			else if (skipCountdown)
			{
				setSongTime(0);
				return true;
			}
			moveCameraSection();

			var swagCounter:Int = 0;
			var tick:Countdown = THREE;
			var antialias:Bool = (ClientPrefs.data.antialiasing && !isPixelStage);
			var countSound:FlxSound = null;

			startTimer = new FlxTimer().start(Conductor.crochet * 0.001 / playbackRate, function(tmr:FlxTimer)
			{
				charsDance(tmr.loopsLeft);

				switch (swagCounter)
				{
					case 0:
						countSound = FlxG.sound.play(Paths.sound('intro3' + introSoundsSuffix), 0.6);
						tick = THREE;
					case 1:
						countdownReady = createCountdownSprite(uiPrefix + 'ready' + uiSuffix, antialias); // automatic sprite handeling😱😱
						countSound = FlxG.sound.play(Paths.sound('intro2' + introSoundsSuffix), 0.6);
						tick = TWO;
					case 2:
						countdownSet = createCountdownSprite(uiPrefix + 'set' + uiSuffix, antialias);
						countSound = FlxG.sound.play(Paths.sound('intro1' + introSoundsSuffix), 0.6);
						tick = ONE;
					case 3:
						countdownGo = createCountdownSprite(uiPrefix + 'go' + uiSuffix, antialias);
						countSound = FlxG.sound.play(Paths.sound('introGo' + introSoundsSuffix), 0.6);
						tick = GO;
					case 4:
						tick = START;
				}
				#if FLX_PITCH if (countSound != null) countSound.pitch = playbackRate; #end

				notes.forEachAlive(function(note:Note)
					if(ClientPrefs.data.opponentStrums || note.mustPress)
					{
						note.copyAlpha = false;
						note.alpha = note.multAlpha * ((ClientPrefs.data.middleScroll && !note.mustPress) ? 0.35 : 1);
					}
				);

				stagesFunc(function(stage:BaseStage) stage.countdownTick(tick, swagCounter));
				callOnLuas('onCountdownTick', [swagCounter]);
				callOnHScript('onCountdownTick', [tick, swagCounter]);

				swagCounter++;
			}, 5);
		}
		return true;
	}

	inline private function createCountdownSprite(image:String, antialias:Bool):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite(0, 0, Paths.image(image));
		spr.cameras = [camHUD];
		if (isPixelStage) {
			spr.setGraphicSize(Std.int(spr.width * daPixelZoom));
			spr.updateHitbox();
		}
		spr.screenCenter();
		spr.antialiasing = antialias;
		insert(members.indexOf(notes), spr);

		FlxTween.num(1, 0, Conductor.crochet * 0.001, {ease: FlxEase.cubeInOut}, function(a:Float) {
			spr.alpha = a;
			if (a == 0) remove(spr).destroy();
		});
		return spr;
	}

	public function addBehindGF(obj:FlxBasic):FlxBasic	return insert(members.indexOf(gfGroup), obj);
	public function addBehindBF(obj:FlxBasic):FlxBasic	return insert(members.indexOf(boyfriendGroup), obj);
	public function addBehindDad(obj:FlxBasic):FlxBasic	return insert(members.indexOf(dadGroup), obj);

	public function clearNotesBefore(time:Float)
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0) {
			var daNote:Note = unspawnNotes[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.destroy();
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0) {
			var daNote:Note = notes.members[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				notes.remove(daNote, true);
				daNote.destroy();
			}
			--i;
		}
	}

	public var charList:Array<Character> = [];
	dynamic public function charsDance(reference:Int, force:Bool = false) // quick 'n' easy way to bop all characters
	{
		for (char in charList)
			if (char != null)
			{
				var doDance:Bool = reference % (char == gf ? Math.round(gfSpeed * char.danceEveryNumBeats) : char.danceEveryNumBeats) == 0;
				if (doDance && #if (haxe > "4.2.5") !char.animation.curAnim?.name.startsWith("sing")
					#else char.animation.curAnim != null && char.animation.curAnim.name.startsWith("sing") #end && !char.stunned)
					char.dance(force);
			}
	}

	/** from https://github.com/ShadowMario/FNF-PsychEngine/pull/13586 **/
	// too lazy to switch to the experemental branch + gutarhero sustains suck, change my mind - richTrash21

	// fun fact: Dynamic Functions can be overriden by just doing this
	// `updateScore = function(miss:Bool = false) { ... }
	// its like if it was a variable but its just a function!
	// cool right? -Crow
	public dynamic function updateScore(miss:Bool = false)
	{
		var str:String = ratingName;
		var percent:Float = CoolUtil.floorDecimal(ratingPercent * 100, 2);
		if(totalPlayed != 0)
			str += ' (${percent}%) - ${ratingFC}';

		var tempScore:String = 'Score: ${songScore}'
		+ (!instakillOnMiss ? ' | Misses: ${songMisses}' : "")
		+ ' | Rating: ${str}';
		// "tempScore" variable is used to prevent another memory leak, just in case
		// "\n" here prevents the text from being cut off by beat zooms
		scoreTxt.text = '${tempScore}\n';

		//scoreTxt.text = 'Score: ' + songScore + ' | Misses: ' + songMisses + ' | Rating: ' + str;

		if(ClientPrefs.data.scoreZoom && !miss && !cpuControlled && !startingSong)
		{
			if(scoreTxtTween != null) scoreTxtTween.cancel();
			scoreTxt.scale.set(1.075, 1.075);
			scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
				onComplete: function(twn:FlxTween) scoreTxtTween = null
			});
		}
		callOnScripts('onUpdateScore', [miss]);
	}

	public dynamic function fullComboFunction()
	{
		var sicks:Int = ratingsData[0].hits;
		var goods:Int = ratingsData[1].hits;
		var bads:Int = ratingsData[2].hits;
		var shits:Int = ratingsData[3].hits;

		ratingFC = "";
		if(songMisses == 0)
		{
			if (bads > 0 || shits > 0) ratingFC = 'FC';
			else if (goods > 0) ratingFC = 'GFC';
			else if (sicks > 0) ratingFC = 'SFC';
		}
		else ratingFC = (songMisses < 10) ? 'SDCB' : 'Clear';
	}

	public function setSongTime(time:Float)
	{
		if(time < 0) time = 0;

		//FlxG.sound.music.pause();

		FlxG.sound.music.time = time;
		//#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		//FlxG.sound.music.play();

		if (SONG.needsVoices && Conductor.songPosition <= vocals.length)
		{
			vocals.pause();
			vocals.time = time;
			//#if FLX_PITCH vocals.pitch = playbackRate; #end
			if (!startingSong) vocals.play();
		}
		Conductor.songPosition = time;
	}

	public function startNextDialogue() {
		dialogueCount++;
		callOnScripts('onNextDialogue', [dialogueCount]);
	}

	public function skipDialogue() {
		callOnScripts('onSkipDialogue', [dialogueCount]);
	}

	//var showcaseTxt:FlxText;
	function startSong():Void
	{
		startingSong = false;

		@:privateAccess
		FlxG.sound.playMusic(inst._sound, 1, false);
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		FlxG.sound.music.onComplete = finishSong.bind();
		if (SONG.needsVoices) vocals.play();

		if (startOnTime > 0) setSongTime(startOnTime - 500);
		startOnTime = 0;

		if (paused)
		{
			FlxG.sound.music.pause();
			/*if (SONG.needsVoices)*/ vocals.pause();
		}

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		FlxTween.num(0, 1, 0.5, {ease: FlxEase.circOut}, function(a:Float) timeBar.alpha = timeTxt.alpha = a);

		/*if(ClientPrefs.getGameplaySetting('showcase')) {
			showcaseTxt = new FlxText(30, FlxG.height - 55, 0, "> SHOWCASE", 32);
			showcaseTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			showcaseTxt.borderSize = 1.25;
			showcaseTxt.alpha = 0;
			add(showcaseTxt);
			showcaseTxt.cameras = [camOther];
			//FlxTween.tween(showcaseTxt, {alpha: 1}, 1.6, {ease: FlxEase.backOut, type: FlxTweenType.PINGPONG});
		}*/

		#if desktop
		// Updating Discord Rich Presence (with Time Left)
		DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.char, true, songLength);
		#end
		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart');
	}

	private var noteTypes:Array<String> = [];
	private var eventsPushed:Array<String> = [];
	private function generateSong(dataPath:String):Void
	{
		songSpeed = SONG.speed;
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype');
		switch(songSpeedType)
		{
			case "multiplicative":	songSpeed *= ClientPrefs.getGameplaySetting('scrollspeed');
			case "constant":		songSpeed  = ClientPrefs.getGameplaySetting('scrollspeed');
		}

		// whyyyy??????
		// ok nvmd
		var songData = SONG;
		Conductor.bpm = songData.bpm;
		curSong = songData.song;

		vocals = new FlxSound();
		if (songData.needsVoices)
		{
			vocals.loadEmbedded(Paths.voices(songData.song));
			#if FLX_PITCH vocals.pitch = playbackRate; #end
		}
		FlxG.sound.list.add(vocals);

		inst = new FlxSound().loadEmbedded(Paths.inst(songData.song));
		FlxG.sound.list.add(inst);

		notes = new FlxTypedGroup<Note>();
		add(notes);

		// NEW SHIT
		var noteData:Array<SwagSection> = songData.notes;

		var file:String = Paths.json(songName + '/events');
		#if MODS_ALLOWED
		if (FileSystem.exists(Paths.modsJson(songName + '/events')) || FileSystem.exists(file))
		#else
		if (OpenFlAssets.exists(file))
		#end
		{
			var eventsData:Array<Dynamic> = Song.loadFromJson('events', songName).events;
			for (event in eventsData) //Event Notes
				for (i in 0...event[1].length)
					makeEvent(event, i);
		}

		for (section in noteData)
		{
			for (songNotes in section.sectionNotes)
			{
				var daStrumTime:Float = songNotes[0];
				var daNoteData:Int = Std.int(songNotes[1] % 4);
				var gottaHitNote:Bool = songNotes[1] > 3 ? !section.mustHitSection : section.mustHitSection;
				var oldNote:Note = (unspawnNotes.length > 0) ? unspawnNotes[unspawnNotes.length - 1] : null;

				var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote);
				swagNote.mustPress = gottaHitNote;
				swagNote.sustainLength = songNotes[2];
				swagNote.gfNote = (section.gfSection && (songNotes[1]<4));
				swagNote.noteType = Std.isOfType(songNotes[3], String)
					? songNotes[3]
					: ChartingState.noteTypeList[songNotes[3]]; //Backward compatibility + compatibility with Week 7 charts
				unspawnNotes.push(swagNote);

				var floorSus:Int = Math.floor(swagNote.sustainLength / Conductor.stepCrochet);
				if(floorSus > 0) {
					for (susNote in 0...floorSus+1)
					{
						oldNote = unspawnNotes[unspawnNotes.length-1];

						var sustainNote:Note = new Note(daStrumTime + (Conductor.stepCrochet * susNote), daNoteData, oldNote, true);
						sustainNote.mustPress = gottaHitNote;
						sustainNote.gfNote = (section.gfSection && (songNotes[1]<4));
						sustainNote.noteType = swagNote.noteType;
						swagNote.tail.push(sustainNote);
						sustainNote.parent = swagNote;
						unspawnNotes.push(sustainNote);
						
						sustainNote.correctionOffset = swagNote.height * 0.5;
						if(!isPixelStage)
						{
							if(oldNote.isSustainNote)
							{
								oldNote.scale.y *= Note.SUSTAIN_SIZE / oldNote.frameHeight;
								oldNote.scale.y /= playbackRate;
								oldNote.updateHitbox();
							}

							if(ClientPrefs.data.downScroll) sustainNote.correctionOffset = 0;
						}
						else if(oldNote.isSustainNote)
						{
							oldNote.scale.y /= playbackRate;
							oldNote.updateHitbox();
						}

						if (sustainNote.mustPress)				sustainNote.x += FlxG.width * 0.5; // general offset
						else if (ClientPrefs.data.middleScroll)	sustainNote.x += daNoteData > 1 ? FlxG.width * 0.5 + 335 : 310;
					}
				}

				if (swagNote.mustPress)					swagNote.x += FlxG.width * 0.5; // general offset
				else if (ClientPrefs.data.middleScroll)	swagNote.x += daNoteData > 1 ? FlxG.width * 0.5 + 335 : 310;

				if(!noteTypes.contains(swagNote.noteType)) noteTypes.push(swagNote.noteType);
			}
		}
		//Event Notes
		for (event in songData.events)
			for (i in 0...event[1].length)
				makeEvent(event, i);

		unspawnNotes.sort(sortByTime);
		generatedMusic = true;
	}

	// called only once per different event (Used for precaching)
	function eventPushed(event:EventNote)
	{
		eventPushedUnique(event);
		if(eventsPushed.contains(event.event)) return;

		stagesFunc(function(stage:BaseStage) stage.eventPushed(event));
		eventsPushed.push(event.event);
	}

	// called by every event with the same name
	function eventPushedUnique(event:EventNote)
	{
		switch(event.event) {
			case "Change Character":
				var charType:Int = 0;
				switch(event.value1.toLowerCase())
				{
					case 'gf' | 'girlfriend' | '1': charType = 2;
					case 'dad' | 'opponent' | '0':  charType = 1;
					default:
						var val1:Int = Std.parseInt(event.value1);
						if(Math.isNaN(val1)) val1 = 0;
						charType = val1;
				}

				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, charType);
			
			case 'Play Sound':
				precacheList.set(event.value1, 'sound');
				Paths.sound(event.value1);
		}
		stagesFunc(function(stage:BaseStage) stage.eventPushedUnique(event));
	}

	function eventEarlyTrigger(event:EventNote):Float
	{
		var ret:Null<Float> = callOnScripts('eventEarlyTrigger', [event.event, event.value1, event.value2, event.strumTime], true, [], [0]);
		if(ret != null && ret != 0 && ret != FunkinLua.Function_Continue)
			return ret;

		switch(event.event)
		{
			case 'Kill Henchmen': //Better timing so that the kill sound matches the beat intended
				return 280; //Plays 280ms before the actual position
		}
		return 0;
	}

	public static function sortByTime(Obj1:Dynamic, Obj2:Dynamic):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);

	function makeEvent(event:Array<Dynamic>, i:Int)
	{
		var subEvent:EventNote = {
			strumTime: event[0] + ClientPrefs.data.noteOffset,
			event: event[1][i][0],
			value1: event[1][i][1],
			value2: event[1][i][2]
		};
		eventNotes.push(subEvent);
		eventPushed(subEvent);
		callOnScripts('onEventPushed', [subEvent.event, #if (haxe > "4.2.5") subEvent.value1 ?? '', subEvent.value2 ?? ''
			#else subEvent.value1 != null ? subEvent.value1 : '', subEvent.value2 != null ? subEvent.value2 : '' #end, subEvent.strumTime]);
	}

	public var skipArrowStartTween:Bool = false; //for lua
	private function generateStaticArrows(player:Int):Void
	{
		final strumLineX:Float = ClientPrefs.data.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X;
		final strumLineY:Float = ClientPrefs.data.downScroll ? (FlxG.height - 150) : 50.0;
		for (i in 0...4)
		{
			var targetAlpha:Float = 1.0;
			if (player < 1)
			{
				if (!ClientPrefs.data.opponentStrums)	targetAlpha = 0;
				else if (ClientPrefs.data.middleScroll)	targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote(strumLineX, strumLineY, i, player);
			babyArrow.downScroll = ClientPrefs.data.downScroll;
			if (!isStoryMode && !skipArrowStartTween)
			{
				//babyArrow.y -= 10;
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
			}
			else babyArrow.alpha = targetAlpha;

			if (player == 1) playerStrums.add(babyArrow);
			else
			{
				if(ClientPrefs.data.middleScroll) babyArrow.x += i > 1 ? FlxG.width * 0.5 + 335 : 310;
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();
		}
	}

	override function openSubState(SubState:FlxSubState)
	{
		stagesFunc(function(stage:BaseStage) stage.openSubState(SubState));
		if (paused)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				/*if(vocals != null)*/ vocals.pause();
			}

			if(startTimer != null && !startTimer.finished)	  startTimer.active = false;
			if(finishTimer != null && !finishTimer.finished)  finishTimer.active = false;
			if(songSpeedTween != null)						  songSpeedTween.active = false;

			for (char in charList)
				if(#if (haxe > "4.2.5") char?.colorTween #else char != null && char.colorTween #end != null)
					char.colorTween.active = false;

			#if LUA_ALLOWED
			for (tween in modchartTweens) tween.active = false;
			for (timer in modchartTimers) timer.active = false;
			#end

			// TODO: FINISH THIS SHIT
			/*@:privateAccess FlxTween.globalManager.forEach(function(tween:FlxTween)
				if(!tween.isTweenOf(SubState)) tween.active = false
			);
			// TODO: better way of pausing timers on substate opening
			FlxTimer.globalManager.forEach(function(timer:FlxTimer) timer.active = false);
			for(sound in FlxG.sound.list) {

			}*/
		}

		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		stagesFunc(function(stage:BaseStage) stage.closeSubState());
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong) resyncVocals();

			/*
			if (startTimer != null && !startTimer.finished)	  startTimer.active = true;
			if (finishTimer != null && !finishTimer.finished) finishTimer.active = true;
			if (songSpeedTween != null)						  songSpeedTween.active = true;
			
			for (char in charList)
				if(#if (haxe > "4.2.5") char?.colorTween #else char != null && char.colorTween #end != null)
					char.colorTween.active = false;

			#if LUA_ALLOWED
			for (tween in modchartTweens) tween.active = true;
			for (timer in modchartTimers) timer.active = true;
			#end
			*/

			FlxTween.globalManager.forEach(function(tween:FlxTween) tween.active = true);
			FlxTimer.globalManager.forEach(function(timer:FlxTimer) timer.active = true);
			FlxG.sound.resume();

			paused = false;
			callOnScripts('onResume');
			resetRPC(#if (haxe > "4.2.5") startTimer?.finished ?? false #else startTimer != null && startTimer.finished #end);
		}

		super.closeSubState();
	}

	override public function onFocus():Void
	{
		var ret:Dynamic = callOnScripts('onFocus', null, true);
		if (ret == FunkinLua.Function_Stop) {
			super.onFocus();
			return;
		}
		if (health > 0 && !paused) resetRPC(Conductor.songPosition > 0.0);
		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		var ret:Dynamic = callOnScripts('onFocusLost', null, true);
		if (ret == FunkinLua.Function_Stop) {
			super.onFocusLost();
			return;
		}
		#if desktop
		if (health >= 0 && !paused) DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.char);
		#end
		if(!FlxG.autoPause && startedCountdown && canPause && !paused)
		{
			var ret:Dynamic = callOnScripts('onPause', null, true);
			if(ret != FunkinLua.Function_Stop) openPauseMenu(); // idk
		}
		super.onFocusLost();
	}

	// Updating Discord Rich Presence.
	function resetRPC(?cond:Bool = false)
	{
		#if desktop
		DiscordClient.changePresence(
			detailsText,
			SONG.song + ' ($storyDifficultyText)',
			iconP2.char,
			cond,
			(cond) ? songLength - Conductor.songPosition - ClientPrefs.data.noteOffset : null
		);
		#end
	}

	function resyncVocals():Void
	{
		if(finishTimer != null || vocals == null) return;

		//FlxG.sound.music.play();
		//#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		Conductor.songPosition = FlxG.sound.music.time;
		if (Conductor.songPosition <= vocals.length)
		{
			vocals.pause();
			vocals.time = Conductor.songPosition;
			//#if FLX_PITCH vocals.pitch = playbackRate; #end
			vocals.play();
		}
	}

	public var paused(default, set):Bool = false;
	public var canReset:Bool = true;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;

	@:noCompletion inline function set_paused(bool:Bool):Bool
	{
		iconP1.lerpScale = iconP2.lerpScale = bool ? false : iconBoping;
		return paused = camGame.paused = camHUD.paused = bool;
	}

	override public function update(elapsed:Float)
	{
		callOnScripts('onUpdate', [elapsed]);

		//camGame.followLerp = 0;
		if(!inCutscene && !paused)
		{
			/**
			 *	--[ idk, just wanted to write smth out of my frustration atm - `richTrash21` ]--
			 *
			 *	!!! calcs below was mesured with `elapsed = 0.0024` and on `240 fps` !!!
			 *	 >  pre flixel `5.4.0` 		pixel/frame ≈ 0.0096
			 *	 >  post flixel `5.4.0`		pixel/frame ≈ 0.0006 (WTF?????????)
			 *
			 *	to achieve pre `5.4.0` lerp now you need to multiply the whole lerp value by `16`!!!
			 *	i hate being a programmer sm
			 *
			 *	UPD: FLIXEL `5.4.0` ACTUALLY MAKES CAMERA MORE JANKY (it's just sometimes teleport for no fucking reason)!
			 *	THANKS FLIXEL!!!
			 *  UPDD: nevermind they fixed it (i think)
			 *  UPDD: no they fucking don't
			 *  UPDDD: nvmd its just me being big ass dumbo
			 */
			//camGame.followLerp = elapsed * 2.4 * cameraSpeed * playbackRate #if (flixel < "5.4.0") / #else * #end (FlxG.updateFramerate / 60);
			#if ACHIEVEMENTS_ALLOWED
			(!startingSong && !endingSong && #if (haxe > "4.2.5") boyfriend.animation.curAnim?.name.startsWith('idle')
				#else boyfriend.animation.curAnim != null && boyfriend.animation.curAnim.name.startsWith('idle') #end)
				? boyfriendIdleTime += elapsed
				: boyfriendIdleTime = 0;
			#end
		}

		super.update(elapsed);

		setOnScripts('curDecStep', curDecStep);
		setOnScripts('curDecBeat', curDecBeat);

		if(#if (haxe > "4.2.5") botplayTxt?.visible #else botplayTxt != null && botplayTxt.visible #end)
		{
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
			//if(showcaseTxt != null) showcaseTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		if (controls.PAUSE && startedCountdown && canPause)
		{
			var ret:Dynamic = callOnScripts('onPause', null, true);
			if (ret != FunkinLua.Function_Stop) openPauseMenu();
		}

		//idk how it will behave on an older versions sooooo...
		//UPD: using hxvlc from now on (idfk whats the difference)
		//UPDD: nvmd back to hxcodec lmao
		#if (hxCodec >= "3.0.0")
		if (playingVideo && (controls.PAUSE || controls.ACCEPT)) endVideo();
		#end

		// :trollface:
		#if !RELESE_BUILD_FR
		if (controls.justPressed('debug_1') && !endingSong && !inCutscene) openChartEditor();
		if (controls.justPressed('debug_2') && !endingSong && !inCutscene) openCharacterEditor();
		#end

		// frameWidth > frameHeight = icon have two frames
		//final P1_frameWidth = /*iconP1.frameWidth > iconP1.frameHeight ? iconP1.frameWidth * 0.5 :*/ iconP1.frameWidth;
		//final P2_frameWidth = /*iconP2.frameWidth > iconP2.frameHeight ? iconP2.frameWidth * 0.5 :*/ iconP2.frameWidth;
		if (healthBarFlip)
		{
			iconP1.x = healthBar.centerPoint.x - (iconP1.frameWidth * iconP1.scale.x) * 0.5 - 52;
			iconP2.x = healthBar.centerPoint.x + (iconP2.frameWidth * iconP2.scale.x - iconP2.frameWidth * iconP2.baseScale) * 0.5 - 26;
		}
		else
		{
			iconP1.x = healthBar.centerPoint.x + (iconP1.frameWidth * iconP1.scale.x - iconP1.frameWidth * iconP1.baseScale) * 0.5 - 26;
			iconP2.x = healthBar.centerPoint.x - (iconP2.frameWidth * iconP2.scale.x) * 0.5 - 52;
		}
		
		if (startedCountdown && !paused) Conductor.songPosition += elapsed * 1000 * playbackRate;

		if (startingSong)
		{
			if (startedCountdown && Conductor.songPosition >= 0) startSong();
			else if (!startedCountdown) Conductor.songPosition = -Conductor.crochet * 5;
		}
		else if (!paused && updateTime)
		{
			final curTime:Float = Math.max(0, Conductor.songPosition - ClientPrefs.data.noteOffset);
			songPercent = curTime / songLength;
		}

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.data.noReset && controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong)
			health = 0;

		if (unspawnNotes[0] != null)
		{
			var time:Float = spawnTime * playbackRate;
			if (songSpeed < 1)				 	time /= songSpeed;
			if (unspawnNotes[0].multSpeed < 1)	time /= unspawnNotes[0].multSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				final dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);
				dunceNote.spawned = true;

				callOnLuas('onSpawnNote', [notes.members.indexOf(dunceNote), dunceNote.noteData, dunceNote.noteType, dunceNote.isSustainNote, dunceNote.strumTime]);
				callOnHScript('onSpawnNote', [dunceNote]);

				unspawnNotes.splice(unspawnNotes.indexOf(dunceNote), 1);
			}
		}

		if (generatedMusic)
		{
			if(!inCutscene)
			{
				if(!cpuControlled)
					keysCheck();
				else if(boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 #if FLX_PITCH / FlxG.sound.music.pitch #end) * boyfriend.singDuration &&
					#if (haxe > "4.2.5") boyfriend.animation.curAnim?.name.startsWith('sing') && !boyfriend.animation.curAnim?.name.endsWith('miss')
					#else boyfriend.animation.curAnim != null && boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.animation.curAnim.name.endsWith('miss') #end)
					boyfriend.dance();

				if(notes.length > 0)
				{
					if(startedCountdown)
					{
						final fakeCrochet:Float = (60 / SONG.bpm) * 1000;
						notes.forEachAlive(function(daNote:Note)
						{
							final strumGroup:FlxTypedGroup<StrumNote> = daNote.mustPress ? playerStrums : opponentStrums;
							final strum:StrumNote = strumGroup.members[daNote.noteData];
							daNote.followStrumNote(strum, fakeCrochet, songSpeed / playbackRate);

							if(daNote.mustPress)
							{
								if(cpuControlled && !daNote.blockHit && daNote.canBeHit && (daNote.isSustainNote || daNote.strumTime <= Conductor.songPosition))
									goodNoteHit(daNote);
							}
							else if (daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote)
								opponentNoteHit(daNote);

							if(daNote.isSustainNote && strum.sustainReduce) daNote.clipToStrumNote(strum);

							// Kill extremely late notes and cause misses
							if (Conductor.songPosition - daNote.strumTime > noteKillOffset)
							{
								if (daNote.mustPress && !cpuControlled &&!daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit))
									noteMiss(daNote);

								daNote.active = false;
								daNote.visible = false;

								daNote.kill();
								notes.remove(daNote, true);
								daNote.destroy();
							}
						});
					}
					else
					{
						notes.forEachAlive(function(daNote:Note)
						{
							daNote.canBeHit = false;
							daNote.wasGoodHit = false;
						});
					}
				}
			}
			checkEventNote();
		}

		#if (debug || !RELESE_BUILD_FR)
		if(!endingSong && !startingSong)
		{
			if (FlxG.keys.justPressed.ONE)
			{
				KillNotes();
				FlxG.sound.music.onComplete();
			}
			if (FlxG.keys.justPressed.TWO) //Go 10 seconds into the future :O
			{
				setSongTime(Conductor.songPosition + (FlxG.keys.pressed.SHIFT ? 20000 : 10000) * playbackRate);
				clearNotesBefore(Conductor.songPosition);
				if(Conductor.songPosition > FlxG.sound.music.length) finishSong();
			}
			if ((FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.B) || FlxG.keys.justPressed.THREE) // quick botplay for testing shit
			{
				cpuControlled = !cpuControlled;
				changedDifficulty = false;
			}
		}
		if (FlxG.keys.pressed.F5) FlxG.resetState();
		#end

		// okay, what the fuck??????
		// why does camFollow represent camera position????

		// UPD: much better. need to make this a pull request to official psych lmao
		// UPD: nvmd won't use anyway
		setOnScripts('cameraX', camFollow.x /*camGame.scroll.x - (camGame.width * 0.5)*/);
		setOnScripts('cameraY', camFollow.y /*camGame.scroll.y - (camGame.height * 0.5)*/);
		callOnScripts('onUpdatePost', [elapsed]);
	}

	function openPauseMenu()
	{
		//camGame.updateLerp = false;
		persistentUpdate = false;
		persistentDraw = true;
		paused = true;
		FlxTween.globalManager.forEach(function(tween:FlxTween) tween.active = false); //so pause tweens wont stop
		FlxTimer.globalManager.forEach(function(timer:FlxTimer) timer.active = false);
		FlxG.sound.pause();

		/*if(FlxG.sound.music != null)
		{
			FlxG.sound.music.pause();
			if (vocals != null) vocals.pause();
		}*/
		if(!cpuControlled)
			for (note in playerStrums)
				if(#if (haxe > "4.2.5") note.animation.curAnim?.name != 'static'
				#else note.animation.curAnim != null && note.animation.curAnim.name != 'static' #end)
				{
					note.playAnim('static');
					note.resetAnim = 0;
				}

		openSubState(new PauseSubState(camOther));

		#if desktop
		DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.char);
		#end
	}

	#if !RELESE_BUILD_FR
	function openChartEditor()
	{
		//camGame.updateLerp = false;
		persistentUpdate = false;
		paused = true;
		cancelMusicFadeTween();
		chartingMode = true;

		#if desktop
		DiscordClient.changePresence("Chart Editor", null, null, true);
		DiscordClient.resetClientID();
		#end
		
		MusicBeatState.switchState(new ChartingState());
	}
	
	function openCharacterEditor()
	{
		//camGame.updateLerp = false;
		persistentUpdate = false;
		paused = true;
		cancelMusicFadeTween();
		#if desktop DiscordClient.resetClientID(); #end
		MusicBeatState.switchState(new CharacterEditorState(SONG.player2));
	}
	#end

	public var isDead:Bool = false; //Don't mess with this on Lua!!!
	function doDeathCheck(?skipHealthCheck:Bool = false) {
		if (((skipHealthCheck && instakillOnMiss) || health <= 0) && !practiceMode && !isDead)
		{
			var ret:Dynamic = callOnScripts('onGameOver', null, true);
			if(ret != FunkinLua.Function_Stop) {
				boyfriend.stunned = true;
				deathCounter++;

				paused = true;

				/*if(vocals != null)*/ vocals.stop();
				FlxG.sound.music.stop();

				persistentUpdate = false;
				persistentDraw = false;
				#if LUA_ALLOWED
				for (tween in modchartTweens) tween.active = true;
				for (timer in modchartTimers) timer.active = true;
				#end
				var screenPos:FlxPoint = boyfriend.getScreenPosition();
				openSubState(new GameOverSubstate(screenPos.x - boyfriend.positionArray[0], screenPos.y - boyfriend.positionArray[1]));
				screenPos.put();

				#if desktop
				// Game Over doesn't get his own variable because it's only used here
				DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.char);
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	public function checkEventNote() {
		while(eventNotes.length > 0) {
			var event:EventNote = eventNotes[0];
			if(Conductor.songPosition < event.strumTime) return;
			triggerEvent(event.event, #if (haxe > "4.2.5") event.value1 ?? '', event.value2 ?? ''
				#else event.value1 != null ? event.value1 : '', event.value2 != null ? event.value2 : '' #end, event.strumTime);
			eventNotes.shift();
		}
	}

	public function triggerEvent(eventName:String, value1:String, value2:String, strumTime:Float) {
		var flValue1:Null<Float> = Std.parseFloat(value1);
		var flValue2:Null<Float> = Std.parseFloat(value2);
		if (Math.isNaN(flValue1))  flValue1 = null;
		if (Math.isNaN(flValue2))  flValue2 = null;

		switch(eventName)
		{
			case 'Hey!':
				var value:Int = 2;
				switch(value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0':  value = 0;
					case 'gf' | 'girlfriend' | '1': value = 1;
				}

				if(flValue2 == null || flValue2 <= 0) flValue2 = 0.6;

				if(value != 0) {
					if(dad.curCharacter.startsWith('gf')) { //Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = flValue2;
					} else if (gf != null) {
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = flValue2;
					}
				}
				if(value != 1) {
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = flValue2;
				}

			case 'Set GF Speed':
				if(flValue1 == null || flValue1 < 1) flValue1 = 1;
				gfSpeed = Math.round(flValue1);

			case 'Add Camera Zoom':
				if(ClientPrefs.data.camZooms /*&& camGame.zoom < 1.35*/) {
					if(flValue1 == null) flValue1 = 0.015;
					if(flValue2 == null) flValue2 = 0.03;

					if (!camGame.tweeningZoom)	camGame.zoom += flValue1;
					if (!camHUD.tweeningZoom)	camHUD.zoom  += flValue2;
				}

			case 'Play Animation':
				var char:Character = dad;
				switch(value2.toLowerCase().trim()) {
					case 'bf' | 'boyfriend':  char = boyfriend;
					case 'gf' | 'girlfriend': char = gf;
					default:
						if(flValue2 == null) flValue2 = 0;
						switch(Math.round(flValue2)) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.playAnim(value1, true);
					char.specialAnim = true;
				}

			case 'Camera Follow Pos':
				if(camFollow != null)
				{
					isCameraOnForcedPos = false;
					if(flValue1 != null || flValue2 != null)
					{
						isCameraOnForcedPos = true;
						if(flValue1 == null) flValue1 = 0;
						if(flValue2 == null) flValue2 = 0;
						camFollow.x = flValue1;
						camFollow.y = flValue2;
					}
				}

			case 'Alt Idle Animation':
				var char:Character = dad;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend': char = gf;
					case 'boyfriend' | 'bf':  char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if(Math.isNaN(val)) val = 0;

						switch(val) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0.0;
					var intensity:Float = 0.0;
					if(split[0] != null) duration = Std.parseFloat(split[0].trim());
					if(split[1] != null) intensity = Std.parseFloat(split[1].trim());
					if(Math.isNaN(duration)) duration = 0.0;
					if(Math.isNaN(intensity)) intensity = 0.0;

					if(duration > 0.0 && intensity != 0.0) targetsArray[i].shake(intensity, duration);
				}


			case 'Change Character':
				var charType:Int = 0;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend': charType = 2;
					case 'dad' | 'opponent':  charType = 1;
					default:
						charType = Std.parseInt(value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				switch(charType)
				{
					case 0:
						if(boyfriend.curCharacter != value2)
						{
							if(!boyfriendMap.exists(value2)) addCharacterToList(value2, charType);

							charList.remove(boyfriend);
							var lastAlpha:Float = boyfriend.alpha;
							boyfriend.alpha = 0.00001;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							iconP1.changeIcon(boyfriend.healthIcon);
							charList.push(boyfriend);
						}
						setOnScripts('boyfriendName', boyfriend.curCharacter);

					case 1:
						if(dad.curCharacter != value2)
						{
							if(!dadMap.exists(value2)) addCharacterToList(value2, charType);

							charList.remove(dad);
							var wasGf:Bool = dad.curCharacter.startsWith('gf-') || dad.curCharacter == 'gf';
							var lastAlpha:Float = dad.alpha;
							dad.alpha = 0.00001;
							dad = dadMap.get(value2);
							if(gf != null) gf.visible = wasGf;
							dad.alpha = lastAlpha;
							iconP2.changeIcon(dad.healthIcon);
							charList.push(dad);
						}
						setOnScripts('dadName', dad.curCharacter);

					case 2:
						if(gf != null)
						{
							if(gf.curCharacter != value2)
							{
								if(!gfMap.exists(value2)) addCharacterToList(value2, charType);

								charList.remove(gf);
								var lastAlpha:Float = gf.alpha;
								gf.alpha = 0.00001;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
								charList.push(gf);
							}
							setOnScripts('gfName', gf.curCharacter);
						}
				}
				reloadHealthBarColors();

			case 'Change Scroll Speed':
				if (songSpeedType != "constant")
				{
					if(flValue1 == null) flValue1 = 1;
					if(flValue2 == null) flValue2 = 0;

					var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed') * flValue1;
					(flValue2 <= 0.0)
						? songSpeed = newValue
						: songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, flValue2 / playbackRate, {ease: FlxEase.linear,
							onComplete: function (twn:FlxTween) songSpeedTween = null});
				}

			case 'Set Property':
				try
				{
					var split:Array<String> = value1.split('.');
					(split.length > 1)
						? LuaUtils.setVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1], value2)
						: LuaUtils.setVarInArray(this, value1, value2);
				}
				catch(e)
				{
					addTextToDebug('ERROR ("Set Property" Event) - ' + e.message.substr(0, e.message.indexOf('\n')), FlxColor.RED);
				}
			
			case 'Play Sound':
				if(flValue2 == null) flValue2 = 1;
				FlxG.sound.play(Paths.sound(value1), flValue2);
		}
		
		stagesFunc(function(stage:BaseStage) stage.eventCalled(eventName, value1, value2, flValue1, flValue2, strumTime));
		callOnScripts('onEvent', [eventName, value1, value2, strumTime]);
	}

	function moveCameraSection(?sec:Null<Int>):Void {
		if (sec == null)
			sec = FlxMath.maxInt(curSection, 0);

		if (SONG.notes[sec] == null) return;

		var char:String = (!SONG.notes[sec].mustHitSection) ? 'dad' : 'boyfriend';
		if (gf != null && SONG.notes[sec].gfSection)
			char = 'gf';

		moveCamera(char);
	}

	public function moveCamera(char:String)
	{
		final charMidpoint:FlxPoint = getCameraPos(char);
		camFollow.setPosition(charMidpoint.x, charMidpoint.y);
		callOnScripts('onMoveCamera', [char]);
		charMidpoint.put();
	}

	dynamic public function getCameraPos(char:String):FlxPoint
	{
		final point:FlxPoint = FlxPoint.get();
		switch(char)
		{
			case 'dad' | 'opponent':
				dad.getMidpoint(point);
				point.x += 150 + dad.cameraPosition[0] + dadCamOffset.x;
				point.y += -100 + dad.cameraPosition[1] + dadCamOffset.y;

			case 'gf' | 'girlfriend':
				gf.getMidpoint(point);
				point.x += gf.cameraPosition[0] + gfCamOffset.x;
				point.y += gf.cameraPosition[1] + gfCamOffset.y;

			default: // boyfriend/invalid character
				boyfriend.getMidpoint(point);
				point.x += -100 - boyfriend.cameraPosition[0] + bfCamOffset.x;
				point.y += -100 + boyfriend.cameraPosition[1] + bfCamOffset.y;
		}
		return point;
	}

	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		updateTime = false;
		FlxG.sound.music.volume = 0;
		FlxG.sound.music.pause();
		//if(vocals != null) {
			vocals.pause();
			vocals.volume = 0;
		//}
		(ClientPrefs.data.noteOffset <= 0 || ignoreNoteOffset)
			? endCallback()
			: finishTimer = new FlxTimer().start(ClientPrefs.data.noteOffset * 0.001, function(tmr:FlxTimer) endCallback());
	}

	public var transitioning = false;
	public function endSong()
	{
		//Should kill you if you tried to cheat
		if(!startingSong) {
			notes.forEach(function(daNote:Note)
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset)
					health -= 0.05 * healthLoss
			);
			for (daNote in unspawnNotes)
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset)
					health -= 0.05 * healthLoss;
			if(doDeathCheck()) return false;
		}

		endingSong = true;
		canPause = false;
		deathCounter = 0;

		//FlxG.camera.pixelPerfectRender = false;
		//camHUD.pixelPerfectRender = false;
		timeBar.visible = false;
		timeTxt.visible = false;
		seenCutscene = false;
		playingVideo = false;
		camZooming = false;
		inCutscene = false;
		updateTime = false;

		#if ACHIEVEMENTS_ALLOWED
		if(achievementObj != null) return false;
		else
		{
			var noMissWeek:String = WeekData.getWeekFileName() + '_nomiss';
			var achieve:String = checkForAchievement([noMissWeek, 'ur_bad', 'ur_good', 'hype', 'two_keys', 'toastie', 'debugger']);
			if(achieve != null) {
				startAchievement(achieve);
				return false;
			}
		}
		#end

		var ret:Dynamic = callOnScripts('onEndSong', null, true);
		if(ret != FunkinLua.Function_Stop && !transitioning)
		{
			#if !switch
			var percent:Float = ratingPercent;
			if(Math.isNaN(percent)) percent = 0.0;
			Highscore.saveScore(SONG.song, songScore, storyDifficulty, percent);
			#end
			playbackRate = 1;

			#if !RELESE_BUILD_FR
			if (chartingMode)
			{
				openChartEditor();
				return false;
			}
			#end

			if (isStoryMode)
			{
				campaignScore += songScore;
				campaignMisses += songMisses;

				storyPlaylist.remove(storyPlaylist[0]);

				if (storyPlaylist.length <= 0)
				{
					Mods.loadTopMod();
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
					#if desktop DiscordClient.resetClientID(); #end

					cancelMusicFadeTween();
					if(FlxTransitionableState.skipNextTransIn)
						CustomFadeTransition.nextCamera = null;
					MusicBeatState.switchState(new StoryMenuState());

					if(!ClientPrefs.getGameplaySetting('practice') && !ClientPrefs.getGameplaySetting('botplay')) {
						StoryMenuState.weekCompleted.set(WeekData.weeksList[storyWeek], true);
						Highscore.saveWeekScore(WeekData.getWeekFileName(), campaignScore, storyDifficulty);

						FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
						FlxG.save.flush();
					}
					changedDifficulty = false;
				}
				else
				{
					var difficulty:String = Difficulty.getFilePath();

					trace('LOADING NEXT SONG');
					trace(Paths.formatToSongPath(storyPlaylist[0]) + difficulty);

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
					prevCamFollow = camFollow;

					SONG = Song.loadFromJson(storyPlaylist[0] + difficulty, storyPlaylist[0]);
					FlxG.sound.music.stop();

					cancelMusicFadeTween();
					LoadingState.loadAndSwitchState(new PlayState());
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				Mods.loadTopMod();
				#if desktop DiscordClient.resetClientID(); #end

				cancelMusicFadeTween();
				if(FlxTransitionableState.skipNextTransIn)
					CustomFadeTransition.nextCamera = null;
				MusicBeatState.switchState(new FreeplayState());
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				changedDifficulty = false;
			}
			transitioning = true;
		}
		return true;
	}

	#if ACHIEVEMENTS_ALLOWED
	var achievementObj:AchievementPopup = null;
	function startAchievement(achieve:String) {
		achievementObj = new AchievementPopup(achieve, camOther);
		achievementObj.onFinish = achievementEnd;
		add(achievementObj);
		trace('Giving achievement ' + achieve);
	}
	function achievementEnd():Void
	{
		achievementObj = null;
		if(endingSong && !inCutscene) endSong();
	}
	#end

	public function KillNotes() {
		while(notes.length > 0) {
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;

			daNote.kill();
			notes.remove(daNote, true);
			daNote.destroy();
		}
		unspawnNotes = [];
		eventNotes   = [];
	}

	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0.0;

	public var showCombo:Bool	 = false;
	public var showComboNum:Bool = true;
	public var showRating:Bool	 = true;

	var lastRating:PopupSprite;			  // stores the last judgement object
	var lastCombo:PopupSprite;			  // stores the last combo sprite object
	var lastScore:Array<PopupSprite> = [];  // stores the last combo score objects in an array

	private function cachePopUpScore()
	{
		if (ClientPrefs.data.enableCombo)
		{
			for (rat in ratingsData) Paths.image(uiPrefix + rat.image + uiSuffix);
			for (i in 0...10) Paths.image(uiPrefix + 'num$i' + uiSuffix);

			// preloading first group objects (please work please work please work please work please work)
			// UPD: IT DOESN'T WAAAAAAAAAAAHHHH😭😭😭
			// https://preview.redd.it/7nskgql0k1w91.png?width=960&crop=smart&auto=webp&s=84099357cf2f7d30075e6c9989b15ef81bda9037
			/*var rating:FlxSprite = new FlxSprite(0, 0, Paths.image(uiPrefix + 'sick'  + uiSuffix));
			var combo:FlxSprite  = new FlxSprite(0, 0, Paths.image(uiPrefix + 'combo' + uiSuffix));
			var score:FlxSprite  = new FlxSprite(0, 0, Paths.image(uiPrefix + 'num0'  + uiSuffix));
			rating.alpha = combo.alpha = score.alpha = 0.000001;
			scoreGroup.add(rating);
			scoreGroup.add(combo);
			scoreGroup.add(score);*/
		}
	}

	private function popUpScore(note:Note = null):Void
	{
		//tryna do MS based judgment due to popular demand
		final daRating:Rating = Conductor.judgeNote(ratingsData, Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset) / playbackRate);		
		var score:Int = daRating.score;

		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if(!note.ratingDisabled) daRating.hits++;
		note.rating = daRating.name;

		if(daRating.noteSplash && !note.noteSplashData.disabled)
			spawnNoteSplashOnNote(note);

		if(!practiceMode && !cpuControlled) {
			songScore += score;
			if(!note.ratingDisabled)
			{
				songHits++;
				totalPlayed++;
				RecalculateRating(false);
			}
		}

		// доволен??🙄🙄
		if (ClientPrefs.data.enableCombo)
		{
			final placement:Float = FlxG.width * 0.35;
			//var antialias:Bool	  = ClientPrefs.data.antialiasing;
			var scaleMult:Float	  = 0.7;
			//var numRes:Array<Int> = [100, 120];
			var numScale:Float	  = 0.5;
			if (isPixelStage)
			{
				//antialias = false;
				scaleMult = daPixelZoom * 0.85;
				//numRes	  = [10, 12];
				numScale  = daPixelZoom * 0.85;
			}

			final noStacking:Bool = !ClientPrefs.data.comboStacking;
			if (noStacking)
			{
				scoreGroup.forEachAlive(function(spr:PopupSprite) FlxTween.completeTweensOf(spr));
				lastScore = [];
			}

			final rating:PopupSprite = scoreGroup.remove(scoreGroup.recycle(PopupSprite), true);
			rating.loadGraphic(Paths.image(uiPrefix + daRating.image + uiSuffix));
			rating.x = placement - 40 + ClientPrefs.data.comboOffset[0];
			rating.screenCenter(Y).y -= 60 + ClientPrefs.data.comboOffset[1];
			rating.setGraphicSize(Std.int(rating.width * scaleMult));
			rating.updateHitbox();

			rating.alpha = 1;
			rating.angle = 0;
			rating.setAcceleration(0, 550);
			rating.setVelocity(-FlxG.random.int(1, 10), -FlxG.random.int(140, 175));
			rating.angularVelocity = rating.velocity.x * FlxG.random.int(1, -1, [0]);
			rating.visible = (!ClientPrefs.data.hideHud && showRating);

			final comboSpr:PopupSprite = scoreGroup.remove(scoreGroup.recycle(PopupSprite), true);
			comboSpr.loadGraphic(Paths.image(uiPrefix + 'combo' + uiSuffix));
			comboSpr.x = placement + ClientPrefs.data.comboOffset[0];
			comboSpr.screenCenter(Y).y += 60 - ClientPrefs.data.comboOffset[1];
			comboSpr.setGraphicSize(Std.int(comboSpr.width * scaleMult));
			comboSpr.updateHitbox();

			comboSpr.alpha = 1;
			comboSpr.angle = 0;
			comboSpr.setAcceleration(0, FlxG.random.int(200, 300));
			comboSpr.setVelocity(FlxG.random.int(1, 10), -FlxG.random.int(140, 160));
			comboSpr.angularVelocity = rating.velocity.x * FlxG.random.int(1, -1, [0]);
			comboSpr.visible = (!ClientPrefs.data.hideHud && showCombo);

			if (isPixelStage)
				rating.antialiasing = comboSpr.antialiasing = false;

			if (showRating)	scoreGroup.add(rating);
			if (showCombo)	scoreGroup.add(comboSpr);
			if (noStacking) {
				lastRating = rating;
				lastCombo = comboSpr;
			}

			final seperatedScore:Array<Int> = [for(i in 0...(combo > 999 ? 4 : 3)) Math.floor(combo / Math.pow(10, i)) % 10];
			seperatedScore.reverse();

			var daLoop:Int = 0;
			var xThing:Float = 0.0;
			for (i in seperatedScore)
			{
				final numScore:PopupSprite = scoreGroup.remove(scoreGroup.recycle(PopupSprite), true);
				numScore.loadGraphic(Paths.image(uiPrefix + 'num$i' + uiSuffix));
				//numScore.loadGraphic(Paths.image(uiPrefix + 'num' + uiSuffix), true, numRes[0], numRes[1]);
				numScore.x = placement + (45 * daLoop) - 90 + ClientPrefs.data.comboOffset[2];
				numScore.screenCenter(Y).y += 80 - ClientPrefs.data.comboOffset[3];
				/*(#if (haxe > "4.2.5") numScore.frames?.frames[i] != null #else numScore.frames != null && numScore.frames.frames[i] != null #end)
					? numScore.frame = numScore.frames.frames[i]
					: numScore.loadGraphic("flixel/images/logo/default.png"); //prevents crash*/
				numScore.setGraphicSize(Std.int(numScore.width * numScale));
				numScore.updateHitbox();

				numScore.alpha = 1;
				numScore.angle = 0;
				numScore.offset.add(FlxG.random.int(-1, 1), FlxG.random.int(-1, 1));
				numScore.setAcceleration(0, FlxG.random.int(200, 300));
				numScore.setVelocity(FlxG.random.float(-5, 5), -FlxG.random.int(140, 160));
				numScore.angularVelocity = -numScore.velocity.x;
				numScore.visible = !ClientPrefs.data.hideHud;
				if (isPixelStage) numScore.antialiasing = false;

				if (showComboNum) scoreGroup.add(numScore);
				if (noStacking)   lastScore.push(numScore);

				FlxTween.tween(numScore, {alpha: 0}, 0.2 / playbackRate, {startDelay: Conductor.crochet * 0.002 / playbackRate,
					onComplete: function(t:FlxTween) numScore.kill()});

				if(numScore.x > xThing) xThing = numScore.x;
				daLoop++;
			}
			comboSpr.x = xThing + 50;
			FlxTween.tween(rating, {alpha: 0}, 0.2 / playbackRate, {startDelay: Conductor.crochet * 0.001 / playbackRate,
				onComplete: function(tween:FlxTween) rating.kill()});
			FlxTween.tween(comboSpr, {alpha: 0}, 0.2 / playbackRate, {startDelay: Conductor.crochet * 0.002 / playbackRate,
				onComplete: function(tween:FlxTween) comboSpr.kill()});
		}
	}

	public var strumsBlocked:Array<Bool> = [];
	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);
		if (!controls.controllerMode && FlxG.keys.checkStatus(eventKey, JUST_PRESSED)) keyPressed(key);
	}

	private function keyPressed(key:Int)
	{
		if (!cpuControlled && startedCountdown && !paused && key > -1)
		{
			if(notes.length > 0 && !boyfriend.stunned && generatedMusic && !endingSong)
			{
				//more accurate hit time for the ratings?
				var lastTime:Float = Conductor.songPosition;
				if(Conductor.songPosition >= 0) Conductor.songPosition = FlxG.sound.music.time;

				var canMiss:Bool = !ClientPrefs.data.ghostTapping;

				// heavily based on my own code LOL if it aint broke dont fix it
				var pressNotes:Array<Note> = [];
				var notesStopped:Bool = false;
				var sortedNotesList:Array<Note> = [];
				notes.forEachAlive(function(daNote:Note)
				{
					if (strumsBlocked[daNote.noteData] != true && daNote.canBeHit && daNote.mustPress &&
						!daNote.tooLate && !daNote.wasGoodHit && !daNote.isSustainNote && !daNote.blockHit)
					{
						if(daNote.noteData == key) sortedNotesList.push(daNote);
						canMiss = true;
					}
				});
				sortedNotesList.sort(sortHitNotes);

				if (sortedNotesList.length > 0) {
					for (epicNote in sortedNotesList)
					{
						for (doubleNote in pressNotes) {
							if (Math.abs(doubleNote.strumTime - epicNote.strumTime) < 1) {
								doubleNote.kill();
								notes.remove(doubleNote, true);
								doubleNote.destroy();
							} else
								notesStopped = true;
						}

						// eee jack detection before was not super good
						if (!notesStopped) {
							goodNoteHit(epicNote);
							pressNotes.push(epicNote);
						}

					}
				}
				else {
					callOnScripts('onGhostTap', [key]);
					if (canMiss && !boyfriend.stunned) noteMissPress(key);
				}

				// I dunno what you need this for but here you go
				//									- Shubs

				// Shubs, this is for the "Just the Two of Us" achievement lol
				//									- Shadow Mario
				#if ACHIEVEMENTS_ALLOWED
				if(!keysPressed.contains(key)) keysPressed.push(key);
				#end

				//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
				Conductor.songPosition = lastTime;
			}

			var spr:StrumNote = playerStrums.members[key];
			if(strumsBlocked[key] != true && #if (haxe > "4.2.5") spr?.animation.curAnim.name #else spr != null && spr.animation.curAnim.name #end != 'confirm')
			{
				spr.playAnim('pressed');
				spr.resetAnim = 0;
			}
			callOnScripts('onKeyPress', [key]);
		}
	}

	public static function sortHitNotes(a:Note, b:Note):Int
	{
		if (a.lowPriority && !b.lowPriority)	  return 1;
		else if (!a.lowPriority && b.lowPriority) return -1;
		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var key:Int = getKeyFromEvent(keysArray, event.keyCode);
		if(!controls.controllerMode && key > -1) keyReleased(key);
	}

	private function keyReleased(key:Int)
	{
		if(!cpuControlled && startedCountdown && !paused)
		{
			var spr:StrumNote = playerStrums.members[key];
			if(spr != null)
			{
				spr.playAnim('static');
				spr.resetAnim = 0;
			}
			callOnScripts('onKeyRelease', [key]);
		}
	}

	public static function getKeyFromEvent(arr:Array<String>, key:FlxKey):Int
	{
		if(key != NONE)
		{
			for (i in 0...arr.length)
			{
				var note:Array<FlxKey> = Controls.instance.keyboardBinds[arr[i]];
				for (noteKey in note) if(key == noteKey) return i;
			}
		}
		return -1;
	}

	// Hold notes
	private function keysCheck():Void
	{
		// HOLDING
		var holdArray:Array<Bool> = [];
		var pressArray:Array<Bool> = [];
		var releaseArray:Array<Bool> = [];
		for (key in keysArray)
		{
			holdArray.push(controls.pressed(key));
			pressArray.push(controls.justPressed(key));
			releaseArray.push(controls.justReleased(key));
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(controls.controllerMode && pressArray.contains(true))
			for (i in 0...pressArray.length)
				if(pressArray[i] && strumsBlocked[i] != true)
					keyPressed(i);

		if (startedCountdown && !boyfriend.stunned && generatedMusic)
		{
			// rewritten inputs???
			if(notes.length > 0)
			{
				notes.forEachAlive(function(daNote:Note)
					// hold note functions
					if (strumsBlocked[daNote.noteData] != true && daNote.isSustainNote && holdArray[daNote.noteData] && daNote.canBeHit
					&& daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.blockHit)
						goodNoteHit(daNote)
				);
			}

			if (holdArray.contains(true) && !endingSong) {
				#if ACHIEVEMENTS_ALLOWED
				var achieve:String = checkForAchievement(['oversinging']);
				if (achieve != null) startAchievement(achieve);
				#end
			}
			else if (boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 #if FLX_PITCH / FlxG.sound.music.pitch #end)
				* boyfriend.singDuration && #if (haxe > "4.2.5") boyfriend.animation.curAnim?.name.startsWith('sing') && !boyfriend.animation.curAnim?.name.endsWith('miss')
				#else boyfriend.animation.curAnim != null && boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.animation.curAnim.name.endsWith('miss') #end)
				boyfriend.dance();
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if((controls.controllerMode || strumsBlocked.contains(true)) && releaseArray.contains(true))
			for (i in 0...releaseArray.length)
				if(releaseArray[i] || strumsBlocked[i] == true)
					keyReleased(i);
	}

	function noteMiss(daNote:Note):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		//Dupe note remove
		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1) {
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		});
		
		noteMissCommon(daNote.noteData, daNote);
		var result:Dynamic = callOnLuas('noteMiss', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote]);
		if(result != FunkinLua.Function_Stop && result != FunkinLua.Function_StopHScript && result != FunkinLua.Function_StopAll) callOnHScript('noteMiss', [daNote]);
	}

	function noteMissPress(direction:Int = 1):Void //You pressed a key when there was no notes to press for this key
	{
		if(ClientPrefs.data.ghostTapping) return; //fuck it

		noteMissCommon(direction);
		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		callOnScripts('noteMissPress', [direction]);
	}

	function noteMissCommon(direction:Int, note:Note = null)
	{
		// score and data
		var subtract:Float = #if (haxe > "4.2.5") note?.missHealth ?? 0.05 #else note != null ? note.missHealth : 0.05 #end;
		health -= subtract * healthLoss;

		if(instakillOnMiss) doDeathCheck(true);
		combo = 0;

		if (!practiceMode)	songScore -= 10;
		if (!endingSong)	songMisses++;
		totalPlayed++;
		RecalculateRating(true);

		// play character anims
		var char:Character = #if (haxe > "4.2.5") (note?.gfNote || SONG.notes[curSection]?.gfSection)
			#else ((note != null && note.gfNote) || (SONG.notes[curSection] != null && SONG.notes[curSection].gfSection)) #end
			? gf : boyfriend;
		
		#if (haxe > "4.2.5")
		if(char?.hasMissAnimations && !note?.noMissAnimation)
		#else
		if(char != null && char.hasMissAnimations && note != null && !note.noMissAnimation)
		#end
		{
			var suffix:String = note != null ? note.animSuffix : '';
			var animToPlay:String = singAnimations[direction] + 'miss' + suffix;
			char.playAnim(animToPlay, true);
			
			if(char != gf && combo > 5 && #if (haxe > "4.2.5") gf?.animOffsets.exists('sad') #else gf != null && gf.animOffsets.exists('sad') #end)
			{
				gf.playAnim('sad');
				gf.specialAnim = true;
			}
		}
		/*if (vocals != null)*/ vocals.volume = 0;
	}

	function opponentNoteHit(note:Note):Void
	{
		camZooming = true;

		if(note.noteType == 'Hey!' && dad.animOffsets.exists('hey')) {
			dad.playAnim('hey', true);
			dad.specialAnim = true;
			dad.heyTimer = 0.6;
		} else if(!note.noAnimation) {
			var altAnim:String = #if (haxe > "4.2.5") (SONG.notes[curSection]?.altAnim && !SONG.notes[curSection]?.gfSection)
								 #else (SONG.notes[curSection] != null && SONG.notes[curSection].altAnim && !SONG.notes[curSection].gfSection) #end
								 ? '-alt' : note.animSuffix;

			var animToPlay:String = singAnimations[note.noteData] + altAnim;
			var char:Character = note.gfNote ? gf : dad;

			if(char != null)
			{
				char.playAnim(animToPlay, true);
				char.holdTimer = 0;
			}
		}

		/*if (vocals != null)*/ vocals.volume = 1;

		strumPlayAnim(true, note.noteData, Conductor.stepCrochet * 1.25 * 0.001 / playbackRate);
		note.hitByOpponent = true;

		var result:Dynamic = callOnLuas('opponentNoteHit', [notes.members.indexOf(note), note.noteData, note.noteType, note.isSustainNote]);
		if(result != FunkinLua.Function_Stop && result != FunkinLua.Function_StopHScript && result != FunkinLua.Function_StopAll) callOnHScript('opponentNoteHit', [note]);

		if (!note.isSustainNote)
		{
			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
	}

	function goodNoteHit(note:Note):Void
	{
		if (!note.wasGoodHit)
		{
			if(cpuControlled && (note.ignoreNote || note.hitCausesMiss)) return;

			note.wasGoodHit = true;
			if (ClientPrefs.data.hitsoundVolume > 0 && !note.hitsoundDisabled)
				FlxG.sound.play(Paths.sound(note.hitsound), ClientPrefs.data.hitsoundVolume);

			if(note.hitCausesMiss) {
				noteMiss(note);
				if(!note.noteSplashData.disabled && !note.isSustainNote) spawnNoteSplashOnNote(note);

				if(!note.noMissAnimation)
				{
					switch(note.noteType) {
						case 'Hurt Note': //Hurt note
							if(boyfriend.animation.getByName('hurt') != null) {
								boyfriend.playAnim('hurt', true);
								boyfriend.specialAnim = true;
							}
					}
				}

				if (!note.isSustainNote)
				{
					note.kill();
					notes.remove(note, true);
					note.destroy();
				}
				return;
			}

			if (!note.isSustainNote)
			{
				combo++;
				if(combo > 9999) combo = 9999;
				popUpScore(note);
			}
			health += note.hitHealth * healthGain;

			if(!note.noAnimation) {
				var animToPlay:String = singAnimations[note.noteData];
				var char:Character = boyfriend;
				var animCheck:String = 'hey';
				if(note.gfNote)
				{
					char = gf;
					animCheck = 'cheer';
				}
				
				if(char != null)
				{
					char.playAnim(animToPlay + note.animSuffix, true);
					char.holdTimer = 0;
					
					if(note.noteType == 'Hey!' && char.animOffsets.exists(animCheck)) {
						char.playAnim(animCheck, true);
						char.specialAnim = true;
						char.heyTimer = 0.6;
					}
				}
			}

			if(!cpuControlled)
			{
				var spr = playerStrums.members[note.noteData];
				if(spr != null) spr.playAnim('confirm', true);
			}
			else strumPlayAnim(false, note.noteData, Conductor.stepCrochet * 1.25 * 0.001 / playbackRate);
			/*if (vocals != null)*/ vocals.volume = 1;
			
			var result:Dynamic = callOnLuas('goodNoteHit', [notes.members.indexOf(note), note.noteData, note.noteType, note.isSustainNote]);
			if(result != FunkinLua.Function_Stop && result != FunkinLua.Function_StopHScript && result != FunkinLua.Function_StopAll) callOnHScript('goodNoteHit', [note]);

			if (!note.isSustainNote)
			{
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		}
	}

	public function spawnNoteSplashOnNote(note:Note) {
		if(note != null) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if(strum != null) spawnNoteSplash(strum.x, strum.y, note.noteData, note);
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null)
		grpNoteSplashes.add(grpNoteSplashes.remove(grpNoteSplashes.recycle(NoteSplash))).setupNoteSplash(x, y, data, note);

	override function destroy() {
		BF_POS.put();
		GF_POS.put();
		DAD_POS.put();

		bfCamOffset.put();
		dadCamOffset.put();
		gfCamOffset.put();
		
		//FlxG.camera.pixelPerfectRender = false;
		//camHUD.pixelPerfectRender = false;
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		FlxG.animationTimeScale = 1;
		#if FLX_PITCH FlxG.sound.music.pitch = 1; #end
		Note.globalRgbShaders = [];
		backend.NoteTypesConfig.clearNoteTypesData();
		if (video != null) endVideo(); // just in case

		// properly destroys custom substates now, finally!!!
		super.destroy();

		#if LUA_ALLOWED
		while (luaArray.length > 0) {
			var lua:FunkinLua = luaArray[0];
			lua.call('onDestroy', []);
			lua.stop();
		}
		FunkinLua.customFunctions.clear();
		#end

		#if HSCRIPT_ALLOWED
		while (hscriptArray.length > 0) {
			var script:HScript = hscriptArray[0];
			hscriptArray.remove(script);
			if(script != null)
			{
				script.call('onDestroy');
				#if (SScript >= "6.1.8")
				script.kill();
				#elseif (SScript >= "3.0.3")
				script.destroy();
				#end
			}
		}
		#end
		instance = null;
	}

	public static function cancelMusicFadeTween() {
		if(FlxG.sound.music.fadeTween != null) FlxG.sound.music.fadeTween.cancel();
		FlxG.sound.music.fadeTween = null;
	}

	var lastStepHit:Int = -1;
	override function stepHit()
	{
		if(FlxG.sound.music.time >= -ClientPrefs.data.noteOffset)
			if (Math.abs(FlxG.sound.music.time - (Conductor.songPosition - Conductor.offset)) > (20 * playbackRate)
				|| (SONG.needsVoices && Math.abs(vocals.time - (Conductor.songPosition - Conductor.offset)) > (20 * playbackRate)))
					resyncVocals();

		super.stepHit();
		if(curStep == lastStepHit) return;

		lastStepHit = curStep;
		FlxG.watch.addQuick("stepShit", curStep);
		setOnScripts('curStep', curStep);
		callOnScripts('onStepHit');
	}

	var lastBeatHit:Int = -1;

	override function beatHit()
	{
		if(lastBeatHit >= curBeat) return;

		if (generatedMusic) notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);

		if (iconBoping)
		{
			iconP1.setScale(1.2 * iconP1.baseScale);
			iconP2.setScale(1.2 * iconP2.baseScale);
			iconP1.updateHitbox();
			iconP2.updateHitbox();
		}

		charsDance(curBeat);

		super.beatHit();
		lastBeatHit = curBeat;

		FlxG.watch.addQuick("beatShit", curBeat);
		setOnScripts('curBeat', curBeat);
		callOnScripts('onBeatHit');
	}

	override function sectionHit()
	{
		if (SONG.notes[curSection] != null)
		{
			if (generatedMusic && !endingSong && !isCameraOnForcedPos)
				moveCameraSection(curSection);

			if (camZooming /*&& camGame.zoom < 1.35*/ && ClientPrefs.data.camZooms)
			{
				if (!camGame.tweeningZoom)	camGame.zoom += 0.015 * camZoomingMult;
				if (!camHUD.tweeningZoom)	camHUD.zoom  += 0.03 * camZoomingMult;
			}

			if (SONG.notes[curSection].changeBPM)
			{
				Conductor.bpm = SONG.notes[curSection].bpm;
				setOnScripts('curBpm', Conductor.bpm);
				setOnScripts('crochet', Conductor.crochet);
				setOnScripts('stepCrochet', Conductor.stepCrochet);
			}
			setOnScripts('mustHitSection', SONG.notes[curSection].mustHitSection);
			setOnScripts('altAnim', SONG.notes[curSection].altAnim);
			setOnScripts('gfSection', SONG.notes[curSection].gfSection);
		}
		super.sectionHit();
		
		FlxG.watch.addQuick("secShit", curSection);
		setOnScripts('curSection', curSection);
		callOnScripts('onSectionHit');
	}

	#if LUA_ALLOWED
	public function startLuasNamed(luaFile:String)
	{
		#if MODS_ALLOWED
		var luaToLoad:String = Paths.modFolders(luaFile);
		if(!FileSystem.exists(luaToLoad)) luaToLoad = Paths.getPreloadPath(luaFile);
		
		if(FileSystem.exists(luaToLoad))
		#elseif sys
		var luaToLoad:String = Paths.getPreloadPath(luaFile);
		if(OpenFlAssets.exists(luaToLoad))
		#end
		{
			for (script in luaArray) if(script.scriptName == luaToLoad) return false;
			new FunkinLua(luaToLoad);
			return true;
		}
		return false;
	}
	#end
	
	#if HSCRIPT_ALLOWED
	public function startHScriptsNamed(scriptFile:String)
	{
		var scriptToLoad:String = Paths.modFolders(scriptFile);
		if(!FileSystem.exists(scriptToLoad)) scriptToLoad = Paths.getPreloadPath(scriptFile);
		
		if(FileSystem.exists(scriptToLoad))
		{
			if (SScript.global.exists(scriptToLoad)) return false;
	
			initHScript(scriptToLoad);
			return true;
		}
		return false;
	}

	inline public function initHScript(file:String)
	{
		try
		{
			var newScript:HScript = new HScript(null, file);
			if(newScript.parsingException != null) // only last exeption error now :'(
			{
				addTextToDebug('ERROR ON LOADING ($file): ${newScript.parsingException.message.substr(0, newScript.parsingException.message.indexOf('\n'))}', FlxColor.RED);
				#if (SScript >= "6.1.8")
				newScript.kill();
				#else
				newScript.destroy();
				#end
				return;
			}

			hscriptArray.push(newScript);
			if(newScript.exists('onCreate'))
			{
				var callValue = newScript.call('onCreate');
				if(!callValue.succeeded)
				{
					for (e in callValue.exceptions)
						if (e != null) addTextToDebug('ERROR ($file: onCreate) - ${e.message.substr(0, e.message.indexOf('\n'))}', FlxColor.RED);

					#if (SScript >= "6.1.8")
					newScript.kill();
					#else
					newScript.destroy();
					#end
					hscriptArray.remove(newScript);
					trace('failed to initialize sscript interp!!! ($file)');
				}
				else trace('initialized sscript interp successfully: $file');
			}
			
		}
		catch(e)
		{
			addTextToDebug('ERROR ($file) - ' + e.message.substr(0, e.message.indexOf('\n')), FlxColor.RED);
			var newScript:HScript = cast (SScript.global.get(file), HScript);
			if(newScript != null)
			{
				#if (SScript >= "6.1.8")
				newScript.kill();
				#else
				newScript.destroy();
				#end
				hscriptArray.remove(newScript);
			}
		}
	}
	#end

	public function callOnScripts(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		if (args == null)			args = [];
		if (exclusions == null)		exclusions = [];
		if (excludeValues == null)	excludeValues = [psychlua.FunkinLua.Function_Continue];

		var result:Dynamic = callOnLuas(funcToCall, args, ignoreStops, exclusions, excludeValues);
		if (result == null || excludeValues.contains(result)) result = callOnHScript(funcToCall, args, ignoreStops, exclusions, excludeValues);
		return result;
	}

	public function callOnLuas(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = FunkinLua.Function_Continue;
		#if LUA_ALLOWED
		if (args == null)			args = [];
		if (exclusions == null)		exclusions = [];
		if (excludeValues == null)	excludeValues = [FunkinLua.Function_Continue];

		var len:Int = luaArray.length;
		var i:Int = 0;
		while(i < len)
		{
			var script:FunkinLua = luaArray[i];
			if(exclusions.contains(script.scriptName))
			{
				i++;
				continue;
			}

			var myValue:Dynamic = script.call(funcToCall, args);
			if((myValue == FunkinLua.Function_StopLua || myValue == FunkinLua.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops)
			{
				returnVal = myValue;
				break;
			}
			
			if(myValue != null && !excludeValues.contains(myValue))
				returnVal = myValue;

			(script.closed) ? len-- : i++;
		}
		#end
		return returnVal;
	}
	
	public function callOnHScript(funcToCall:String, args:Array<Dynamic> = null, ?ignoreStops:Bool = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = psychlua.FunkinLua.Function_Continue;

		#if HSCRIPT_ALLOWED
		if (exclusions == null)		exclusions = new Array();
		if (excludeValues == null)	excludeValues = new Array();
		excludeValues.push(psychlua.FunkinLua.Function_Continue);

		var len:Int = hscriptArray.length;
		if (len < 1) return returnVal;
		for(i in 0...len)
		{
			var script:HScript = hscriptArray[i];
			if(script == null || !script.exists(funcToCall) || exclusions.contains(script.origin))
				continue;

			var myValue:Dynamic = null;
			try
			{
				var callValue = script.call(funcToCall, args);
				if(!callValue.succeeded)
				{
					var e = callValue.exceptions[0];
					if(e != null)
						FunkinLua.luaTrace('ERROR (${script.origin}: ${callValue.calledFunction}) - ' + e.message.substr(0, e.message.indexOf('\n')), true, false, FlxColor.RED);
				}
				else
				{
					myValue = callValue.returnValue;
					if((myValue == FunkinLua.Function_StopHScript || myValue == FunkinLua.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops)
					{
						returnVal = myValue;
						break;
					}
					
					if(myValue != null && !excludeValues.contains(myValue))
						returnVal = myValue;
				}
			}
		}
		#end

		return returnVal;
	}

	public function setOnScripts(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		if(exclusions == null) exclusions = [];
		setOnLuas(variable, arg, exclusions);
		setOnHScript(variable, arg, exclusions);
	}

	public function setOnLuas(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		#if LUA_ALLOWED
		if(exclusions == null) exclusions = [];
		for (script in luaArray) {
			if(exclusions.contains(script.scriptName)) continue;
			script.set(variable, arg);
		}
		#end
	}

	public function setOnHScript(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		#if HSCRIPT_ALLOWED
		if(exclusions == null) exclusions = [];
		for (script in hscriptArray) {
			if(exclusions.contains(script.origin)) continue;
			script.set(variable, arg);
		}
		#end
	}

	function strumPlayAnim(isDad:Bool, id:Int, time:Float) {
		var spr:StrumNote = isDad ? opponentStrums.members[id] : playerStrums.members[id];
		if(spr != null) {
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public var ratingName:String = '?';
	public var ratingPercent:Float;
	public var ratingFC:String;
	public function RecalculateRating(badHit:Bool = false) {
		setOnScripts('score', songScore);
		setOnScripts('misses', songMisses);
		setOnScripts('hits', songHits);
		setOnScripts('combo', combo);

		var ret:Dynamic = callOnScripts('onRecalculateRating', null, true);
		if(ret != FunkinLua.Function_Stop)
		{
			ratingName = '?';
			if(totalPlayed != 0) //Prevent divide by 0
			{
				// Rating Percent
				//ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
				ratingPercent = FlxMath.bound(totalNotesHit / totalPlayed, 0, 1);
				//trace((totalNotesHit / totalPlayed) + ', Total: ' + totalPlayed + ', notes hit: ' + totalNotesHit);

				// Rating Name
				ratingName = ratingStuff[ratingStuff.length-1][0]; //Uses last string
				if(ratingPercent < 1)
					for (i in 0...ratingStuff.length-1)
						if(ratingPercent < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
			}
			fullComboFunction();
		}
		updateScore(badHit); // score will only update after rating is calculated, if it's a badHit, it shouldn't bounce -Ghost
		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
	}

	#if ACHIEVEMENTS_ALLOWED
	private function checkForAchievement(achievesToCheck:Array<String> = null):String
	{
		if(chartingMode) return null;

		var usedPractice:Bool = (ClientPrefs.getGameplaySetting('practice') || ClientPrefs.getGameplaySetting('botplay'));
		for (i in 0...achievesToCheck.length) {
			var achievementName:String = achievesToCheck[i];
			if(!Achievements.isAchievementUnlocked(achievementName) && !cpuControlled && Achievements.getAchievementIndex(achievementName) > -1) {
				var unlock:Bool = false;
				if (achievementName == WeekData.getWeekFileName() + '_nomiss') // any FC achievements, name should be "weekFileName_nomiss", e.g: "week3_nomiss";
				{
					if(isStoryMode && campaignMisses + songMisses < 1 && Difficulty.getString().toUpperCase() == 'HARD'
						&& storyPlaylist.length <= 1 && !changedDifficulty && !usedPractice)
						unlock = true;
				}
				else
				{
					switch(achievementName)
					{
						case 'ur_bad':				 unlock = (ratingPercent < 0.2 && !practiceMode);

						case 'ur_good':				 unlock = (ratingPercent >= 1 && !usedPractice);

						case 'roadkill_enthusiast':	 unlock = (Achievements.henchmenDeath >= 50);

						case 'oversinging':			 unlock = (boyfriend.holdTimer >= 10 && !usedPractice);

						case 'hype':				 unlock = (!boyfriendIdled && !usedPractice);

						case 'two_keys':			 unlock = (!usedPractice && keysPressed.length <= 2);

						case 'toastie':				 unlock = (!ClientPrefs.data.shaders && ClientPrefs.data.lowQuality && !ClientPrefs.data.antialiasing);

						case 'debugger':			 unlock = (Paths.formatToSongPath(SONG.song) == 'test' && !usedPractice);
					}
				}

				if(unlock) {
					Achievements.unlockAchievement(achievementName);
					return achievementName;
				}
			}
		}
		return null;
	}
	#end

	#if (!flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = [];
	public function createRuntimeShader(name:String):FlxRuntimeShader
	{
		if(!ClientPrefs.data.shaders) return new FlxRuntimeShader();

		#if (!flash && MODS_ALLOWED && sys)
		if(!runtimeShaders.exists(name) && !initLuaShader(name))
		{
			FlxG.log.warn('Shader $name is missing!');
			return new FlxRuntimeShader();
		}

		var arr:Array<String> = runtimeShaders.get(name);
		return new FlxRuntimeShader(arr[0], arr[1]);
		#else
		FlxG.log.warn("Platform unsupported for Runtime Shaders!");
		return null;
		#end
	}

	public function initLuaShader(name:String, ?glslVersion:Int = 120)
	{
		if(!ClientPrefs.data.shaders) return false;

		#if (MODS_ALLOWED && !flash && sys)
		if(runtimeShaders.exists(name))
		{
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		var foldersToCheck:Array<String> = [Paths.mods('shaders/')];
		var curModDir = Mods.currentModDirectory;
		if(#if (haxe > "4.2.5") curModDir?.length #else curModDir != null && curModDir.length #end > 0)
			foldersToCheck.insert(0, Paths.mods(curModDir + '/shaders/'));

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
					return true;
				}
			}
		}
		FlxG.log.warn('Missing shader $name .frag AND .vert files!');
		#else
		FlxG.log.warn('This platform doesn\'t support Runtime Shaders!', false, false, FlxColor.RED);
		#end
		return false;
	}
	#end
}