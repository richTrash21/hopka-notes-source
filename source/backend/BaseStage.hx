package backend;

import flixel.FlxBasic;
import flixel.FlxObject;
import backend.MusicBeatState;

import objects.Note.EventNote;
import objects.Character;

enum Countdown
{
	THREE;
	TWO;
	ONE;
	GO;
	START;
}

class BaseStage extends FlxBasic
{
	// some variables for convenience
	public var paused(get, never):Bool;
	public var songName(get, never):String;
	public var isStoryMode(get, never):Bool;
	public var seenCutscene(get, never):Bool;
	public var inCutscene(get, set):Bool;
	public var canPause(get, set):Bool;
	public var members(get, never):Array<FlxBasic>;

	public var boyfriend(get, never):Character;
	public var dad(get, never):Character;
	public var gf(get, never):Character;
	public var boyfriendGroup(get, never):FlxTypedSpriteGroup<Character>;
	public var dadGroup(get, never):FlxTypedSpriteGroup<Character>;
	public var gfGroup(get, never):FlxTypedSpriteGroup<Character>;
	
	public var camGame(get, never):FlxCamera;
	public var camHUD(get, never):FlxCamera;
	public var camOther(get, never):FlxCamera;

	public var defaultCamZoom(get, set):Float;
	public var camFollow(get, never):FlxObject;
	
	var game:MusicBeatState;
	var playState:PlayState; // to get rid of Dynamic type on game variable and avoid casting
	public var onPlayState:Bool;

	@:noCompletion inline function resolveState():MusicBeatState
	{
		// FlxG.state is states.PlayState
		return (onPlayState = PlayState.instance != null) ? (playState = PlayState.instance) : cast FlxG.state; // avoid casting me say?
	}

	public function new()
	{
		super();
		this.game = resolveState();
		// impossible scenario
		/*if (this.game == null)
		{
			FlxG.log.warn('Invalid state for the stage added!');
			destroy();
		}
		else
		{*/
		this.game.stages.push(this);
		create();
		// }
	}

	/** cleanup **/
	override function destroy()
	{
		super.destroy();
		game = null;
		playState = null;
		onPlayState = false;
	}

	//main callbacks
	public function create() {}
	public function createPost() {}
	//public function update(elapsed:Float) {}
	public function countdownTick(count:Countdown, num:Int) {}

	// FNF steps, beats and sections
	public var curBeat:Int = 0;
	public var curDecBeat:Float = 0;
	public var curStep:Int = 0;
	public var curDecStep:Float = 0;
	public var curSection:Int = 0;
	public function beatHit() {}
	public function stepHit() {}
	public function sectionHit() {}

	// Substate close/open, for pausing Tweens/Timers
	public function closeSubState() {}
	public function openSubState(SubState:flixel.FlxSubState) {}

	// Events
	public function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float) {}
	public function eventPushed(event:EventNote) {}
	public function eventPushedUnique(event:EventNote) {}

	// Things to replace FlxGroup stuff and inject sprites directly into the state
	function add(object:FlxBasic):FlxBasic
	{
		return game.add(object);
	}
	function remove(object:FlxBasic):FlxBasic
	{
		return game.remove(object);
	}
	function insert(position:Int, object:FlxBasic):FlxBasic
	{
		return game.insert(position, object);
	}
	
	public function addBehindGF(obj:FlxBasic):FlxBasic
	{
		return onPlayState ? insert(members.indexOf(playState.gfGroup), obj) : obj;
	}
	public function addBehindBF(obj:FlxBasic):FlxBasic
	{
		return onPlayState ? insert(members.indexOf(playState.boyfriendGroup), obj) : obj;
	}
	public function addBehindDad(obj:FlxBasic):FlxBasic
	{
		return onPlayState ? insert(members.indexOf(playState.dadGroup), obj) : obj;
	}

	public function setDefaultGF(name:String) //Fix for the Chart Editor on Base Game stages
	{
		if (onPlayState)
		{
			final gfVersion:String = PlayState.SONG.gfVersion;
			if (gfVersion == null || gfVersion.length < 1)
			{
				PlayState.SONG.gfVersion = name;
			}
		}
		/* else
			FlxG.log.warn("setDefaultGF: Current state is NOT PlayState!"); */
	}

	//start/end callback functions
	public function setStartCallback(myfn:Void->Void)
	{
		if (onPlayState)
			playState.startCallback = myfn;
		/* else
			FlxG.log.warn("setStartCallback: Current state is NOT PlayState!"); */
	}
	public function setEndCallback(myfn:Void->Void)
	{
		if (onPlayState)
			playState.endCallback = myfn;
		/* else
			FlxG.log.warn("setEndCallback: Current state is NOT PlayState!"); */
	}

	//precache functions
	public function precacheImage(key:String)
	{
		precache(key, 'image');
	}
	public function precacheSound(key:String)
	{
		precache(key, 'sound');
	}
	public function precacheMusic(key:String)
	{
		precache(key, 'music');
	}

	public function precache(key:String, type:String)
	{
		if (onPlayState)
			playState.precacheList.set(key, type);

		switch(type)
		{
			case 'image':
				Paths.image(key);
			case 'sound':
				Paths.sound(key);
			case 'music':
				Paths.music(key);
		}
	}

	// overrides
	function startCountdown():Bool
	{
		return onPlayState ? playState.startCountdown() : false;
	}
	function endSong():Bool
	{
		return onPlayState ? playState.endSong() : false;
	}

	function moveCameraSection()
	{
		if (onPlayState)
			playState.moveCameraSection();
	}
	function moveCamera(char:String /*isDad:Bool*/)
	{
		if (onPlayState)
			playState.moveCamera(char /*isDad*/);
	}

	@:noCompletion inline function get_paused():Bool
	{
		return onPlayState ? playState.paused : false;
	}
	@:noCompletion inline function get_songName():String
	{
		return onPlayState ? playState.songName : null;
	}
	@:noCompletion inline function get_isStoryMode():Bool
	{
		return PlayState.isStoryMode;
	}
	@:noCompletion inline function get_seenCutscene():Bool
	{
		return PlayState.seenCutscene;
	}
	@:noCompletion inline function get_inCutscene():Bool
	{
		return onPlayState ? playState.inCutscene : false;
	}
	@:noCompletion inline function set_inCutscene(value:Bool):Bool
	{
		return onPlayState ? playState.inCutscene = value : false;
	}
	@:noCompletion inline function get_canPause()
	{
		return onPlayState ? playState.canPause : false;
	}
	@:noCompletion inline function set_canPause(value:Bool)
	{
		return onPlayState ? playState.canPause = value : false;
	}
	@:noCompletion inline function get_members()
	{
		return game.members;
	}

	@:noCompletion inline function get_boyfriend():Character
	{
		return onPlayState ? playState.boyfriend : null;
	}
	@:noCompletion inline function get_dad():Character
	{
		return onPlayState ? playState.dad : null;
	}
	@:noCompletion inline function get_gf():Character
	{
		return onPlayState ? playState.gf : null;
	}

	@:noCompletion inline function get_boyfriendGroup():FlxTypedSpriteGroup<Character>
	{
		return onPlayState ? playState.boyfriendGroup : null;
	}
	@:noCompletion inline function get_dadGroup():FlxTypedSpriteGroup<Character>
	{
		return onPlayState ? playState.dadGroup : null;
	}
	@:noCompletion inline function get_gfGroup():FlxTypedSpriteGroup<Character>
	{
		return onPlayState ? playState.gfGroup : null;
	}
	
	@:noCompletion inline function get_camGame():FlxCamera
	{
		return FlxG.camera; // since camGame is default camera
	}
	@:noCompletion inline function get_camHUD():FlxCamera
	{
		return playState.camHUD;
	}
	@:noCompletion inline function get_camOther():FlxCamera
	{
		return playState.camOther;
	}

	@:noCompletion inline function get_defaultCamZoom():Float
	{
		return onPlayState ? playState.defaultCamZoom : 0.0;
	}
	@:noCompletion inline function set_defaultCamZoom(value:Float):Float
	{
		return onPlayState ? playState.defaultCamZoom = value : 0.0;
	}
	@:noCompletion inline function get_camFollow():FlxObject
	{
		return onPlayState ? playState.camFollow : null;
	}
}