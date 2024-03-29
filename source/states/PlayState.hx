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
import backend.Rating;

import flixel.FlxBasic;
import flixel.FlxSubState;
import flixel.math.FlxPoint;
import flixel.addons.transition.FlxTransitionableState;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxArrayUtil;
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
/*#if (hxCodec >= "3.0.0")
import hxcodec.flixel.FlxVideo as VideoHandler;
#elseif (hxCodec >= "2.6.1") import hxcodec.VideoHandler;
#elseif (hxCodec == "2.6.0") import VideoHandler;
#else import vlc.MP4Handler as VideoHandler; #end*/
import backend.VideoSprite as VideoHandler;
#end
import backend.Subtitles;

import objects.PopupSprite;
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

import haxe.extern.EitherType;

// https://media.discordapp.net/attachments/1041755661630976052/1180970202079436908/image.png?ex=657f5b35&is=656ce635&hm=477b7411d344068f3cf93abbc76f0fc5457eb03123b25d788c663ef2d58ad107&=&format=webp&quality=lossless&width=517&height=631
abstract RatingData(Array<EitherType<Float, String>>) from Array<EitherType<Float, String>> to Array<EitherType<Float, String>>
{
	public var percent(get, never):Float;
	public var name(get, never):String;

	@:noCompletion inline function get_percent():Float	return this[0];
	@:noCompletion inline function get_name():String	return this[1];
}

@:access(flixel.math.FlxCallbackPoint._setXCallback)
class PlayState extends MusicBeatState
{
	// по приколу :) - Redar13
	public static var instance(default, null):PlayState;

	public static var STRUM_X = 42.0;
	public static var STRUM_X_MIDDLESCROLL = -278.0;

	public static var perfectRating = "Perfect!!";
	public static var unknownRating = "?";
	public static var ratingStuff:Array<RatingData> = [
		[0.2,  "You Suck!"],  // From 0% to 19%
		[0.4,  "Shit"],		  // From 20% to 39%
		[0.5,  "Bad"],		  // From 40% to 49%
		[0.6,  "Bruh"],		  // From 50% to 59%
		[0.69, "Meh"],		  // From 60% to 68%
		[0.7,  "Nice"],		  // 69% :trollface:
		[0.8,  "Good"],		  // From 70% to 79%
		[0.9,  "Great"],	  // From 80% to 89%
		[1.0,  "Sick!"]		  // From 90% to 99%
	];

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6.0;

	public static var SONG:Song;
	public static var storyWeek:Int = 0;
	public static var isStoryMode:Bool = false;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	public static var noteKillOffset = 350.;
	public static var curStage:String = "";
	public static var isPixelStage(get, never):Bool;
	public static var stageUI:String = "normal";

	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;
	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public static var startOnTime:Float = 0.0;

	inline public static function sortHitNotes(a:Note, b:Note):Int
	{
		return (a.lowPriority && !b.lowPriority ? 1 : (!a.lowPriority && b.lowPriority ? -1 : FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime)));
	}

	inline public static function cancelMusicFadeTween()
	{
		if (FlxG.sound.music.fadeTween != null)
		{
			FlxG.sound.music.fadeTween.cancel();
			FlxG.sound.music.fadeTween = null;
		}
	}

	public static function getKeyFromEvent(arr:Array<String>, key:FlxKey):Int
	{
		if (key != NONE)
			for (i in 0...arr.length)
				for (noteKey in Controls.instance.keyboardBinds.get(arr[i]))
					if (key == noteKey)
						return i;

		return -1;
	}

	// Less laggy controls
	@:allow(states.editors.EditorPlayState)
	static final keysArray		= ["note_left", "note_down", "note_up", "note_right"];
	static final singAnimations	= ["singLEFT", "singDOWN", "singUP", "singRIGHT"];

	static var prevCamFollow:CameraTarget;
	static final spawnTime = 2000.;

	// event variables
	public var isCameraOnForcedPos(default, set):Bool = false;

	public var boyfriendMap:Map<String, Character> = [];
	public var dadMap:Map<String, Character> = [];
	public var gfMap:Map<String, Character> = [];
	public var variables:Map<String, Dynamic> = [];
	
	#if HSCRIPT_ALLOWED public var hscriptArray:Array<HScript> = []; #end

	#if LUA_ALLOWED
	public var modchartTweens:Map<String, FlxTween> = [];
	public var modchartSprites:Map<String, ExtendedSprite> = [];
	public var modchartTimers:Map<String, FlxTimer> = [];
	public var modchartSounds:Map<String, FlxSound> = [];
	public var modchartTexts:Map<String, FlxText> = [];
	public var modchartSaves:Map<String, FlxSave> = [];
	#end

	public var BF_POS  = FlxPoint.get(770.0, 100.0);
	public var DAD_POS = FlxPoint.get(100.0, 100.0);
	public var GF_POS  = FlxPoint.get(400.0, 130.0);

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1.0;
	public var songSpeedType:String = "multiplicative";

	public var playbackRate(default, set):Float = 1.0;

	public var boyfriendGroup:FlxTypedSpriteGroup<Character>;
	public var dadGroup:FlxTypedSpriteGroup<Character>;
	public var gfGroup:FlxTypedSpriteGroup<Character>;

	public var curStageObj:BaseStage; // tracker for last loaded hard coded stage

	public var introSoundsSuffix:String = "";
	public var uiPrefix:String = "";
	public var uiSuffix:String = "";

	public var inst:FlxSound;
	public var vocals:FlxSound;

	public var dad:Character;
	public var gf:Character;
	public var boyfriend:Character;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];

	var _camTarget:String = "dad";
	var _camFollow:CameraTarget; // tracker for actual camFollow, used when isCameraOnForcedPos = true
	public var camFollow(get, never):CameraTarget; // alias for char_field.camFollow

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

	public var gfSpeed:Int = 1;
	public var combo:Int = 0;
	public var health(default, set):Float = 1.0;
		
	public var healthBar:Bar;
	public var timeBar:Bar;
	public var healthBarFlip(get, set):Bool;

	public var ratingsData:Array<Rating> = Rating.loadDefault();

	private var generatedMusic:Bool = false;
	public var endingSong:Bool = false;
	public var startingSong:Bool = false;
	private var updateTime:Bool = true;

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

	public var camHUD:GameCamera;
	public var camGame:GameCamera;
	public var camOther:GameCamera;
	public var cameraSpeed(default, set):Float;

	public var songScore:Int = 0;
	public var songHits:Int = 0;
	public var songMisses:Int = 0;
	public var scoreTxt:FlxText;
	var timeTxt:FlxText;
	var scoreTxtTween:FlxTween;

	public var defaultCamZoom(default, set):Float = 1.05;
	public var defaultHUDZoom(default, set):Float = 1.0;

	public var playingVideo(get, never):Bool;
	public var inCutscene(default, set):Bool = false;
	public var skipCountdown:Bool = false;

	var songLength(default, null):Float  = 0.0;
	var songPercent(default, null):Float = 0.0;

	// i have no fucking idea why i made this - richTrash21
	public var bfCamOffset:FlxCallbackPoint;
	public var dadCamOffset:FlxCallbackPoint;
	public var gfCamOffset:FlxCallbackPoint;

	#if hxdiscord_rpc
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	#if ACHIEVEMENTS_ALLOWED
	// Achievement shit
	var keysPressed:Array<Int> = [];
	var boyfriendIdleTime:Float = 0.0;
	var boyfriendIdled:Bool = false;
	#end

	// Lua shit
	public var luaArray:Array<FunkinLua> = [];
	#if LUA_ALLOWED
	private var luaDebugGroup:FlxTypedSpriteGroup<DebugLuaText>;
	#end

	public var precacheList:Map<String, String> = [];
	public var songName(default, null):String;

	// Callbacks for stages
	public var startCallback:()->Void;
	public var endCallback:()->Void;

	override public function create()
	{
		Paths.clearStoredMemory();

		startCallback = startCountdown;
		endCallback = endSong;

		// for lua
		instance = this;

		PauseSubState.songName = null; //Reset to default
		playbackRate = ClientPrefs.getGameplaySetting("songspeed");

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// Gameplay settings
		healthGain = ClientPrefs.getGameplaySetting("healthgain");
		healthLoss = ClientPrefs.getGameplaySetting("healthloss");
		instakillOnMiss = ClientPrefs.getGameplaySetting("instakill");
		practiceMode = ClientPrefs.getGameplaySetting("practice");
		cpuControlled = ClientPrefs.getGameplaySetting("botplay") /*|| ClientPrefs.getGameplaySetting("showcase")*/;

		camGame = new GameCamera(/*0, 0, true*/);
		camHUD = new GameCamera(0, 0);
		camOther = new GameCamera(0, 0);
		camGame.checkForTweens = camHUD.checkForTweens = true;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		persistentUpdate = persistentDraw = true;

		if (SONG == null)
			SONG = Song.loadFromJson("test");

		Conductor.mapBPMChanges(SONG);
		Conductor.bpm = SONG.bpm;

		#if hxdiscord_rpc
		storyDifficultyText = Difficulty.getString();
		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		detailsText = isStoryMode ? "Story Mode: " + WeekData.getCurrentWeek().weekName : "Freeplay";
		// String for when the game is paused
		detailsPausedText = 'Paused - $detailsText';
		#end

		songName = Paths.formatToSongPath(SONG.song);
		if (SONG.stage == null || SONG.stage.length < 1)
			SONG.stage = StageData.vanillaSongStage(songName);
		curStage = SONG.stage;

		final stageData = StageData.getStageFile(curStage) ?? StageData.dummy(); //Stage couldn't be found, create a dummy stage for preventing a crash

		defaultCamZoom = stageData.defaultZoom;

		stageUI = stageData.isPixelStage ? "pixel" : "normal";
		if (stageData.stageUI?.trim().length > 0)
			stageUI = stageData.stageUI;

		if (stageUI != "normal")
		{
			introSoundsSuffix = '-$stageUI';
			uiSuffix = '-$stageUI';
			uiPrefix = stageUI + "UI/";
		}

		BF_POS.set(stageData.boyfriend[0],  stageData.boyfriend[1]);
		GF_POS.set(stageData.girlfriend[0], stageData.girlfriend[1]);
		DAD_POS.set(stageData.opponent[0],  stageData.opponent[1]);

		boyfriendGroup = new FlxTypedSpriteGroup(BF_POS.x, BF_POS.y);
		dadGroup = new FlxTypedSpriteGroup(DAD_POS.x, DAD_POS.y);
		gfGroup = new FlxTypedSpriteGroup(GF_POS.x, GF_POS.y);

		// for character precaching
		GameOverSubstate.resetVariables(SONG);

		cameraSpeed = stageData.camera_speed ?? 1;

		bfCamOffset = new FlxCallbackPoint((p)  -> if (boyfriend != null) boyfriend.camFollowOffset.set(p.x - 100, p.y - 100));
		dadCamOffset = new FlxCallbackPoint((p) -> if (dad != null) dad.camFollowOffset.set(p.x + 150, p.y - 100));
		gfCamOffset = new FlxCallbackPoint((p)  -> if (gf != null) gf.camFollowOffset.set(p.x, p.y));

		//Fucks sake should have done it since the start :rolling_eyes:
		if (stageData.camera_boyfriend != null)
			bfCamOffset.set(stageData.camera_boyfriend[0], stageData.camera_boyfriend[1]);

		if (stageData.camera_opponent != null)
			dadCamOffset.set(stageData.camera_opponent[0], stageData.camera_opponent[1]);

		if (stageData.camera_girlfriend != null)
			gfCamOffset.set(stageData.camera_girlfriend[0], stageData.camera_girlfriend[1]);

		// NEVERMIND
		// gfGroup.scrollFactor.set(0.95, 0.95); // fixed gf paralax lmao

		curStageObj = switch (curStage) // lol
		{
			case "stage": new states.stages.StageWeek1(); // Week 1
			default:	  null;
		}

		add(gfGroup);
		add(dadGroup);
		add(boyfriendGroup);

		#if LUA_ALLOWED
		luaDebugGroup = new FlxTypedSpriteGroup<DebugLuaText>(0, Main.fpsVar.visible ? 20 : 0); // for better visibility duhh
		luaDebugGroup.camera = camOther;
		add(luaDebugGroup);
		#end

		// idfk how regex work lmao
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		inline function scriptHelper(file:String, folder:String)
		{
			#if LUA_ALLOWED
			if (Paths.LUA_REGEX.match(file))
				new FunkinLua(folder + file);
			#end
			#if HSCRIPT_ALLOWED
			if (Paths.HX_REGEX.match(file))
				initHScript(folder + file);
			#end
		}
		#end

		// "GLOBAL" SCRIPTS
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		for (folder in Mods.directoriesWithFile(Paths.getPreloadPath(), "scripts/"))
			for (file in FileSystem.readDirectory(folder))
				scriptHelper(file, folder);
		#end

		// STAGE SCRIPTS
		#if LUA_ALLOWED		startLuasNamed('stages/$curStage.lua'); #end
		#if HSCRIPT_ALLOWED	startHScriptsNamed('stages/$curStage.hx'); #end

		if (!stageData.hide_girlfriend)
		{
			if (SONG.gfVersion == null || SONG.gfVersion.length < 1)
				SONG.gfVersion = "gf"; // Fix for the Chart Editor

			gf = new Character(SONG.gfVersion);
			startCharacterPos(gf);
			gfGroup.add(gf);
			startCharacterScripts(gf.curCharacter);
			charList.push(gf);
		}

		dad = new Character(SONG.player2);
		startCharacterPos(dad, true);
		dadGroup.add(dad);
		startCharacterScripts(dad.curCharacter);
		charList.push(dad);

		boyfriend = new Character(SONG.player1, true);
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
		startCharacterScripts(boyfriend.curCharacter);
		charList.push(boyfriend);

		bfCamOffset._setXCallback(bfCamOffset);
		dadCamOffset._setXCallback(dadCamOffset);
		gfCamOffset._setXCallback(gfCamOffset);

		final camPos = FlxPoint.get(gfCamOffset.x, gfCamOffset.y);
		if (gf != null)
			camPos.addPoint(gf.getGraphicMidpoint(FlxPoint.weak()).addPoint(gf.cameraOffset));

		if (dad.curCharacter.startsWith("gf"))
		{
			dad.setPosition(GF_POS.x, GF_POS.y);
			if (gf != null)
				gf.visible = false;
		}
		stagesFunc((stage) -> stage.createPost());

		Conductor.songPosition = -5000 / Conductor.songPosition;
		final showTime = (ClientPrefs.data.timeBarType != "Disabled");
		timeTxt = new FlxText(/*STRUM_X + (FlxG.width * 0.5) - 248*/ 0, (ClientPrefs.data.downScroll ? FlxG.height - 44 : 19), 120, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = updateTime = showTime;

		timeBar = new Bar(0, timeTxt.y + (timeTxt.height * 0.25), "timeBar", () -> songPercent);
		timeBar.antialiasing = !isPixelStage;
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		timeBar.smooth = false;

		add(timeBar.screenCenter(X));
		add(timeTxt.screenCenter(X));

		if (ClientPrefs.data.timeBarType == "Song Name")
		{
			timeTxt.text = SONG.song;
			timeTxt.size = 24;
			timeTxt.y += 3;
		}
		else
			timeBar.updateCallback = (value, percent) ->
			{
				final curTime = songLength * (percent * 0.01);
				final songCalc = ClientPrefs.data.timeBarType == "Time Elapsed" ? curTime : songLength - curTime;
				timeTxt.text = FlxStringUtil.formatTime(FlxMath.bound(Math.floor(songCalc * 0.001), 0), false);
			}

		scoreGroup = new FlxTypedSpriteGroup<PopupSprite>();
		scoreGroup.ID = 0;
		strumLineNotes = new FlxTypedGroup<StrumNote>();
		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		grpNoteSplashes.ID = 0;
		add(scoreGroup);
		add(strumLineNotes);
		add(grpNoteSplashes);

		final splash = grpNoteSplashes.add(new NoteSplash()).precache();
		splash.alpha = 0; // cant make it invisible or it won't allow precaching (does he know? - rich)

		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();

		generateSong(SONG.song);

		add(_camFollow = prevCamFollow ?? new CameraTarget(camPos.x, camPos.y));
		prevCamFollow = null;
		camPos.put();

		camGame.follow(_camFollow, LOCKON, camGame.followLerp);
		camGame.zoom = defaultCamZoom;
		camGame.snapToTarget();
		camHUD.visible = !ClientPrefs.getGameplaySetting("showcase");

		// will give pixel stages more pixelated look (???????????????????)
		// dont ask why its down here idfk
		// nvmd have almost no effect
		//FlxG.camera.pixelPerfectRender = isPixelStage;
		//camHUD.pixelPerfectRender = isPixelStage;

		//FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);
		moveCameraSection();

		healthBar = new Bar(0, FlxG.height * (ClientPrefs.data.downScroll ? 0.11 : 0.89), "healthBar", () -> health, 0, 2);
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

		healthBar.updateCallback = (value:Float, percent:Float) ->
		{
			iconP1.animation.curAnim.curFrame = percent < 20 ? 1 : 0;
			iconP2.animation.curAnim.curFrame = percent > 80 ? 1 : 0;
		}

		scoreTxt = new FlxText(0, healthBar.y + 40, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.data.hideHud;
		add(scoreTxt);

		botplayTxt = new FlxText(0, timeBar.y + 55, FlxG.width - 1120, "PUSSY", 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		add(botplayTxt.screenCenter(X));
		if (ClientPrefs.data.downScroll)
			botplayTxt.y = timeBar.y - 78;

		subtitles = new Subtitles();
		subtitles.camera = camOther;
		add(subtitles);
		
		scoreGroup.camera	=	strumLineNotes.camera	=	grpNoteSplashes.camera	=
		notes.camera		=	healthBar.camera		=	iconP1.camera			=
		iconP2.camera		=	scoreTxt.camera 		=	botplayTxt.camera		=
		timeBar.camera		=	timeTxt.camera			=	camHUD;	// i love haxe <3

		startingSong = true;
		
		#if LUA_ALLOWED
		while (noteTypes.length > 0)
			startLuasNamed("custom_notetypes/" + noteTypes.pop() + ".lua");
		while (eventsPushed.length > 0)
			startLuasNamed("custom_events/" + eventsPushed.pop() + ".lua");
		#end

		#if HSCRIPT_ALLOWED
		while (noteTypes.length > 0)
			startLuasNamed("custom_notetypes/" + noteTypes.pop() + ".hx");
		while (eventsPushed.length > 0)
			startLuasNamed("custom_events/" + eventsPushed.pop() + ".hx");
		#end
		noteTypes = null;
		eventsPushed = null;

		if (eventNotes.length > 1)
		{
			for (event in eventNotes)
				event.strumTime -= eventEarlyTrigger(event);
			eventNotes.sort(Note.sortByTime);
		}

		// SONG SPECIFIC SCRIPTS
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		for (folder in Mods.directoriesWithFile(Paths.getPreloadPath(), 'data/$songName/'))
			for (file in FileSystem.readDirectory(folder))
				scriptHelper(file, folder);
		#end
		RecalculateRating();

		// PRECACHING MISS SOUNDS BECAUSE I THINK THEY CAN LAG PEOPLE AND FUCK THEM UP IDK HOW HAXE WORKS
		if (ClientPrefs.data.hitsoundVolume > 0)
			precacheList.set("hitsound", "sound");

		precacheList.set("missnote1", "sound");
		precacheList.set("missnote2", "sound");
		precacheList.set("missnote3", "sound");

		if (PauseSubState.songName != null)
			precacheList.set(PauseSubState.songName, "music");
		else if (ClientPrefs.data.pauseMusic != "None")
			precacheList.set(Paths.formatToSongPath(ClientPrefs.data.pauseMusic), "music");

		precacheList.set("alphabet", "image");
		resetRPC();

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		callOnScripts("onCreatePost");

		cacheCountdown();
		cachePopUpScore();

		for (key => type in precacheList)
			switch(type)
			{
				case "image": Paths.image(key);
				case "sound": Paths.sound(key);
				case "music": Paths.music(key);
			}

		super.create();
		Paths.clearUnusedMemory();

		if (eventNotes.length < 1)
			checkEventNote();

		// now we can finally start the song :D
		startCallback();
	}

	public function addTextToDebug(text:String, ?color:FlxColor/*, ?pos:haxe.PosInfos*/)
	{
		#if LUA_ALLOWED
		if (isDead) // ACTUALLY CAN CAUSES MEMORY LEAK!!!
			return trace(text);

		if (luaDebugGroup == null)
			return trace("can't add debug text - 'luaDebugGroup' is null!!!");

		final newText = luaDebugGroup.recycle(DebugLuaText);
		newText.text = text;
		newText.color = color ?? FlxColor.WHITE;
		newText.setPosition(10, 8 - newText.height);

		luaDebugGroup.forEachAlive((spr) -> spr.y += newText.height + 2);
		luaDebugGroup.add(newText);
		#end
		trace(text);
	}

	inline public function reloadHealthBarColors()
	{
		healthBar.setColors(healthBarFlip ? boyfriend.healthColor : dad.healthColor, healthBarFlip ? dad.healthColor : boyfriend.healthColor);
	}

	public function addCharacterToList(newCharacter:String, type:Int)
	{
		var map   = boyfriendMap;
		var group = boyfriendGroup;
		if (type == 1)
		{
			map   = dadMap;
			group = dadGroup;
		}
		else if (type == 2 && gf != null)
		{
			map   = gfMap;
			group = gfGroup;
		}

		if (map.exists(newCharacter))
			return;

		final char = new Character(0, 0, newCharacter, type == 0);
		map.set(newCharacter, char);
		// group.add(char);
		startCharacterPos(char, type == 1);
		char.precache();
		char.active = false;
		startCharacterScripts(char.curCharacter);

		/*switch (type)
		{
			case 0:
				if (!boyfriendMap.exists(newCharacter))
				{
					final newBoyfriend = new Character(0, 0, newCharacter, true);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterScripts(newBoyfriend.curCharacter);
				}

			case 1:
				if (!dadMap.exists(newCharacter))
				{
					final newDad = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterScripts(newDad.curCharacter);
				}

			case 2:
				if (gf != null && !gfMap.exists(newCharacter))
				{
					final newGf = new Character(0, 0, newCharacter);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterScripts(newGf.curCharacter);
				}
		}*/
	}
 
	@:allow(substates.GameOverSubstate)
	function startCharacterScripts(name:String)
	{
		// Lua
		#if LUA_ALLOWED
		var doPush = false;
		var luaFile = 'characters/$name.lua';
		#if MODS_ALLOWED
		final replacePath = Paths.modFolders(luaFile);
		if (FileSystem.exists(replacePath))
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
		if (Assets.exists(luaFile))
			doPush = true;
		#end

		if (doPush)
		{
			for (script in luaArray)
			{
				if (script.scriptName == luaFile)
				{
					doPush = false;
					break;
				}
			}
			if (doPush)
				new FunkinLua(luaFile);
		}
		#end

		// HScript
		#if HSCRIPT_ALLOWED
		var doPush = false;
		var scriptFile = 'characters/$name.hx';
		final replacePath = Paths.modFolders(scriptFile);
		if (FileSystem.exists(replacePath))
		{
			scriptFile = replacePath;
			doPush = true;
		}
		else
		{
			scriptFile = Paths.getPreloadPath(scriptFile);
			doPush = FileSystem.exists(scriptFile);
		}
		
		if (doPush)
			for (hx in hscriptArray)
				if (hx.origin != scriptFile)
					initHScript(scriptFile);
		#end
	}

	inline public function getLuaObject(tag:String, text = true):Dynamic
	{
		#if LUA_ALLOWED
		if (modchartSprites.exists(tag))
			return modchartSprites.get(tag);
		if (text && modchartTexts.exists(tag))
			return modchartTexts.get(tag);
		if (variables.exists(tag))
			return variables.get(tag);
		#end
		return null;
	}

	inline function startCharacterPos(char:Character, ?gfCheck = false)
	{
		if (gfCheck && char.curCharacter.startsWith("gf")) // IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
		{
			// char.setPosition(GF_POS.x, GF_POS.y);
			char.setPosition(GF_POS.x, GF_POS.y);
			char.addPosition(char.position.x, char.position.y);
			char.danceEveryNumBeats = 2;
		}
		// char.addPosition(char.position.x, char.position.y);
	}

	#if VIDEOS_ALLOWED
	public var videoPlayer:VideoHandler;
	#end
	public var subtitles:Subtitles;
	public function startVideo(name:String, antialias = true):Bool // TODO: actual subtitles (done!!)
	{
		#if VIDEOS_ALLOWED
		inCutscene = true;

		final filepath:String = Paths.video(name);
		if (#if sys !FileSystem.exists(filepath) #else !OpenFlAssets.exists(filepath) #end)
		{
			FlxG.log.warn('Couldnt find video file: $name');
			startAndEnd();
			return false;
		}

		function loadSubtitles()
		{
			final subs = Paths.getTextFromFile(Paths.srt(name), false, true);
			if (subs != null)
			{
				subtitles.loadSubtitles(subs);
				insert(members.indexOf(videoPlayer), remove(subtitles, true));
			}
		}

		videoPlayer = new VideoHandler();
		videoPlayer.camera = camOther;
		videoPlayer.antialiasing = ClientPrefs.data.antialiasing ? antialias : false;
		#if hxCodec
		#if (hxCodec >= "3.0.0")
		// Recent versions
		videoPlayer.play(filepath);
		videoPlayer.onEndReached.add(endVideo, true);
		#else
		// Older versions
		videoPlayer.playVideo(filepath);
		videoPlayer.finishCallback = endVideo;
		videoPlayer.readyCallback = loadSubtitles;
		#end
		#else
		videoPlayer.load(filepath);
		videoPlayer.bitmap.onEndReached.add(endVideo, true);
		videoPlayer.bitmap.onOpening.add(loadSubtitles, true);
		final loaded = videoPlayer.play();
		if (!loaded)
		{
			endVideo();
			return false;
		}
		#end
		add(videoPlayer);
		return true;
		#else
		FlxG.log.warn("Platform not supported!");
		startAndEnd();
		return true;
		#end
	}

	#if VIDEOS_ALLOWED
	function endVideo()
	{
		startAndEnd();
		remove(videoPlayer);
		videoPlayer = FlxDestroyUtil.destroy(videoPlayer);
		if (subtitles.playing)
			subtitles.stopSubtitles();
	}
	#end

	inline function startAndEnd() return endingSong ? endSong() : startCountdown();

	var dialogueCount:Int = 0;
	public var psychDialogue:DialogueBoxPsych;
	//You don't have to add a song, just saying. You can just do "startDialogue(DialogueBoxPsych.parseDialogue(Paths.json(songName + '/dialogue')))" and it should load dialogue.json
	public function startDialogue(dialogueFile:DialogueFile, ?song:String)
	{
		// TO DO: Make this more flexible, maybe?
		if (psychDialogue != null)
			return;

		if (dialogueFile.dialogue.length > 0)
		{
			inCutscene = true;
			precacheList.set("dialogue", "sound");
			precacheList.set("dialogueClose", "sound");
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.finishThing = () ->
			{
				psychDialogue = null;
				startAndEnd();
			}
			psychDialogue.nextDialogueThing = () -> callOnScripts("onNextDialogue", [++dialogueCount]);
			psychDialogue.skipDialogueThing = () -> callOnScripts("onSkipDialogue", [dialogueCount]);
			psychDialogue.camera = camHUD;
			add(psychDialogue);
		}
		else
		{
			FlxG.log.warn("Your dialogue file is badly formatted!");
			startAndEnd();
		}
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer;

	// For being able to mess with the sprites on Lua
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;

	function cacheCountdown()
	{
		// no more useless maps!!!
		Paths.image(uiPrefix + 'ready$uiSuffix');
		Paths.image(uiPrefix + 'set$uiSuffix');
		Paths.image(uiPrefix + 'go$uiSuffix');
		
		Paths.sound('intro3$introSoundsSuffix');
		Paths.sound('intro2$introSoundsSuffix');
		Paths.sound('intro1$introSoundsSuffix');
		Paths.sound('introGo$introSoundsSuffix');
	}

	public function startCountdown()
	{
		if (startedCountdown)
		{
			callOnScripts("onStartCountdown");
			return false;
		}

		seenCutscene = true;
		inCutscene = false;
		final ret:Dynamic = callOnScripts("onStartCountdown", null, true);
		if (ret != FunkinLua.Function_Stop)
		{
			if (skipCountdown || startOnTime > 0)
				skipArrowStartTween = true;

			generateStaticArrows(0);
			generateStaticArrows(1);
			for (i in 0...playerStrums.length)
			{
				setOnScripts('defaultPlayerStrumX$i', playerStrums.members[i].x);
				setOnScripts('defaultPlayerStrumY$i', playerStrums.members[i].y);
			}
			for (i in 0...opponentStrums.length)
			{
				setOnScripts('defaultOpponentStrumX$i', opponentStrums.members[i].x);
				setOnScripts('defaultOpponentStrumY$i', opponentStrums.members[i].y);
			}
			
			if (SONG.swapNotes && !ClientPrefs.data.middleScroll)
			{
				var dadStrum:StrumNote;
				for (i => bfStrum in playerStrums.members)
				{
					final curX = bfStrum.x;
					dadStrum = opponentStrums.members[i];
					bfStrum.x = dadStrum.x;
					dadStrum.x = curX;
				}
			}

			startedCountdown = true;
			Conductor.songPosition = -Conductor.crochet * 5;
			setOnScripts("startedCountdown", true);
			callOnScripts("onCountdownStarted");

			if (startOnTime > 0)
			{
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

			var swagCounter = 0;
			var tick = Countdown.THREE;
			var countSound:FlxSound = null;
			final antialias = (ClientPrefs.data.antialiasing && !isPixelStage);

			startTimer = new FlxTimer().start(Conductor.crochet * 0.001, (tmr) ->
			{
				charsDance(tmr.loopsLeft);

				switch (swagCounter)
				{
					case 0:
						countSound = FlxG.sound.play(Paths.sound('intro3$introSoundsSuffix'), 0.6);
						tick = THREE;

					case 1:
						countdownReady = createCountdownSprite(uiPrefix + 'ready$uiSuffix', antialias); // automatic sprite handeling😱😱
						countSound = FlxG.sound.play(Paths.sound('intro2$introSoundsSuffix'), 0.6);
						tick = TWO;

					case 2:
						countdownSet = createCountdownSprite(uiPrefix + 'set$uiSuffix', antialias);
						countSound = FlxG.sound.play(Paths.sound('intro1$introSoundsSuffix'), 0.6);
						tick = ONE;

					case 3:
						countdownGo = createCountdownSprite(uiPrefix + 'go$uiSuffix', antialias);
						countSound = FlxG.sound.play(Paths.sound('introGo$introSoundsSuffix'), 0.6);
						tick = GO;

					case 4:
						tick = START;
						startTimer = null;
				}
				#if FLX_PITCH
				if (countSound != null)
					countSound.pitch = playbackRate;
				#end

				notes.forEachAlive((note) ->
					if (ClientPrefs.data.opponentStrums || note.mustPress)
					{
						note.copyAlpha = false;
						note.alpha = note.multAlpha * ((ClientPrefs.data.middleScroll && !note.mustPress) ? 0.35 : 1);
					}
				);

				stagesFunc((stage) -> stage.countdownTick(tick, swagCounter));
				callOnLuas("onCountdownTick", [swagCounter]);
				callOnHScript("onCountdownTick", [tick, swagCounter]);
				swagCounter++;
			}, 5);
		}
		return true;
	}

	inline function createCountdownSprite(image:String, antialias:Bool):FlxSprite
	{
		final spr = new ExtendedSprite(image, antialias);
		spr.camera = camHUD;
		if (isPixelStage)
		{
			spr.setScale(daPixelZoom);
			spr.updateHitbox();
		}
		FlxTween.num(1, 0, Conductor.crochet * 0.001, {ease: FlxEase.cubeInOut, onComplete: (_) -> remove(spr).destroy()}, (a) -> spr.alpha = a);
		insert(members.indexOf(notes), spr.screenCenter());
		return spr; 
	}

	inline public function addBehindGF(obj:FlxBasic):FlxBasic	return insert(members.indexOf(gfGroup), obj);
	inline public function addBehindBF(obj:FlxBasic):FlxBasic	return insert(members.indexOf(boyfriendGroup), obj);
	inline public function addBehindDad(obj:FlxBasic):FlxBasic	return insert(members.indexOf(dadGroup), obj);

	public function clearNotesBefore(time:Float)
	{
		var daNote:Note = null;
		var i = unspawnNotes.length-1;
		while (i >= 0)
		{
			daNote = unspawnNotes[i--];
			if (daNote.strumTime - 350 < time)
			{
				daNote.active = daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.destroy();
			}
		}

		i = notes.length-1;
		while (i >= 0)
		{
			daNote = notes.members[i--];
			if (daNote.strumTime - 350 < time)
			{
				daNote.active = daNote.visible = false;
				daNote.ignoreNote = true;
				invalidateNote(daNote);
			}
		}
	}

	public var charList:Array<Character> = [];
	dynamic public function charsDance(reference:Int) // quick 'n' easy way to bop all characters
	{
		for (char in charList)
		{
			if (char == null || char.animation.curAnim == null)
				continue;

			final anim = char.animation.curAnim;
			final doDance = reference % (char == gf ? Math.round(gfSpeed * char.danceEveryNumBeats) : char.danceEveryNumBeats) == 0;
			if (doDance && !anim.name.startsWith("sing") && !char.stunned)
			{
				// fixes danceEveryNumBeats = 1 on idle dances
				char.dance(char.danceEveryNumBeats == 1 && anim.curFrame > (anim.frameDuration == 0 ? 0 : Math.floor(4 / (24 * anim.frameDuration))));
			}
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
		var str = ratingName;
		if (totalPlayed > 0)
		{
			final percent = CoolUtil.floorDecimal(ratingPercent * 100, 2);
			str += ' ($percent%) - $ratingFC';
		}

		final tempScore = 'Score: $songScore' + (!instakillOnMiss ? ' | Misses: $songMisses' : "") + ' | Rating: $str';
		// "tempScore" variable is used to prevent another memory leak, just in case
		// "\n" here prevents the text from being cut off by beat zooms
		scoreTxt.text = '$tempScore\n';

		if (ClientPrefs.data.scoreZoom && !miss && !cpuControlled && !startingSong)
		{
			if (scoreTxtTween != null)
				scoreTxtTween.cancel();
			scoreTxt.scale.set(1.075, 1.075);
			scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {onComplete: (_) -> scoreTxtTween = null});
		}
		callOnScripts("onUpdateScore", [miss]);
	}

	public dynamic function fullComboFunction()
	{
		ratingFC = if (songMisses == 0)
		{
			if (ratingsData[2].hits + ratingsData[3].hits > 0) // bads and shits
				"FC";
			else if (ratingsData[1].hits > 0) // goods
				"GFC";
			else if (ratingsData[0].hits > 0) // sicks
				"SFC";
			else
				"";
		}
		else
		{
			if (songMisses < 10)
				"SDCB";
			else
				"Clear";
		}
	}

	public function setSongTime(time:Float)
	{
		if (time < 0)
			time = 0;

		FlxG.sound.music.pause();
		FlxG.sound.music.time = time;
		//#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		FlxG.sound.music.play();

		if (vocals != null && Conductor.songPosition <= vocals.length)
		{
			vocals.pause();
			vocals.time = time;
			//#if FLX_PITCH vocals.pitch = playbackRate; #end
			if (!startingSong)
				vocals.play();
		}
		if (videoPlayer != null)
			videoPlayer.bitmap.time += Math.round(time - Conductor.songPosition);

		Conductor.songPosition = time;
	}		

	// var showcaseTxt:FlxText;
	@:access(flixel.sound.FlxSound._sound)
	function startSong():Void
	{
		startingSong = false;

		FlxG.sound.playMusic(inst._sound, 1, false);
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		FlxG.sound.music.onComplete = finishSong.bind();
		if (vocals != null)
			vocals.play();

		if (startOnTime > 0)
			setSongTime(startOnTime - 500);
		startOnTime = 0;

		if (paused)
		{
			FlxG.sound.music.pause();
			if (vocals != null)
				vocals.pause();
		}

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		FlxTween.num(0, 1, 0.5, {ease: FlxEase.circOut}, (a) -> timeBar.alpha = timeTxt.alpha = a);

		/*if (ClientPrefs.getGameplaySetting("showcase"))
		{
			showcaseTxt = new FlxText(30, FlxG.height - 55, 0, "> SHOWCASE", 32);
			showcaseTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			showcaseTxt.borderSize = 1.25;
			showcaseTxt.alpha = 0;
			add(showcaseTxt);
			showcaseTxt.camera = camOther;
			// FlxTween.tween(showcaseTxt, {alpha: 1}, 1.6, {ease: FlxEase.backOut, type: FlxTweenType.PINGPONG});
		}*/

		#if hxdiscord_rpc
		// Updating Discord Rich Presence (with Time Left)
		var text = SONG.song;
		if (storyDifficultyText != Difficulty.defaultDifficulty)
			text += ' ($storyDifficultyText)';
		DiscordClient.changePresence(detailsText, text, iconP2.char, true, songLength, songName);
		#end
		setOnScripts("songLength", songLength);
		callOnScripts("onSongStart");
	}

	private var noteTypes:Array<String> = [];
	private var eventsPushed:Array<String> = [];
	private function generateSong(dataPath:String):Void
	{
		songSpeed = SONG.speed;
		songSpeedType = ClientPrefs.getGameplaySetting("scrolltype");
		switch (songSpeedType)
		{
			case "multiplicative":
				songSpeed *= ClientPrefs.getGameplaySetting("scrollspeed");
			case "constant":
				songSpeed  = ClientPrefs.getGameplaySetting("scrollspeed");
		}

		Conductor.bpm = SONG.bpm;
		curSong = SONG.song;

		inst = FlxG.sound.load(Paths.inst(SONG.song));
		if (SONG.needsVoices)
		{
			vocals = FlxG.sound.load(Paths.voices(SONG.song));
			#if FLX_PITCH vocals.pitch = playbackRate; #end
		}

		notes = new FlxTypedGroup<Note>();
		add(notes);

		// NEW SHIT
		final file = Paths.json('$songName/events');
		#if MODS_ALLOWED
		if (FileSystem.exists(Paths.modsJson('$songName/events')) || FileSystem.exists(file))
		#else
		if (OpenFlAssets.exists(file))
		#end
		{
			for (event in Song.loadFromJson("events", songName).events) // Event Notes
				for (i in 0...event[1].length)
					makeEvent(event, i);
		}

		for (section in SONG.notes)
			for (songNotes in section.sectionNotes)
			{
				final daStrumTime = songNotes[0];
				final daNoteData = Std.int(songNotes[1] % 4);
				final gottaHitNote = songNotes[1] > 3 ? !section.mustHitSection : section.mustHitSection;
				var oldNote = unspawnNotes[unspawnNotes.length - 1];

				final swagNote = new Note(daStrumTime, daNoteData, oldNote);
				swagNote.mustPress = gottaHitNote;
				swagNote.sustainLength = songNotes[2];
				swagNote.gfNote = (section.gfSection && (songNotes[1]<4));
				// Backward compatibility + compatibility with Week 7 charts
				swagNote.noteType = Std.isOfType(songNotes[3], String) ? songNotes[3] : ChartingState.noteTypeList[songNotes[3]];
				unspawnNotes.push(swagNote);

				final susLength = swagNote.sustainLength / Conductor.stepCrochet;
				final floorSus = Math.floor(susLength);
				if (floorSus > 0)
				{
					for (susNote in 0...floorSus+1)
					{
						oldNote = unspawnNotes[unspawnNotes.length-1];

						final sustainNote = new Note(daStrumTime + (Conductor.stepCrochet * susNote), daNoteData, oldNote, true);
						sustainNote.mustPress = gottaHitNote;
						sustainNote.gfNote = (section.gfSection && (songNotes[1]<4));
						sustainNote.noteType = swagNote.noteType;
						sustainNote.parent = swagNote;
						unspawnNotes.push(sustainNote);
						swagNote.tail.push(sustainNote);
						
						sustainNote.correctionOffset = swagNote.height * 0.5;
						if (!isPixelStage)
						{
							if (oldNote.isSustainNote)
							{
								oldNote.scale.y *= Note.SUSTAIN_SIZE / oldNote.frameHeight;
								// oldNote.scale.y /= playbackRate;
								oldNote.updateHitbox();
							}

							if (ClientPrefs.data.downScroll)
								sustainNote.correctionOffset = 0;
						}
						else if (oldNote.isSustainNote)
						{
							// oldNote.scale.y /= playbackRate;
							oldNote.updateHitbox();
						}

						if (sustainNote.mustPress) // general offset
							sustainNote.x += FlxG.width * 0.5;
						else if (ClientPrefs.data.middleScroll)
							sustainNote.x += daNoteData > 1 ? FlxG.width * 0.5 + 335 : 310;
					}
				}

				if (swagNote.mustPress) // general offset
					swagNote.x += FlxG.width * 0.5;
				else if (ClientPrefs.data.middleScroll)
					swagNote.x += daNoteData > 1 ? FlxG.width * 0.5 + 335 : 310;

				if (!noteTypes.contains(swagNote.noteType))
					noteTypes.push(swagNote.noteType);
			}

		//Event Notes
		for (event in SONG.events)
			for (i in 0...event[1].length)
				makeEvent(event, i);

		unspawnNotes.sort(Note.sortByTime);
		generatedMusic = true;
	}

	// called only once per different event (Used for precaching)
	function eventPushed(event:EventNote)
	{
		eventPushedUnique(event);
		if (eventsPushed.contains(event.event))
			return;

		stagesFunc((stage) -> stage.eventPushed(event));
		eventsPushed.push(event.event);
	}

	// called by every event with the same name
	function eventPushedUnique(event:EventNote)
	{
		switch (event.event)
		{
			case "Change Character":
				addCharacterToList(event.value2, switch (event.value1.toLowerCase().trim())
				{
					case "gf" | "girlfriend": 2;
					case "dad" | "opponent":  1;
					default:				  Std.parseInt(event.value1) ?? 0;
				});
			
			case "Play Sound":
				precacheList.set(event.value1, "sound");
				// Paths.sound(event.value1);
		}
		stagesFunc((stage) -> stage.eventPushedUnique(event));
	}

	inline function eventEarlyTrigger(event:EventNote):Float
	{
		final ret = callOnScripts("eventEarlyTrigger", [event.event, event.value1, event.value2, event.strumTime], true);
		if (ret != null && ret != FunkinLua.Function_Continue)
			return ret;

		return switch (event.event)
		{
			// Better timing so that the kill sound matches the beat intended
			case "Kill Henchmen":  280; // Plays 280ms before the actual position
			default:			   0;
		}
	}

	function makeEvent(event:Array<Dynamic>, i:Int)
	{
		final eventData = event[1][i];
		final subEvent:EventNote = {
			strumTime:	event[0] + ClientPrefs.data.noteOffset,
			event:		eventData[0],
			value1:		eventData[1],
			value2:		eventData[2]
		};
		eventNotes.push(subEvent);
		eventPushed(subEvent);
		callOnScripts("onEventPushed", [subEvent.event, subEvent.value1 ?? "", subEvent.value2 ?? "", subEvent.strumTime]);
	}

	public var skipArrowStartTween:Bool = false; //for lua
	private function generateStaticArrows(player:Int):Void
	{
		final strumLineX = ClientPrefs.data.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X;
		final strumLineY = ClientPrefs.data.downScroll ? (FlxG.height - 150) : 50.0;

		var targetAlpha = 1.0;
		if (player < 1)
		{
			if (!ClientPrefs.data.opponentStrums)
				targetAlpha = 0;
			else if (ClientPrefs.data.middleScroll)
				targetAlpha = 0.35;
		}

		for (i in 0...4)
		{
			final babyArrow = new StrumNote(strumLineX, strumLineY, i, player);
			babyArrow.downScroll = ClientPrefs.data.downScroll;
			if (!isStoryMode && !skipArrowStartTween)
			{
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + 0.2 * i});
			}
			else
				babyArrow.alpha = targetAlpha;

			if (player == 1)
				playerStrums.add(babyArrow);
			else
			{
				if (ClientPrefs.data.middleScroll)
					babyArrow.x += i > 1 ? FlxG.width * 0.5 + 335 : 310;
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();
		}
	}

	override function openSubState(SubState:FlxSubState)
	{
		stagesFunc((stage) -> stage.openSubState(SubState));
		if (paused)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				if (vocals != null)
					vocals.pause();
			}

			if (startTimer != null && !startTimer.finished)
				startTimer.active = false;
			if (finishTimer != null && !finishTimer.finished)
				finishTimer.active = false;
			if (songSpeedTween != null && !songSpeedTween.finished)
				songSpeedTween.active = false;

			/*for (char in charList)
				if (char?.colorTween != null)
					char.colorTween.active = false;*/

			#if LUA_ALLOWED
			for (tween in modchartTweens)
				tween.active = false;
			for (timer in modchartTimers)
				timer.active = false;
			#end

			// TODO: FINISH THIS SHIT
			/*@:privateAccess FlxTween.globalManager.forEach(function(tween:FlxTween)
				if (!tween.isTweenOf(SubState)) tween.active = false
			);
			// TODO: better way of pausing timers on substate opening
			FlxTimer.globalManager.forEach(function(timer:FlxTimer) timer.active = false);
			for (sound in FlxG.sound.list) {

			}*/
			FlxG.timeScale = 1.0;
		}

		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		stagesFunc((stage) -> stage.closeSubState());
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong)
				resyncVocals();

			/*
			if (startTimer != null && !startTimer.finished)
				startTimer.active = true;
			if (finishTimer != null && !finishTimer.finished)
				finishTimer.active = true;
			if (songSpeedTween != null)
				songSpeedTween.active = true;
			
			for (char in charList)
				if (char?.colorTween != null)
					char.colorTween.active = false;

			#if LUA_ALLOWED
			for (tween in modchartTweens)
				tween.active = true;
			for (timer in modchartTimers)
				timer.active = true;
			#end
			*/

			FlxTween.globalManager.forEach((tween) -> tween.active = true);
			FlxTimer.globalManager.forEach((timer) -> timer.active = true);
			FlxG.sound.resume();

			FlxG.timeScale = playbackRate;
			paused = false;
			callOnScripts("onResume");
			resetRPC(startTimer?.finished);
		}

		super.closeSubState();
	}

	override public function onFocus():Void
	{
		final ret:Dynamic = callOnScripts("onFocus", null, true);
		if (ret == FunkinLua.Function_Stop)
			return super.onFocus();

		if (health > 0 && !paused)
			resetRPC(Conductor.songPosition > 0.0);

		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		final ret:Dynamic = callOnScripts("onFocusLost", null, true);
		if (ret == FunkinLua.Function_Stop)
			return super.onFocusLost();

		#if hxdiscord_rpc
		if (health >= 0 && !paused)
		{
			var text = SONG.song;
			if (storyDifficultyText != Difficulty.defaultDifficulty)
				text += ' ($storyDifficultyText)';
			DiscordClient.changePresence(detailsPausedText, text, iconP2.char, songName);
		}
		#end
		if (!FlxG.autoPause && startedCountdown && canPause && !paused)
		{
			final _ret:Dynamic = callOnScripts("onPause", null, true);
			if (_ret != FunkinLua.Function_Stop)
				openPauseMenu(); // idk
		}
		super.onFocusLost();
	}

	// Updating Discord Rich Presence.
	inline function resetRPC(?cond = false)
	{
		#if hxdiscord_rpc
		var text = SONG.song;
		if (storyDifficultyText != Difficulty.defaultDifficulty)
			text += ' ($storyDifficultyText)';
		DiscordClient.changePresence(detailsText, text, iconP2.char, cond,
									 cond ? songLength - Conductor.songPosition - ClientPrefs.data.noteOffset : null, songName);
		#end
	}

	function resyncVocals():Void
	{
		if (finishTimer == null)
		{
			FlxG.sound.music.play();
			//#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
			Conductor.songPosition = FlxG.sound.music.time;
			if (vocals != null && Conductor.songPosition <= vocals.length)
			{
				vocals.pause();
				vocals.time = Conductor.songPosition;
				//#if FLX_PITCH vocals.pitch = playbackRate; #end
				vocals.play();
			}
		}
	}

	public var paused(default, set):Bool = false;
	public var canReset:Bool = true;
	var startedCountdown:Bool = false;
	@:allow(backend.BaseStage)
	var canPause:Bool = true;

	override public function update(elapsed:Float)
	{
		callOnScripts("onUpdate", [elapsed]);

		#if ACHIEVEMENTS_ALLOWED
		if (!inCutscene && !paused)
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
			// camGame.followLerp = elapsed * 2.4 * cameraSpeed * playbackRate #if (flixel < "5.4.0") / #else * #end (FlxG.updateFramerate / 60);
			if (!startingSong && !endingSong && boyfriend.animation.curAnim?.name.startsWith("idle"))
			{
				// Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
				if ((boyfriendIdleTime += elapsed) >= 0.15)
					boyfriendIdled = true;
			}
			else
				boyfriendIdleTime = 0;
		}
		#end

		super.update(elapsed);

		setOnScripts("curDecStep", curDecStep);
		setOnScripts("curDecBeat", curDecBeat);

		if (botplayTxt?.visible)
		{
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) * 0.005555555555555556); // / 180
			// if (showcaseTxt != null) showcaseTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		if (!(FlxG.keys.pressed.ALT && FlxG.keys.firstJustPressed() == ENTER))
			if (controls.PAUSE && startedCountdown && canPause)
			{
				final ret:Dynamic = callOnScripts("onPause", null, true);
				if (ret != FunkinLua.Function_Stop)
					openPauseMenu();
			}

		// idk how it will behave on an older versions sooooo...
		// UPD: using hxvlc from now on (idfk whats the difference)
		// UPDD: nvmd back to hxcodec lmao
		// UPDDD: back to hxvlc yeah...
		#if (VIDEOS_ALLOWED && !hxCodec)
		if ((controls.PAUSE || controls.ACCEPT) && playingVideo && (startingSong || endingSong))
			endVideo();
		#end

		// :trollface:
		#if !RELESE_BUILD_FR
		if (!(endingSong || inCutscene))
		{
			if (controls.justPressed("debug_1"))
				openChartEditor();
			if (controls.justPressed("debug_2"))
				openCharacterEditor();
		}
		#end

		updateIcons();
		
		if (startedCountdown && !paused)
			Conductor.songPosition += elapsed * 1000;

		if (startingSong)
		{
			if (startedCountdown)
			{
				if (Conductor.songPosition >= 0)
					startSong();
			}
			else
				Conductor.songPosition = -Conductor.crochet * 5;
		}
		else if (!paused && updateTime)
			songPercent = Math.max(0, Conductor.songPosition - ClientPrefs.data.noteOffset) / songLength;

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.data.noReset && controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong)
			health = 0;

		if (unspawnNotes[0] != null)
		{
			var time = spawnTime;
			if (songSpeed < 1)
				time /= songSpeed;
			if (unspawnNotes[0].multSpeed < 1)
				time /= unspawnNotes[0].multSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				final dunceNote = unspawnNotes.shift();
				notes.insert(0, dunceNote).spawned = true;

				callOnLuas("onSpawnNote", [notes.members.indexOf(dunceNote), dunceNote.noteData, dunceNote.noteType, dunceNote.isSustainNote, dunceNote.strumTime]);
				callOnHScript("onSpawnNote", [dunceNote]);
			}
		}

		if (generatedMusic)
		{
			if (!inCutscene)
			{
				if (cpuControlled)
					playerDance();
				else
					keysCheck();

				if (notes.length > 0)
				{
					if (startedCountdown)
					{
						// final fakeCrochet = 60 / SONG.bpm * 1000;
						notes.forEachAlive((daNote) ->
						{
							final strum = (daNote.mustPress ? playerStrums : opponentStrums).members[daNote.noteData];
							daNote.followStrumNote(strum, /*Conductor.crochet,*/ songSpeed / playbackRate);

							if (daNote.mustPress)
							{
								if (cpuControlled && !daNote.blockHit && daNote.canBeHit && (daNote.isSustainNote || daNote.strumTime <= Conductor.songPosition))
									goodNoteHit(daNote);
							}
							else if (daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote)
								opponentNoteHit(daNote);

							if (daNote.isSustainNote && strum.sustainReduce)
								daNote.clipToStrumNote(strum);

							// Kill extremely late notes and cause misses
							if (Conductor.songPosition - daNote.strumTime > noteKillOffset)
							{
								if (daNote.mustPress && !cpuControlled && !daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit))
									noteMiss(daNote);

								daNote.active = false;
								daNote.visible = false;
								invalidateNote(daNote);
							}
						});
					}
					else
					{
						notes.forEachAlive((daNote) ->
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
		if (!endingSong && !startingSong)
		{
			if (FlxG.keys.justPressed.ONE)
			{
				KillNotes();
				FlxG.sound.music.onComplete();
			}
			if (FlxG.keys.justPressed.TWO) // Go 10 seconds into the future :O
			{
				setSongTime(Conductor.songPosition + (FlxG.keys.pressed.SHIFT ? 20000 : 10000) * playbackRate);
				clearNotesBefore(Conductor.songPosition);
				if (Conductor.songPosition > FlxG.sound.music.length)
					finishSong();
			}
			if ((FlxG.keys.pressed.SHIFT && FlxG.keys.justPressed.B) || FlxG.keys.justPressed.THREE) // quick botplay for testing shit
			{
				cpuControlled = !cpuControlled;
				changedDifficulty = false;
			}
		}
		if (FlxG.keys.pressed.F5)
			FlxG.resetState();
		#end

		// okay, what the fuck??????
		// why does camFollow represent camera position????

		// UPD: much better. need to make this a pull request to official psych lmao
		// UPD: nvmd won't use anyway
		setOnScripts("cameraX", camFollow.x /*camGame.scroll.x - (camGame.width * 0.5)*/);
		setOnScripts("cameraY", camFollow.y /*camGame.scroll.y - (camGame.height * 0.5)*/);
		callOnScripts("onUpdatePost", [elapsed]);
	}

	dynamic public function updateIcons()
	{
		var iconL = iconP2;
		var iconR = iconP1;
		if (healthBarFlip)
		{
			iconL = iconP1;
			iconR = iconP2;
		}
		iconL.x = healthBar.centerPoint.x - iconL.width * .5 - 52;
		iconR.x = healthBar.centerPoint.x + (iconR.width - iconR.frameWidth * iconR.baseScale) * .5 - 26;
	}

	function openPauseMenu()
	{
		if (playingVideo)
			videoPlayer.pause();

		// camGame.updateLerp = false;
		persistentUpdate = false;
		persistentDraw = paused = true;
		FlxTween.globalManager.forEach((tween) -> tween.active = false); // so pause tweens wont stop
		FlxTimer.globalManager.forEach((timer) -> timer.active = false);
		FlxG.sound.pause();

		if (!cpuControlled)
			for (note in playerStrums)
				if (note.animation.curAnim?.name != "static")
				{
					note.playAnim("static");
					note.resetAnim = 0;
				}

		openSubState(new PauseSubState(camOther));

		#if hxdiscord_rpc
		var text = SONG.song;
		if (storyDifficultyText != Difficulty.defaultDifficulty)
			text += ' ($storyDifficultyText)';
		DiscordClient.changePresence(detailsPausedText, text, iconP2.char, songName);
		#end
	}

	#if !RELESE_BUILD_FR
	function openChartEditor()
	{
		persistentUpdate = false;
		paused = true;
		cancelMusicFadeTween();
		chartingMode = true;

		#if hxdiscord_rpc
		DiscordClient.changePresence("Chart Editor", null, null, true);
		DiscordClient.resetClientID();
		#end
		
		MusicBeatState.switchState(ChartingState.new);
	}
	
	function openCharacterEditor()
	{
		persistentUpdate = false;
		paused = true;
		cancelMusicFadeTween();
		#if hxdiscord_rpc
		DiscordClient.resetClientID();
		#end
		MusicBeatState.switchState(CharacterEditorState.new.bind(SONG.player2, true));
		HealthIcon.jsonCache.clear();
		Character.jsonCache.clear();
	}
	#end

	public var isDead:Bool = false; //Don't mess with this on Lua!!!
	function doDeathCheck(skipHealthCheck = false):Bool
	{
		if ((!skipHealthCheck && health > healthBar.bounds.min || practiceMode) || isDead)
			return false;

		final ret:Dynamic = callOnScripts("onGameOver", null, true);
		if (ret == FunkinLua.Function_Stop)
			return false;

		boyfriend.stunned = true;
		deathCounter++;

		@:bypassAccessor
		paused = true;

		if (vocals != null)
			vocals.stop();
		FlxG.sound.music.stop();

		persistentUpdate = persistentDraw = false;
		#if LUA_ALLOWED
		for (tween in modchartTweens)
			tween.active = true;
		for (timer in modchartTimers)
			timer.active = true;
		#end
		final screenPos = boyfriend.getScreenPosition();
		openSubState(new GameOverSubstate(screenPos.x - boyfriend.position.x, screenPos.y - boyfriend.position.y));
		screenPos.put();

		#if hxdiscord_rpc
		// Game Over doesn't get his own variable because it's only used here
		var text = SONG.song;
		if (storyDifficultyText != Difficulty.defaultDifficulty)
			text += ' ($storyDifficultyText)';
		DiscordClient.changePresence('Game Over - $detailsText', text, iconP2.char, songName);
		#end
		return isDead = true;
	}

	public function checkEventNote()
	{
		while (eventNotes.length != 0)
		{
			if (Conductor.songPosition < eventNotes[0].strumTime)
				return;
			final event = eventNotes.shift();
			triggerEvent(event.event, event.value1 ?? "", event.value2 ?? "", event.strumTime);
		}
	}

	public function triggerEvent(eventName:String, value1:String, value2:String, ?strumTime:Float)
	{
		var flValue1 = CoolUtil.nullifyNaN(Std.parseFloat(value1));
		var flValue2 = CoolUtil.nullifyNaN(Std.parseFloat(value2));

		if (strumTime == null)
			strumTime = Conductor.songPosition;

		switch(eventName)
		{
			case "Hey!":
				final value = switch (value1.toLowerCase().trim())
				{
					case "bf" | "boyfriend" | "0":   0;
					case "gf" | "girlfriend" | "1":  1;
					default:						 2;
				}

				if (flValue2 == null || flValue2 <= 0.0)
					flValue2 = 0.6;

				if (value != 0)
				{
					// Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
					final char = dad.curCharacter.startsWith("gf") ? dad : gf;
					if (char != null)
					{
						char.playAnim("cheer", true);
						char.specialAnim = true;
						char.heyTimer = flValue2;
					}
				}
				if (value != 1)
				{
					boyfriend.playAnim("hey", true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = flValue2;
				}

			case "Set GF Speed":
				if (flValue1 == null || flValue1 < 1.0)
					flValue1 = 1;
				gfSpeed = Math.round(flValue1);

			case "Add Camera Zoom":
				if (ClientPrefs.data.camZooms /*&& camGame.zoom < 1.35*/)
				{
					if (flValue1 == null)
						flValue1 = 0.015;
					if (flValue2 == null)
						flValue2 = 0.03;

					if (!camGame.tweeningZoom)
						camGame.zoom += flValue1;
					if (!camHUD.tweeningZoom)
						camHUD.zoom  += flValue2;
				}

			case "Play Animation":
				final char = switch (value2.toLowerCase().trim())
				{
					case "gf" | "girlfriend" | "2":  gf;
					case "bf" | "boyfriend" | "1":   boyfriend;
					default:						 dad;
				}

				if (char != null)
				{
					char.playAnim(value1, true);
					char.specialAnim = true;
				}

			case "Camera Follow Pos":
				isCameraOnForcedPos = false;
				if (flValue1 != null || flValue2 != null)
				{
					isCameraOnForcedPos = true;
					if (flValue1 == null)
						flValue1 = 0.0;
					if (flValue2 == null)
						flValue2 = 0.0;

					_camFollow.x = flValue1;
					_camFollow.y = flValue2;
				}

			case "Alt Idle Animation":
				final char = switch (value1.toLowerCase().trim())
				{
					case "gf" | "girlfriend" | "2":  gf;
					case "boyfriend" | "bf" | "1":   boyfriend;
					default:						 dad;
				}

				if (char != null)
					char.idleSuffix = value2;

			case "Screen Shake":
				inline function shakeCamera(camera:FlxCamera, params:String)
				{
					final split = params.split(",");
					final duration  = CoolUtil.nullifyNaN(Std.parseFloat(split[0])) ?? 0.0;
					final intensity = CoolUtil.nullifyNaN(Std.parseFloat(split[1])) ?? 0.0;
					if (duration > 0.0 && intensity != 0.0)
						camera.shake(intensity, duration);
				}

				shakeCamera(camGame, value1);
				shakeCamera(camGame, value2);

			case "Change Character":
				final charType = switch (value1.toLowerCase().trim())
				{
					case "gf" | "girlfriend" | "2":  2;
					case "dad" | "opponent" | "1":   1;
					default:						 0;
				}

				switch (charType)
				{
					case 0:
						if (boyfriend.curCharacter != value2)
						{
							if (!boyfriendMap.exists(value2))
								addCharacterToList(value2, charType);

							final lastAlpha = boyfriend.alpha;
							charList.remove(boyfriendGroup.remove(boyfriend));
							// boyfriend.alpha = 0.00001;
							boyfriend.active = false;

							charList.push(boyfriend = boyfriendGroup.add(boyfriendMap.get(value2)));
							boyfriend.alpha = lastAlpha;
							boyfriend.active = true;

							iconP1.changeIcon(boyfriend.healthIcon);
							bfCamOffset._setXCallback(bfCamOffset);
						}
						setOnScripts("boyfriendName", boyfriend.curCharacter);

					case 1:
						if (dad.curCharacter != value2)
						{
							if (!dadMap.exists(value2))
								addCharacterToList(value2, charType);

							final lastAlpha = dad.alpha;
							final wasGf = dad.curCharacter.startsWith("gf-") || dad.curCharacter == "gf";
							charList.remove(dadGroup.remove(dad));
							// dad.alpha = 0.00001;
							dad.active = false;

							charList.push(dad = dadGroup.add(dadMap.get(value2)));
							dad.alpha = lastAlpha;
							dad.active = true;

							iconP2.changeIcon(dad.healthIcon);
							dadCamOffset._setXCallback(dadCamOffset);

							if (gf != null)
								gf.visible = !(dad.curCharacter.startsWith("gf-") || dad.curCharacter == "gf") ? (wasGf ? true : gf.visible) : false;
						}
						setOnScripts("dadName", dad.curCharacter);

					case 2:
						if (gf != null)
						{
							if (gf.curCharacter != value2)
							{
								if (!gfMap.exists(value2))
									addCharacterToList(value2, charType);

								final lastAlpha = gf.alpha;
								charList.remove(gfGroup.remove(gf));
								// gf.alpha = 0.00001;
								gf.active = false;

								charList.push(gf = gfGroup.add(gfMap.get(value2)));
								gf.alpha = lastAlpha;
								gf.active = true;

								gfCamOffset._setXCallback(gfCamOffset);
							}
							setOnScripts("gfName", gf.curCharacter);
						}
				}
				reloadHealthBarColors();
				moveCameraSection();

			case "Change Scroll Speed":
				if (songSpeedType != "constant")
				{
					if (flValue1 == null)
						flValue1 = 1.0;
					if (flValue2 == null) 
						flValue2 = 0.0;

					final newValue = SONG.speed * ClientPrefs.getGameplaySetting("scrollspeed") * flValue1;
					if (flValue2 > 0.0)
						songSpeedTween = FlxTween.num(songSpeed, newValue, flValue2, {onComplete: (_) -> songSpeedTween = null}, set_songSpeed);
					else
						songSpeed = newValue;
				}

			case "Set Property":
				try
				{
					final v2 = LuaUtils.boolCkeck(value2);
					if (value1.contains("."))
					{
						final split = value1.split(".");
						LuaUtils.setVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1], v2);
					}
					else
						LuaUtils.setVarInArray(this, value1, v2);
				}
				catch(e)
				{
					HScript.hscriptTrace('ERROR ("Set Property" Event) - $e', FlxColor.RED);
				}
			
			case "Play Sound":
				if (flValue2 == null)
					flValue2 = 1.0;
				FlxG.sound.play(Paths.sound(value1), flValue2);
		}
		
		stagesFunc((stage) -> stage.eventCalled(eventName, value1, value2, flValue1, flValue2, strumTime));
		callOnScripts("onEvent", [eventName, value1, value2, strumTime]);
	}

	@:allow(backend.BaseStage)
	function moveCameraSection(?sec:Int):Void
	{
		if (SONG.notes[(sec = FlxMath.maxInt(sec ?? curSection, 0))] == null)
			return;

		final char = (gf != null && SONG.notes[sec].gfSection ? "gf" : (SONG.notes[sec].mustHitSection ? "boyfriend" : "dad"));
		moveCamera(char);
	}

	public function moveCamera(char:String):Bool
	{
		_camTarget = char.toLowerCase().trim();
		// if (!isCameraOnForcedPos)
		//	setCharCamOffset(_camTarget);
		camGame.target = camFollow;
		callOnScripts("onMoveCamera", [_camTarget]);
		return _camTarget == "dad" || _camTarget == "opponent"; // for lua
	}

	/*dynamic public function setCharCamOffset(char:String)
	{
		switch (char)
		{
			case "dad" | "opponent":
				dad.camFollowOffset.copyFrom(dadCamOffset).add(150, -100);
				dad.updateCamFollow();

			case "gf" | "girlfriend":
				gf.camFollowOffset.copyFrom(gfCamOffset);
				gf.updateCamFollow();

			default:
				boyfriend.camFollowOffset.copyFrom(bfCamOffset).subtract(100, 100);
				boyfriend.updateCamFollow();
		}
	}*/

	dynamic public function getCharCamFollow(char:String):CameraTarget
	{
		return switch (char)
			{
				case "dad" | "opponent":	dad.camFollow;
				case "gf" | "girlfriend":	gf.camFollow;
				default:					boyfriend.camFollow;
			}
	}

	public function finishSong(?ignoreNoteOffset = false):Void
	{
		updateTime = false;
		FlxG.sound.music.volume = 0;
		FlxG.sound.music.pause();
		if (vocals != null)
		{
			vocals.pause();
			vocals.volume = 0;
		}
		if (ClientPrefs.data.noteOffset < 1 || ignoreNoteOffset)
			endCallback();
		else
			finishTimer = new FlxTimer().start(ClientPrefs.data.noteOffset * 0.001, (_) -> { finishTimer = null; endCallback(); });
	}

	public var transitioning = false;
	public function endSong()
	{
		if (!startingSong) // Should kill you if you tried to cheat
		{
			notes.forEach((daNote) ->
				if (daNote.strumTime < songLength - Conductor.safeZoneOffset)
					health -= 0.05 * healthLoss
			);
			for (daNote in unspawnNotes)
				if (daNote.strumTime < songLength - Conductor.safeZoneOffset)
					health -= 0.05 * healthLoss;
			if (doDeathCheck())
				return false;
		}

		endingSong = true;
		canPause = false;
		deathCounter = 0;

		//FlxG.camera.pixelPerfectRender = false;
		//camHUD.pixelPerfectRender = false;
		timeBar.visible = timeTxt.visible = seenCutscene = camZooming = inCutscene = updateTime = false;

		#if ACHIEVEMENTS_ALLOWED
		checkForAchievement([WeekData.getWeekFileName() + "_nomiss", "ur_bad", "ur_good", "hype", "two_keys", "toastie", "debugger"]);
		#end

		final ret:Dynamic = callOnScripts("onEndSong", null, true);
		if (ret == FunkinLua.Function_Stop || transitioning)
			return true;

		#if !switch
		Highscore.saveScore(SONG.song, songScore, storyDifficulty, Math.isNaN(ratingPercent) ? 0.0 : ratingPercent);
		#end
		playbackRate = 1.0;

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

			if (storyPlaylist.length == 0)
			{
				Mods.loadTopMod();
				FlxG.sound.playMusic(Paths.music("freakyMenu"));
				#if hxdiscord_rpc
				DiscordClient.resetClientID();
				#end

				cancelMusicFadeTween();
				MusicBeatState.switchState(StoryMenuState.new);

				if (!ClientPrefs.getGameplaySetting("practice") && !ClientPrefs.getGameplaySetting("botplay"))
				{
					StoryMenuState.weekCompleted.set(WeekData.weeksList[storyWeek], true);
					Highscore.saveWeekScore(WeekData.getWeekFileName(), campaignScore, storyDifficulty);

					FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
					FlxG.save.flush();
				}
				changedDifficulty = false;
			}
			else
			{
				final difficulty:String = Difficulty.getFilePath();

				trace("LOADING NEXT SONG");
				trace(Paths.formatToSongPath(storyPlaylist[0]) + difficulty);

				FlxTransitionableState.skipNextTransIn = FlxTransitionableState.skipNextTransOut = true;
				prevCamFollow = camFollow;
				remove(prevCamFollow);

				SONG = Song.loadFromJson(storyPlaylist[0] + difficulty, storyPlaylist[0]);
				FlxG.sound.music.stop();

				cancelMusicFadeTween();
				LoadingState.loadAndSwitchState(new PlayState());
			}
		}
		else
		{
			trace("WENT BACK TO FREEPLAY??");
			Mods.loadTopMod();
			#if hxdiscord_rpc
			DiscordClient.resetClientID();
			#end

			cancelMusicFadeTween();
			MusicBeatState.switchState(FreeplayState.new);
			FlxG.sound.playMusic(Paths.music("freakyMenu"));
			changedDifficulty = false;
		}
		return transitioning = true;
	}

	public function KillNotes()
	{
		while (notes.length > 0)
		{
			final daNote = notes.members[0];
			daNote.active = daNote.visible = false;
			invalidateNote(daNote);
		}
		FlxDestroyUtil.destroyArray(unspawnNotes);
		FlxArrayUtil.clearArray(unspawnNotes);
		FlxArrayUtil.clearArray(eventNotes);
	}

	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0.0;

	public var showComboNum:Bool = true;
	public var showRating:Bool	 = true;

	private function cachePopUpScore()
	{
		if (!ClientPrefs.data.enableCombo)
			return;

		for (rat in ratingsData)
			Paths.image(uiPrefix + rat.image + uiSuffix);
		for (i in 0...10)
			Paths.image(uiPrefix + 'num$i' + uiSuffix);

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

	// cache factories for later use
	@:allow(states.editors.EditorPlayState)
	@:noCompletion static final __ratingFactory = PopupSprite.new.bind(-10, -1, -175, -140, 0, 0, 550, 550);
	@:allow(states.editors.EditorPlayState)
	@:noCompletion static final __numScoreFactory = PopupScore.new.bind(-10, -1, -175, -140, 0, 0, 550, 550);

	private function popUpScore(?note:Note):Void
	{
		// tryna do MS based judgment due to popular demand
		final MS = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset) / playbackRate;
		final daRating = Conductor.judgeNote(ratingsData, MS);
		// RATINGS BROKE FOR SOME REASON SO I NEED TEST IT
		/*trace(
			daRating,
			"songPosition: " + FlxMath.roundDecimal(Conductor.songPosition, 4),
			"MS: " + FlxMath.roundDecimal(MS, 4),
			"strumTime: " + FlxMath.roundDecimal(note.strumTime, 4)
		);*/

		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if (!note.ratingDisabled)
			daRating.hits++;
		note.rating = daRating.name;

		if (daRating.noteSplash && !note.noteSplashData.disabled)
			spawnNoteSplashOnNote(note);

		if (!practiceMode && !cpuControlled)
		{
			songScore += daRating.score;
			if (!note.ratingDisabled)
			{
				songHits++;
				totalPlayed++;
				RecalculateRating(false);
			}
		}

		// доволен??🙄🙄
		if (!ClientPrefs.data.enableCombo || ClientPrefs.data.hideHud || (!showRating && !showComboNum))
			return;

		final placement = FlxG.width * 0.35;
		var scaleMult   = 0.7;
		var numScale    = 0.5;
		if (isPixelStage)
			scaleMult = numScale = daPixelZoom * 0.85;

		final noStacking = !ClientPrefs.data.comboStacking;
		if (noStacking)
			scoreGroup.forEachAlive((spr) -> spr.kill());

		if (showRating)
		{
			final rating = scoreGroup.recycle(PopupSprite, __ratingFactory, true);
			rating.loadGraphic(Paths.image(uiPrefix + daRating.image + uiSuffix));
			rating.x = placement - 40 + ClientPrefs.data.comboOffset[0];
			rating.screenCenter(Y).y -= 60 + ClientPrefs.data.comboOffset[1];
			rating.setScale(scaleMult);
			rating.updateHitbox();
			rating.setAngleVelocity(-rating.velocity.x, rating.velocity.x);
			if (isPixelStage)
				rating.antialiasing = false;
			scoreGroup.add(rating);

			rating.fadeTime = Conductor.crochet * 0.001;
			rating.fadeSpeed = 5;
			rating.order = scoreGroup.ID++;
		}

		if (showComboNum)
		{
			final digits = combo < 1000 ? 3 : CoolUtil.getDigits(combo);
			final seperatedScore = [for (i in 0...digits) Math.floor(combo / Math.pow(10, (digits - 1) - i)) % 10];

			for (i => v in seperatedScore)
			{
				final numScore = scoreGroup.recycle(PopupScore, __numScoreFactory, true);
				numScore.loadGraphic(Paths.image(uiPrefix + 'num$v' + uiSuffix));
				numScore.x = placement + (45 * i) - 90 + ClientPrefs.data.comboOffset[2];
				numScore.screenCenter(Y).y += 80 - ClientPrefs.data.comboOffset[3];

				numScore.setScale(numScale);
				numScore.updateHitbox();
				numScore.offset.add(FlxG.random.float(-1, 1), FlxG.random.float(-1, 1));
				numScore.angularVelocity = -numScore.velocity.x;
				if (isPixelStage)
					numScore.antialiasing = false;
				scoreGroup.add(numScore);

				numScore.fadeTime = Conductor.crochet * 0.001;
				numScore.fadeSpeed = 5;
				numScore.order = scoreGroup.ID++;
			}
		}
		scoreGroup.sort(CoolUtil.sortByOrder);
	}

	public var strumsBlocked:Array<Bool> = [];
	private function onKeyPress(event:KeyboardEvent):Void
	{
		final eventKey = event.keyCode;
		if (!controls.controllerMode && FlxG.keys.checkStatus(eventKey, JUST_PRESSED))
			keyPressed(getKeyFromEvent(keysArray, eventKey));
	}

	// new psych input by crowplexus (so sexy)
	private function keyPressed(key:Int)
	{
		if (cpuControlled || paused || key == -1 || !generatedMusic || endingSong || boyfriend.stunned)
			return;

		// had to name it like this else it'd break older scripts lol
		final ret:Dynamic = callOnScripts("preKeyPress", [key], true);
		if (ret == FunkinLua.Function_Stop)
			return;

		// more accurate hit time for the ratings?
		final lastTime = Conductor.songPosition;
		if (Conductor.songPosition >= 0)
			Conductor.songPosition = FlxG.sound.music.time;

		// obtain notes that the player can hit
		final plrInputNotes = notes.members.filter((n) ->
		{
			return	if (n == null)
						false;
					else
						(!strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit)
						&& !n.isSustainNote && n.noteData == key;
		});
		plrInputNotes.sort(sortHitNotes);

		final shouldMiss = !ClientPrefs.data.ghostTapping;
		if (plrInputNotes.length == 0) // slightly faster than doing `> 0` lol
		{
			if (shouldMiss && !boyfriend.stunned)
			{
				callOnScripts("onGhostTap", [key]);
				noteMissPress(key);
			}
		}
		else
		{
			var funnyNote = plrInputNotes[0]; // front note
			// trace('✡⚐🕆☼ 💣⚐💣');

			if (plrInputNotes.length != 1)
			{
				final doubleNote = plrInputNotes[1];
				if (doubleNote.noteData == funnyNote.noteData)
				{
					// if the note has a 0ms distance (is on top of the current note), kill it
					if (Math.abs(doubleNote.strumTime - funnyNote.strumTime) < 1.0)
						invalidateNote(doubleNote);
					// replace the note if its ahead of time (or at least ensure "doubleNote" is ahead)
					else if (doubleNote.strumTime < funnyNote.strumTime)
						funnyNote = doubleNote;
				}
			}
			goodNoteHit(funnyNote);
		}

		// This is for the "Just the Two of Us" achievement lol
		//									- Shadow Mario
		#if ACHIEVEMENTS_ALLOWED
		if (!keysPressed.contains(key))
			keysPressed.push(key);
		#end

		// more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
		Conductor.songPosition = lastTime;

		final spr = playerStrums.members[key];
		if (!strumsBlocked[key] && spr != null && spr.animation.curAnim.name != "confirm")
		{
			spr.playAnim("pressed");
			spr.resetAnim = 0;
		}
		callOnScripts("onKeyPress", [key]);
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		final key = getKeyFromEvent(keysArray, event.keyCode);
		if (!controls.controllerMode && key != -1)
			keyReleased(key);
	}

	private function keyReleased(key:Int)
	{
		if (cpuControlled || !startedCountdown || paused)
			return;

		final spr = playerStrums.members[key];
		if (spr != null)
		{
			spr.playAnim("static");
			spr.resetAnim = 0;
		}
		callOnScripts("onKeyRelease", [key]);
	}

	// Hold notes
	private function keysCheck():Void
	{
		// HOLDING
		final holdArray = new Array<Bool>();
		final pressArray = new Array<Bool>();
		final releaseArray = new Array<Bool>();
		for (key in keysArray)
		{
			holdArray.push(controls.pressed(key));
			pressArray.push(controls.justPressed(key));
			releaseArray.push(controls.justReleased(key));
		}

		// TODO: Find a better way to handle controller inputs, this should work for now
		if (controls.controllerMode && pressArray.contains(true))
			for (i in 0...pressArray.length)
				if (pressArray[i] && !strumsBlocked[i])
					keyPressed(i);

		if (startedCountdown && !inCutscene && !boyfriend.stunned && generatedMusic)
		{
			// rewritten inputs???
			if (notes.length != 0)
				notes.forEachAlive((note) ->
					// hold note functions
					if (!strumsBlocked[note.noteData] && note.isSustainNote && holdArray[note.noteData] && note.canBeHit
						&& note.mustPress && !note.tooLate && !note.wasGoodHit && !note.blockHit)
						goodNoteHit(note)
				);

			if (!holdArray.contains(true) || endingSong)
				playerDance();
			#if ACHIEVEMENTS_ALLOWED
			else
				checkForAchievement(["oversinging"]);
			#end
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if ((controls.controllerMode || strumsBlocked.contains(true)) && releaseArray.contains(true))
			for (i in 0...releaseArray.length)
				if (releaseArray[i] || strumsBlocked[i])
					keyReleased(i);
	}

	function noteMiss(daNote:Note):Void // You didn't hit the key and let it go offscreen, also used by Hurt Notes
	{
		// Dupe note remove
		notes.forEachAlive((note) ->
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote
				&& Math.abs(daNote.strumTime - note.strumTime) < 1)
				invalidateNote(note)
		);
		
		noteMissCommon(daNote.noteData, daNote);
		final ret:Dynamic = callOnLuas("noteMiss", [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote]);
		if (ret != FunkinLua.Function_Stop && ret != FunkinLua.Function_StopHScript && ret != FunkinLua.Function_StopAll)
			callOnHScript("noteMiss", [daNote]);
	}

	function noteMissPress(direction:Int = 1):Void // You pressed a key when there was no notes to press for this key
	{
		if (ClientPrefs.data.ghostTapping)
			return; // fuck it

		noteMissCommon(direction);
		FlxG.sound.play(Paths.soundRandom("missnote", 1, 3), FlxG.random.float(0.1, 0.2));
		callOnScripts("noteMissPress", [direction]);
	}

	function noteMissCommon(direction:Int, ?note:Note)
	{
		// score and data
		health -= (note?.missHealth ?? 0.05) * healthLoss;
		combo = 0;

		if (!practiceMode)
			songScore -= 10;
		if (!endingSong)
			songMisses++;
		totalPlayed++;
		RecalculateRating(true);

		if (doDeathCheck(instakillOnMiss))
			return;

		// play character anims
		final char = (note?.gfNote || SONG.notes[curSection]?.gfSection) ? gf : boyfriend;

		if (char?.hasMissAnimations && !note?.noMissAnimation)
		{
			final suffix = note?.animSuffix ?? "";
			final animToPlay:String = singAnimations[direction] + 'miss$suffix';
			char.playAnim(animToPlay, true);
			
			if (char != gf && combo > 5 && gf?.animOffsets.exists("sad"))
			{
				gf.playAnim("sad");
				gf.specialAnim = true;
			}
		}
		if (vocals != null)
			vocals.volume = 0;
	}

	function opponentNoteHit(note:Note):Void
	{
		camZooming = true;

		if (note.noteType == "Hey!" && dad.animOffsets.exists("hey"))
		{
			dad.playAnim("hey", true);
			dad.specialAnim = true;
			dad.heyTimer = 0.6;
		}
		else if (!note.noAnimation)
		{
			final altAnim = (SONG.notes[curSection]?.altAnim && !SONG.notes[curSection]?.gfSection) ? "-alt" : note.animSuffix;
			final animToPlay = singAnimations[note.noteData] + altAnim;
			final char = note.gfNote ? gf : dad;

			if (char != null)
			{
				char.playAnim(animToPlay, true);
				char.holdTimer = 0;
			}
		}
		if (vocals != null)
			vocals.volume = 1;

		strumPlayAnim(true, note.noteData, Conductor.stepCrochet * 1.25 * 0.001 / playbackRate);
		note.hitByOpponent = true;

		final result:Dynamic = callOnLuas("opponentNoteHit", [notes.members.indexOf(note), note.noteData, note.noteType, note.isSustainNote]);
		if (result != FunkinLua.Function_Stop && result != FunkinLua.Function_StopHScript && result != FunkinLua.Function_StopAll)
			callOnHScript("opponentNoteHit", [note]);

		if (!note.isSustainNote)
			invalidateNote(note);
	}

	// new psych input by crowplexus
	public function goodNoteHit(note:Note):Void
	{
		if (note.wasGoodHit || (cpuControlled && (note.ignoreNote || note.hitCausesMiss)))
			return;

		note.wasGoodHit = true;
		if (ClientPrefs.data.hitsoundVolume > 0 && !note.hitsoundDisabled)
			FlxG.sound.play(Paths.sound(note.hitsound), ClientPrefs.data.hitsoundVolume);

		if (note.hitCausesMiss)
		{
			noteMiss(note);
			if (!note.noteSplashData.disabled && !note.isSustainNote)
				spawnNoteSplashOnNote(note);

			if (!note.noMissAnimation)
			{
				switch(note.noteType)
				{
					case "Hurt Note": //Hurt note
						if (boyfriend.animation.getByName("hurt") != null)
						{
							boyfriend.playAnim("hurt", true);
							boyfriend.specialAnim = true;
						}
				}
			}
			if (!note.isSustainNote)
				invalidateNote(note);
			return;
		}

		if (!note.isSustainNote)
		{
			combo++;
			popUpScore(note);
		}
		health += note.hitHealth * healthGain;

		if (!note.noAnimation)
		{
			final animToPlay:String = singAnimations[note.noteData];
			var char:Character = boyfriend;
			var animCheck:String = "hey";
			if (note.gfNote)
			{
				char = gf;
				animCheck = "cheer";
			}

			if (char != null)
			{
				char.playAnim(animToPlay + note.animSuffix, true);
				char.holdTimer = 0;

				if (note.noteType == "Hey!")
					if (char.animOffsets.exists(animCheck))
					{
						char.playAnim(animCheck, true);
						char.specialAnim = true;
						char.heyTimer = 0.6;
					}
			}
		}

		if (!cpuControlled)
		{
			final spr = playerStrums.members[note.noteData];
			if (spr != null)
				spr.playAnim("confirm", true);
		}
		else
			strumPlayAnim(false, note.noteData, Conductor.stepCrochet * 1.25 * .001);

		if (vocals != null)
			vocals.volume = 1;

		final result:Dynamic = callOnLuas("goodNoteHit", [notes.members.indexOf(note), note.noteData, note.noteType, note.isSustainNote]);
		if (result != FunkinLua.Function_Stop && result != FunkinLua.Function_StopHScript && result != FunkinLua.Function_StopAll)
			callOnHScript("goodNoteHit", [note]);

		if (!note.isSustainNote)
			invalidateNote(note);
	}

	public function spawnNoteSplashOnNote(note:Note)
	{
		if (note == null)
			return;

		final strum = playerStrums.members[note.noteData];
		if (strum != null)
			spawnNoteSplash(strum.x, strum.y, note.noteData, note);
	}

	// new psych input by crowplexus
	inline public function invalidateNote(note:Note):Void
	{
		note.kill();
		notes.remove(note, true);
		note.destroy();
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note)
	{
		final splash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, note);
		splash.order = grpNoteSplashes.ID++;
		grpNoteSplashes.sort(CoolUtil.sortByOrder);
	}

	override function destroy()
	{
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		FlxG.timeScale = #if FLX_PITCH FlxG.sound.music.pitch = #end 1.0;

		#if VIDEOS_ALLOWED
		if (playingVideo) // just in case
			endVideo();
		#end

		FlxArrayUtil.clearArray(Note.globalRgbShaders);
		backend.NoteTypesConfig.clearNoteTypesData();
		Note._lastValidChecked = null;
		HealthIcon.jsonCache.clear();
		Character.jsonCache.clear();

		// properly destroys custom substates now, finally!!!
		super.destroy();

		#if LUA_ALLOWED
		var luaScript:FunkinLua;
		while (luaArray.length != 0)
		{
			if ((luaScript = luaArray.pop()) != null)
			{
				luaScript.call("onDestroy", []);
				luaScript.stop();
			}
		}
		FunkinLua.customFunctions.clear();
		#end

		#if HSCRIPT_ALLOWED
		var hscript:HScript;
		while (hscriptArray.length != 0)
		{
			if ((hscript = hscriptArray.pop()) != null)
			{
				hscript.executeFunction("onDestroy");
				hscript.destroy();
			}
		}
		#end

		BF_POS = FlxDestroyUtil.put(BF_POS);
		GF_POS = FlxDestroyUtil.put(GF_POS);
		DAD_POS = FlxDestroyUtil.put(DAD_POS);

		boyfriendMap = CoolUtil.clear(boyfriendMap);
		dadMap = CoolUtil.clear(dadMap);
		gfMap = CoolUtil.clear(gfMap);
		variables = CoolUtil.clear(variables);
		#if LUA_ALLOWED
		modchartTweens = CoolUtil.clear(modchartTweens);
		modchartSprites = CoolUtil.clear(modchartSprites);
		modchartTimers = CoolUtil.clear(modchartTimers);
		modchartSounds = CoolUtil.clear(modchartSounds);
		modchartTexts = CoolUtil.clear(modchartTexts);
		modchartSaves = CoolUtil.clear(modchartSaves);
		#end
		#if (!flash && sys)
		runtimeShaders = CoolUtil.clear(runtimeShaders);
		#end

		bfCamOffset = FlxDestroyUtil.destroy(bfCamOffset);
		dadCamOffset = FlxDestroyUtil.destroy(dadCamOffset);
		gfCamOffset = FlxDestroyUtil.destroy(gfCamOffset);

		instance = null;
	}

	var lastStepHit = -1;
	override function stepHit()
	{
		if (FlxG.sound.music.time >= -ClientPrefs.data.noteOffset)
		{
			final maxDelay = 20 * playbackRate;
			final realTime = Conductor.songPosition - Conductor.offset;
			if (Math.abs(FlxG.sound.music.time - realTime) > maxDelay || (vocals != null && Math.abs(vocals.time - realTime) > maxDelay))
				resyncVocals();
		}

		super.stepHit();
		if (curStep == lastStepHit)
			return;

		lastStepHit = curStep;
		#if debug
		FlxG.watch.addQuick("stepShit", curStep);
		#end
		setOnScripts("curStep", curStep);
		callOnScripts("onStepHit");
	}

	var lastBeatHit = -1;
	override function beatHit()
	{
		if (lastBeatHit >= curBeat)
			return;

		if (generatedMusic)
			notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);

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

		#if debug
		FlxG.watch.addQuick("beatShit", curBeat);
		#end
		setOnScripts("curBeat", curBeat);
		callOnScripts("onBeatHit");
	}

	// new psych input by crowplexus
	public function playerDance(force = false):Void
	{
		final anim = boyfriend.animation.curAnim;
		if (anim != null && boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 #if FLX_PITCH / FlxG.sound.music.pitch #end) * boyfriend.singDuration
			&& anim.name.startsWith("sing") && !anim.name.endsWith("miss"))
			boyfriend.dance(force);
	}

	override function sectionHit()
	{
		if (SONG.notes[curSection] != null)
		{
			if (generatedMusic && !endingSong && !isCameraOnForcedPos)
				moveCameraSection(curSection);

			if (camZooming /*&& camGame.zoom < 1.35*/ && ClientPrefs.data.camZooms)
			{
				if (!camGame.tweeningZoom)
					camGame.zoom += 0.015 * camZoomingMult;
				if (!camHUD.tweeningZoom)
					camHUD.zoom  += 0.03 * camZoomingMult;
			}

			if (SONG.notes[curSection].changeBPM)
			{
				Conductor.bpm = SONG.notes[curSection].bpm;
				setOnScripts("curBpm", Conductor.bpm);
				setOnScripts("crochet", Conductor.crochet);
				setOnScripts("stepCrochet", Conductor.stepCrochet);
			}
			setOnScripts("mustHitSection", SONG.notes[curSection].mustHitSection);
			setOnScripts("altAnim", SONG.notes[curSection].altAnim);
			setOnScripts("gfSection", SONG.notes[curSection].gfSection);
		}
		super.sectionHit();

		#if debug
		FlxG.watch.addQuick("secShit", curSection);
		#end
		setOnScripts("curSection", curSection);
		callOnScripts("onSectionHit");
	}

	#if LUA_ALLOWED
	public function startLuasNamed(luaFile:String)
	{
		var luaToLoad:String;
		#if MODS_ALLOWED
		luaToLoad = Paths.modFolders(luaFile);
		if (!FileSystem.exists(luaToLoad))
			luaToLoad = Paths.getPreloadPath(luaFile);
		if (FileSystem.exists(luaToLoad))
		#else
		luaToLoad = Paths.getPreloadPath(luaFile);
		if (OpenFlAssets.exists(luaToLoad))
		#end
		{
			for (script in luaArray)
				if (script.scriptName == luaToLoad)
					return false;

			new FunkinLua(luaToLoad);
			return true;
		}
		return false;
	}
	#end
	
	#if HSCRIPT_ALLOWED
	public function startHScriptsNamed(scriptFile:String)
	{
		var scriptToLoad:String;
		#if MODS_ALLOWED
		var scriptToLoad = Paths.modFolders(scriptFile);
		if (!FileSystem.exists(scriptToLoad))
			scriptToLoad = Paths.getPreloadPath(scriptFile);
		if (FileSystem.exists(scriptToLoad))
		#else
		scriptToLoad = Paths.getPreloadPath(scriptFile);
		if (OpenFlAssets.exists(scriptToLoad))
		#end
		{
			for (hx in hscriptArray)
				if (hx.origin == scriptToLoad)
					return false;
	
			initHScript(scriptToLoad);
			return true;
		}
		return false;
	}

	public function initHScript(file:String)
	{
		inline function makeError(newScript:HScript)
		{
			newScript.destroy();
			hscriptArray.remove(newScript);
		}

		try
		{
			final times = Date.now().getTime();
			final newScript = new HScript(null, file);
			hscriptArray.push(newScript);

			if (newScript.exception != null)
			{
				HScript.hscriptTrace("ERROR ON LOADING - " + newScript.exception.message, FlxColor.RED);
				makeError(newScript);
				return;
			}

			if (newScript.variables.exists("onCreate"))
			{
				final retVal:Dynamic = newScript.executeFunction("onCreate");
				if (newScript.exception != null)
				{
					HScript.hscriptTrace("ERROR (onCreate) - " + newScript.exception.message, FlxColor.RED);
					makeError(newScript);
					return;
				}
			}
			final _delay = Std.int(Date.now().getTime() - times);
			trace('initialized hscript interp successfully: $file [' + (_delay == 0 ? "instantly" : _delay + "ms") + "]");
		}
		catch(e)
		{
			HScript.hscriptTrace('ERROR - $e', FlxColor.RED);
			if (hscriptArray.length > 0)
				makeError(hscriptArray[hscriptArray.length - 1]);
		}
	}
	#end

	public function callOnScripts(funcToCall:String, ?args:Array<Dynamic>, ignoreStops = false, ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>):Dynamic {
		if (args == null)			args = [];
		if (exclusions == null)		exclusions = [];
		if (excludeValues == null)	excludeValues = [psychlua.FunkinLua.Function_Continue];

		var result:Dynamic = callOnLuas(funcToCall, args, ignoreStops, exclusions, excludeValues);
		if (result == null || excludeValues.contains(result)) result = callOnHScript(funcToCall, args, ignoreStops, exclusions, excludeValues);
		return result;
	}

	public function callOnLuas(funcToCall:String, ?args:Array<Dynamic>, ignoreStops = false, ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>):Dynamic {
		var returnVal:Dynamic = FunkinLua.Function_Continue;
		#if LUA_ALLOWED
		if (args == null)			args = [];
		if (exclusions == null)		exclusions = [];
		if (excludeValues == null)	excludeValues = [FunkinLua.Function_Continue];

		var len:Int = luaArray.length;
		var i:Int = 0;
		while(i < len)
		{
			final script:FunkinLua = luaArray[i++];
			if (script == null || exclusions.contains(script.scriptName))
				continue;

			final myValue:Dynamic = script.call(funcToCall, args);
			if ((myValue == FunkinLua.Function_StopLua || myValue == FunkinLua.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops)
			{
				returnVal = myValue;
				break;
			}
			
			if (myValue != null && !excludeValues.contains(myValue))
				returnVal = myValue;

			if (script.closed)
				len--;
		}
		#end
		return returnVal;
	}
	
	public function callOnHScript(funcToCall:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false, ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>):Dynamic {
		var returnVal:Dynamic = FunkinLua.Function_Continue;

		#if HSCRIPT_ALLOWED
		if (exclusions == null)		exclusions = [];
		if (excludeValues == null)	excludeValues = [FunkinLua.Function_Continue];

		final len = hscriptArray.length;
		if (len == 0)
			return returnVal;

		var i = 0;
		while (i < len)
		{
			final script:HScript = hscriptArray[i++];
			if (script == null || !script.active || exclusions.contains(script.origin))
				continue;

			try
			{
				var callValue = script.executeFunction(funcToCall, args);
				if (script.exception != null)
				{
					//script.active = false;
					FunkinLua.luaTrace('ERROR ($funcToCall) - ' + script.exception, true, false, FlxColor.RED);
				}
				else
				{
					if((callValue == FunkinLua.Function_StopHScript || callValue == FunkinLua.Function_StopAll) && !excludeValues.contains(callValue) && !ignoreStops)
					{
						returnVal = callValue;
						break;
					}

					if (callValue != null && !excludeValues.contains(callValue))
						returnVal = callValue;

					/*if ((returnVal == FunkinLua.Function_StopHScript || returnVal == FunkinLua.Function_StopAll) && !excludeValues.contains(returnVal) && !ignoreStops)
						break;*/
				}
			}
		}
		#end

		return returnVal;
	}

	public function setOnScripts(variable:String, arg:Dynamic, ?exclusions:Array<String>)
	{
		if (exclusions == null)
			exclusions = [];
		setOnLuas(variable, arg, exclusions);
		setOnHScript(variable, arg, exclusions);
	}

	public function setOnLuas(variable:String, arg:Dynamic, ?exclusions:Array<String>)
	{
		#if LUA_ALLOWED
		if (exclusions == null)
			exclusions = [];
		for (script in luaArray)
		{
			if (exclusions.contains(script.scriptName))
				continue;
			script.set(variable, arg);
		}
		#end
	}

	public function setOnHScript(variable:String, arg:Dynamic, ?exclusions:Array<String>)
	{
		#if HSCRIPT_ALLOWED
		if (exclusions == null)
			exclusions = [];
		for (script in hscriptArray)
		{
			if (exclusions.contains(script.origin))
				continue;
			script.setVar(variable, arg);
		}
		#end
	}

	inline function strumPlayAnim(isDad:Bool, id:Int, time:Float)
	{		
		final spr = strumLineNotes.members[isDad ? id : id + 4];
		if (spr != null)
		{
			spr.playAnim("confirm", true);
			spr.resetAnim = time;
		}
	}

	public var ratingName:String = unknownRating;
	public var ratingPercent:Float;
	public var ratingFC:String;

	public function RecalculateRating(badHit:Bool = false)
	{
		setOnScripts("score", songScore);
		setOnScripts("misses", songMisses);
		setOnScripts("hits", songHits);
		setOnScripts("combo", combo);

		final ret:Dynamic = callOnScripts("onRecalculateRating", null, true);
		if (ret != FunkinLua.Function_Stop)
		{
			if (totalPlayed == 0)
				ratingName = unknownRating; // Prevent division by 0
			else
			{
				// Rating Percent
				ratingPercent = FlxMath.bound(totalNotesHit / totalPlayed, 0, 1);

				// Rating Name
				if (ratingPercent == 1)
					ratingName = perfectRating; // Uses last string
				else
					for (data in ratingStuff)
						if (ratingPercent < data.percent)
						{
							ratingName = data.name;
							break;
						}
			}
			fullComboFunction();
		}
		updateScore(badHit); // score will only update after rating is calculated, if it's a badHit, it shouldn't bounce -Ghost
		setOnScripts("rating", ratingPercent);
		setOnScripts("ratingName", ratingName);
		setOnScripts("ratingFC", ratingFC);
	}

	#if ACHIEVEMENTS_ALLOWED
	function checkForAchievement(?achievesToCheck:Array<String>)
	{
		if (chartingMode || cpuControlled || achievesToCheck == null || achievesToCheck.length == 0)
			return;

		final usedPractice = ClientPrefs.getGameplaySetting("practice") || ClientPrefs.getGameplaySetting("botplay");
		for (name in achievesToCheck)
		{
			if (!Achievements.exists(name))
				continue;

			final unlock = if (name.endsWith("_nomiss")) // any FC achievements, name should be "weekFileName_nomiss", e.g: "week3_nomiss";
			{
				(isStoryMode && campaignMisses + songMisses < 1 && Difficulty.getString().toUpperCase() == "HARD"
					&& storyPlaylist.length <= 1 && !changedDifficulty && !usedPractice);
			}
			else // common achievements
			{
				switch (name)
				{
					case "ur_bad":		 ratingPercent < 0.2 && !practiceMode;

					case "ur_good":		 ratingPercent == 1 && !usedPractice;

					case "oversinging":	 boyfriend.holdTimer >= 10 && !usedPractice;

					case "hype":		 !boyfriendIdled && !usedPractice;

					case "two_keys":	 !usedPractice && keysPressed.length < 3;

					case "toastie":		 !ClientPrefs.data.cacheOnGPU && !ClientPrefs.data.shaders && ClientPrefs.data.lowQuality && !ClientPrefs.data.antialiasing;

					case "debugger":	 songName == "test" && !usedPractice;

					default:			 false;
				}
			}

			if (unlock)
				Achievements.unlock(name);
		}
	}
	#end

	#if (!flash && sys)
	public var runtimeShaders:Map<String, RuntimeShaderData> = [];
	public function createRuntimeShader(name:String):FlxRuntimeShader
	{
		if (!ClientPrefs.data.shaders)
			return new FlxRuntimeShader();

		if (!runtimeShaders.exists(name) && !initLuaShader(name))
		{
			FlxG.log.warn('Shader $name is missing!');
			return new FlxRuntimeShader();
		}

		final data = runtimeShaders.get(name);
		return new FlxRuntimeShader(data.frag, data.vert);
	}

	public function initLuaShader(name:String, ?glslVersion:Int = 120)
	{
		if (!ClientPrefs.data.shaders)
			return false;

		if (runtimeShaders.exists(name))
		{
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		final foldersToCheck = [Paths.mods("shaders/")];
		#if MODS_ALLOWED
		if (Mods.currentModDirectory?.length > 0)
			foldersToCheck.unshift(Paths.mods(Mods.currentModDirectory + "/shaders/"));

		for (mod in Mods.getGlobalMods())
			foldersToCheck.unshift(Paths.mods('$mod/shaders/'));
		#end
		
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

		FlxG.log.warn('Missing shader $name .frag AND .vert files!');
		return false;
	}
	#end

	inline function calcFollowLerp():Float
	{
		return camGame.followLerp = 0.04 * cameraSpeed;
	}

	// DEPRECATED!!!
	@:noCompletion /*extern*/ public var BF_X(get, set):Float;
	@:noCompletion /*extern*/ public var BF_Y(get, set):Float;
	@:noCompletion /*extern*/ public var DAD_X(get, set):Float;
	@:noCompletion /*extern*/ public var DAD_Y(get, set):Float;
	@:noCompletion /*extern*/ public var GF_X(get, set):Float;
	@:noCompletion /*extern*/ public var GF_Y(get, set):Float;
	@:noCompletion /*extern*/ public var boyfriendCameraOffset(get, set):Array<Float>;
	@:noCompletion /*extern*/ public var opponentCameraOffset(get, set):Array<Float>;
	@:noCompletion /*extern*/ public var girlfriendCameraOffset(get, set):Array<Float>;

	@:noCompletion inline public function set_isCameraOnForcedPos(force:Bool):Bool
	{
		if (force) // actual follow object!! :O
			camGame.target = _camFollow;
		return isCameraOnForcedPos = force;
	}

	@:noCompletion inline function get_BF_X():Float   return BF_POS.x;
	@:noCompletion inline function get_BF_Y():Float   return BF_POS.y;
	@:noCompletion inline function get_DAD_X():Float  return DAD_POS.x;
	@:noCompletion inline function get_DAD_Y():Float  return DAD_POS.y;
	@:noCompletion inline function get_GF_X():Float   return GF_POS.x;
	@:noCompletion inline function get_GF_Y():Float   return GF_POS.y;

	@:noCompletion inline function set_BF_X(v:Float):Float   return BF_POS.x  = v;
	@:noCompletion inline function set_BF_Y(v:Float):Float   return BF_POS.y  = v;
	@:noCompletion inline function set_DAD_X(v:Float):Float  return DAD_POS.x = v;
	@:noCompletion inline function set_DAD_Y(v:Float):Float  return DAD_POS.y = v;
	@:noCompletion inline function set_GF_X(v:Float):Float   return GF_POS.x  = v;
	@:noCompletion inline function set_GF_Y(v:Float):Float   return GF_POS.y  = v;

	@:noCompletion inline static function get_isPixelStage():Bool
	{
		return stageUI == "pixel" || stageUI.endsWith("-pixel");
	}

	@:noCompletion inline public function get_camFollow():CameraTarget
	{
		return isCameraOnForcedPos ? _camFollow : getCharCamFollow(_camTarget);
	}

	@:noCompletion inline function set_camZoomingDecay(decay:Float):Float
	{
		return camZoomingDecay = camGame.zoomDecay = camHUD.zoomDecay = decay;
	}

	@:noCompletion inline function set_camZooming(bool:Bool):Bool
	{
		return camZooming = camGame.updateZoom = camHUD.updateZoom = bool;
	}

	@:noCompletion inline function set_health(HP:Float):Float
	{
		if (health != HP)
		{
			health = FlxMath.bound(HP, healthBar.bounds.min, healthBar.bounds.max);
			doDeathCheck();
		}
		return health;
	}

	@:noCompletion inline function get_healthBarFlip():Bool
	{
		return healthBar.leftToRight;
	}

	@:noCompletion function set_healthBarFlip(value:Bool):Bool
	{
		if (healthBarFlip != value)
		{
			healthBar.leftToRight = value;
			healthBar.setColors(healthBar.rightBar.color, healthBar.leftBar.color);
			iconP1.animation.curAnim.flipX = !value;
			iconP2.animation.curAnim.flipX = value;
			updateIcons();
		}
		return value;
	}

	@:noCompletion inline function set_iconBoping(bool:Bool):Bool
	{
		return iconP2.lerpScale = iconP1.lerpScale = iconBoping = bool;
	}

	@:noCompletion inline function set_iconBopSpeed(speed:Float):Float
	{
		return iconP2.lerpSpeed = iconP1.lerpSpeed = iconBopSpeed = speed;
	}

	@:noCompletion inline function set_cameraSpeed(speed:Float):Float
	{
		if (cameraSpeed != speed)
		{
			cameraSpeed = /*camGame.cameraSpeed =*/ speed;
			calcFollowLerp();
		}
		return speed;
	}

	@:noCompletion inline function set_defaultCamZoom(zoom:Float):Float
	{
		return defaultCamZoom = camGame.targetZoom = zoom;
	}

	@:noCompletion inline function set_defaultHUDZoom(zoom:Float):Float
	{
		return defaultCamZoom = camHUD.targetZoom = zoom;
	}

	@:noCompletion inline function get_playingVideo():Bool
	{
		return #if VIDEOS_ALLOWED #if hxCodec videoPlayer?.isPlaying #else videoPlayer?.bitmap.isPlaying #end ?? #end false;
	}

	@:noCompletion inline function set_inCutscene(bool:Bool):Bool
	{
		camGame.active = !bool;
		return inCutscene = bool;
	}

	@:noCompletion inline function get_boyfriendCameraOffset():Array<Float>
	{
		return [bfCamOffset.x, bfCamOffset.y];
	}

	@:noCompletion inline function get_opponentCameraOffset():Array<Float>
	{
		return [dadCamOffset.x, dadCamOffset.y];
	}

	@:noCompletion inline function get_girlfriendCameraOffset():Array<Float>
	{
		return [gfCamOffset.x, gfCamOffset.y];
	}

	@:noCompletion inline function set_boyfriendCameraOffset(a:Array<Float>):Array<Float>
	{
		if (a != null)
		{
			bfCamOffset.x = a[0];
			if (a.length > 1)
				bfCamOffset.y = a[1];
		}
		return a;
	}
	@:noCompletion inline function set_opponentCameraOffset(a:Array<Float>):Array<Float>
	{
		if (a != null)
		{
			dadCamOffset.x = a[0];
			if (a.length > 1)
				dadCamOffset.y = a[1];
		}
		return a;
	}
	@:noCompletion inline function set_girlfriendCameraOffset(a:Array<Float>):Array<Float>
	{
		if (a != null)
		{
			gfCamOffset.x = a[0];
			if (a.length > 1)
				gfCamOffset.y = a[1];
		}
		return a;
	}

	// rich: yes i am a nerd!! 🤓🤓
	@:noCompletion function set_cpuControlled(value:Bool):Bool
	{
		if (botplayTxt != null)
		{
			botplayTxt.visible = value;
			botplayTxt.alpha = 1;
			botplaySine = 0;
		}
		if (!changedDifficulty && value)
			changedDifficulty = true;

		setOnScripts("botPlay", value);
		return cpuControlled = value;
	}

	@:noCompletion inline function __resizeNotes(ratio:Float) // funny word huh
	{
		if (ratio != -1)
		{
			final combined = unspawnNotes.concat(notes.members);
			var note:Note;
			while (combined.length != 0)
				if ((note = combined.pop()) != null)
					note.resizeByRatio(ratio);
		}
	}

	@:noCompletion function set_songSpeed(value:Float):Float
	{
		if (generatedMusic)
			__resizeNotes(value / songSpeed);

		noteKillOffset = Math.max(Conductor.stepCrochet, 350 / value);
		return songSpeed = value;
	}

	@:noCompletion #if !FLX_PITCH inline #end function set_playbackRate(value:Float):Float
	{
		#if FLX_PITCH
		if (generatedMusic)
		{
			if (vocals != null)
				vocals.pitch = value;
			FlxG.sound.music.pitch = value;
			__resizeNotes(playbackRate / value);
		}
		FlxG.timeScale = playbackRate = value;
		Conductor.safeZoneOffset = (ClientPrefs.data.safeFrames * 0.016666666666666666) * 1000 * value; // / 60
		setOnScripts("playbackRate", playbackRate);
		#else
		playbackRate = 1.0; // ensuring -Crow
		#end
		return value;
	}

	@:noCompletion inline function set_paused(bool:Bool):Bool
	{
		return paused = !(camGame.active = camHUD.active = !bool);
	}
}

// rich: i love abstracts :3
abstract RuntimeShaderData(Array<String>) from Array<String> to Array<String>
{
	public var frag(get, never):String;
	public var vert(get, never):String;

	@:noCompletion inline function get_frag():String			 return this[0];
	@:noCompletion inline function get_vert():String			 return this[1];
	// @:noCompletion inline function set_frag(frag:String):String	 return this[0] = frag;
	// @:noCompletion inline function set_vert(vert:String):String	 return this[1] = vert;
}
