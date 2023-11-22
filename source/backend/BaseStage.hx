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

class BaseStage extends FlxBasic implements IMusicBeatState
{
	private var game(default, set):MusicBeatState = PlayState.instance;
	public var onPlayState:Bool = false;

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
	public var boyfriendGroup(get, never):FlxSpriteGroup;
	public var dadGroup(get, never):FlxSpriteGroup;
	public var gfGroup(get, never):FlxSpriteGroup;
	
	public var camGame(get, never):FlxCamera;
	public var camHUD(get, never):FlxCamera;
	public var camOther(get, never):FlxCamera;

	public var defaultCamZoom(get, set):Float;
	public var camFollow(get, never):FlxObject;

	public function new()
	{
		this.game = cast MusicBeatState.getState();
		if(this.game == null || !(this.game is MusicBeatState))
		{
			FlxG.log.warn('Invalid state for the stage added!');
			destroy();
			return;
		}
		this.game.stages.push(this);
		super();
		create();
	}

	//main callbacks
	public function create() {}
	public function createPost() {}
	//public function update(elapsed:Float) {} // АНЕКДОТ????????
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
		return game.add(object);
	function remove(object:FlxBasic):FlxBasic
		return game.remove(object);
	function insert(position:Int, object:FlxBasic):FlxBasic
		return game.insert(position, object);
	
	public function addBehindGF(obj:FlxBasic):FlxBasic
	{
		if (!onPlayState)
			return null;

		return insert(members.indexOf(cast (game, PlayState).gfGroup), obj);
	}
	public function addBehindBF(obj:FlxBasic):FlxBasic
	{
		if (!onPlayState)
			return null;

		return insert(members.indexOf(cast (game, PlayState).boyfriendGroup), obj);
	}
	public function addBehindDad(obj:FlxBasic):FlxBasic
	{
		if (!onPlayState)
			return null;

		return insert(members.indexOf(cast (game, PlayState).dadGroup), obj);
	}

	public function setDefaultGF(name:String) //Fix for the Chart Editor on Base Game stages
	{
		final gfVersion:String = PlayState.SONG.gfVersion;

		if(gfVersion == null || gfVersion.length < 1)
			PlayState.SONG.gfVersion = name;
	}

	//start/end callback functions
	public function setStartCallback(myfn:Void->Void)
	{
		if(!onPlayState) return;
		cast (game, PlayState).startCallback = myfn;
	}
	public function setEndCallback(myfn:Void->Void)
	{
		if(!onPlayState) return;
		cast (game, PlayState).endCallback = myfn;
	}

	//precache functions
	public function precacheImage(key:String) precache(key, 'image');
	public function precacheSound(key:String) precache(key, 'sound');
	public function precacheMusic(key:String) precache(key, 'music');

	public function precache(key:String, type:String)
	{
		if(onPlayState)
			cast (game, PlayState).precacheList.set(key, type);

		switch(type)
		{
			case 'image': Paths.image(key);
			case 'sound': Paths.sound(key);
			case 'music': Paths.music(key);
		}
	}

	// overrides
	function startCountdown():Bool
	{
		if (onPlayState)
			return cast (game, PlayState).startCountdown();

		return false;
	}
	function endSong():Bool
	{
		if (onPlayState)
			return cast (game, PlayState).endSong();

		return false;
	}
	
	function moveCameraSection()
	{
		@:privateAccess
		if (onPlayState)
			cast (game, PlayState).moveCameraSection();
	}
	function moveCamera(char:String)
	{
		if (onPlayState)
			cast (game, PlayState).moveCamera(char);
	}

	inline private function get_paused():Bool
		return onPlayState ? cast (game, PlayState).paused : false;
	inline private function get_songName():String
		return onPlayState ? cast (game, PlayState).songName : null;
	inline private function get_isStoryMode():Bool
		return PlayState.isStoryMode;
	inline private function get_seenCutscene():Bool
		return PlayState.seenCutscene;

	inline private function get_inCutscene():Bool
		return onPlayState ? cast (game, PlayState).inCutscene : false;
	inline private function set_inCutscene(value:Bool):Bool
	{
		if (onPlayState)
			cast (game, PlayState).inCutscene = value;

		return value;
	}
	
	inline private function get_canPause():Bool
	{
		@:privateAccess
		return onPlayState ? cast (game, PlayState).canPause : false;
	}
	inline private function set_canPause(value:Bool):Bool
	{
		@:privateAccess
		if (onPlayState)
			cast (game, PlayState).canPause = value;

		return value;
	}

	inline private function get_members():Array<FlxBasic>
		return game.members;
	inline private function set_game(value:MusicBeatState):MusicBeatState
	{
		onPlayState = value is PlayState;
		return game = value;
	}

	inline private function get_boyfriend():Character
		return onPlayState ? cast (game, PlayState).boyfriend : null;
	inline private function get_dad():Character
		return onPlayState ? cast (game, PlayState).dad : null;
	inline private function get_gf():Character
		return onPlayState ? cast (game, PlayState).gf : null;

	inline private function get_boyfriendGroup():FlxSpriteGroup
		return onPlayState ? cast (game, PlayState).boyfriendGroup : null;
	inline private function get_dadGroup():FlxSpriteGroup
		return onPlayState ? cast (game, PlayState).dadGroup : null;
	inline private function get_gfGroup():FlxSpriteGroup
		return onPlayState ? cast (game, PlayState).gfGroup : null;
	
	inline private function get_camGame():FlxCamera
		return onPlayState ? cast (game, PlayState).camGame : FlxG.camera;
	inline private function get_camHUD():FlxCamera
		return onPlayState ? cast (game, PlayState).camHUD : null;
	inline private function get_camOther():FlxCamera
		return onPlayState ? cast (game, PlayState).camOther : null;

	inline private function get_defaultCamZoom():Float
		return onPlayState ? cast (game, PlayState).defaultCamZoom : 1;
	inline private function set_defaultCamZoom(value:Float):Float
	{
		if (onPlayState)
			cast (game, PlayState).defaultCamZoom = value;

		return value;
	}
	inline private function get_camFollow():FlxObject
		return FlxG.camera.target;
}