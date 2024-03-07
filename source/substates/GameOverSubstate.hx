package substates;

import objects.GameCamera;
import objects.Character;
import flixel.FlxObject;
import flixel.math.FlxPoint;

#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.FunkinLua;
import psychlua.LuaUtils;
import psychlua.HScript;
#end

class GameOverSubstate extends MusicBeatSubstate
{
	inline static final DEFAULT_CHAR  = "bf-dead";
	inline static final DEFAULT_SOUND = "fnf_loss_sfx";
	inline static final DEFAULT_LOOP  = "gameOver";
	inline static final DEFAULT_END   = "gameOverEnd";

	public var boyfriend:Character;
	public var camFollow(get, never):FlxObject;
	public var updateCamera(default, set):Bool = false;
	public var realCamera(default, null):GameCamera; // = cast FlxG.camera; // whoops😬

	@:noCompletion inline function get_camFollow():FlxObject
	{
		return boyfriend.camFollow;
	}

	@:noCompletion inline function set_updateCamera(bool:Bool):Bool
	{
		return updateCamera == bool ? bool : realCamera.updateLerp = updateCamera = bool;
	}

	// better structurised now
	public static var characterName  = DEFAULT_CHAR;
	public static var deathSoundName = DEFAULT_SOUND;
	public static var loopSoundName  = DEFAULT_LOOP;
	public static var endSoundName   = DEFAULT_END;

	public static var instance(default, null):GameOverSubstate;
	public static var game(default, null):PlayState;

	public static function resetVariables(_song:backend.Song.SwagSong)
	{
		if (_song == null)
			return;

		characterName	= _song.gameOverChar?.length  == 0 ? DEFAULT_CHAR  : _song.gameOverChar;
		deathSoundName	= _song.gameOverSound?.length == 0 ? DEFAULT_SOUND : _song.gameOverSound;
		loopSoundName	= _song.gameOverLoop?.length  == 0 ? DEFAULT_LOOP  : _song.gameOverLoop;
		endSoundName	= _song.gameOverEnd?.length   == 0 ? DEFAULT_END   : _song.gameOverEnd;

		if (!PlayState.instance.boyfriendMap.exists(characterName))
			PlayState.instance.addCharacterToList(characterName, 0);

		Paths.sound(deathSoundName);
		Paths.music(loopSoundName);
		Paths.sound(endSoundName);
	}

	override function create()
	{
		instance = this;

		realCamera = PlayState.instance.camGame;
		realCamera.updateLerp = realCamera.updateZoom = false;
		realCamera._speed *= 0.25;
		realCamera.cameraSpeed = 1;

		game.callOnScripts("onGameOverStart");
		boyfriend.animation.callback = onAnimationUpdate;
		boyfriend.animation.finishCallback = onAnimationFinished;
		super.create();
	}

	public function new(x:Float, y:Float)
	{
		game = PlayState.instance;
		super();

		game.setOnScripts("inGameOver", true);
		Conductor.songPosition = 0;

		if (game.boyfriendMap.exists(characterName))
		{
			boyfriend = game.boyfriendMap.get(characterName);
			boyfriend.setPosition(x, y);
			boyfriend.alpha = 1;
		}
		else
			boyfriend = new Character(x, y, characterName, true);

		boyfriend.x += boyfriend.position.x;
		boyfriend.y += boyfriend.position.y;
		add(boyfriend);

		FlxG.sound.play(Paths.sound(deathSoundName));
		boyfriend.playAnim("firstDeath");

		final midpoint:FlxPoint = boyfriend.getGraphicMidpoint();
		camFollow.setPosition(midpoint.x, midpoint.y);
		add(camFollow);
		midpoint.put();

		realCamera.follow(camFollow, LOCKON, 0);
		realCamera.scroll.set();
	}

	dynamic public static function onAnimationUpdate(name:String, frame:Int, frameID:Int):Void
	{
		if (name == "firstDeath" && frame >= 12 && !instance.isFollowingAlready)
			instance.updateCamera = instance.isFollowingAlready = true;
	}

	dynamic public static function onAnimationFinished(name:String):Void
	{
		if (name == "firstDeath")
		{
			instance.updateCamera = instance.startedDeath = true;
			FlxG.sound.playMusic(Paths.music(loopSoundName));
			instance.boyfriend.playAnim("deathLoop");
		}
		// in case of missing animations death will continue with music n' shit
		/*else if(!name.startsWith("death"))
		{
			instance.updateCamera = instance.startedDeath = true;
			FlxG.sound.playMusic(Paths.music(loopSoundName));
		}*/
	}

	public var startedDeath = false;
	var isFollowingAlready = false;

	override function update(elapsed:Float)
	{
		game.callOnScripts("onUpdate", [elapsed]);

		if (!isEnding)
		{
			if (controls.ACCEPT)
				endBullshit();
			else if (controls.BACK)
			{
				#if desktop DiscordClient.resetClientID(); #end
				FlxG.sound.music.stop();
				PlayState.deathCounter = 0;
				PlayState.seenCutscene = PlayState.chartingMode = false;

				Mods.loadTopMod();
				MusicBeatState.switchState(PlayState.isStoryMode ? states.StoryMenuState.new : states.FreeplayState.new);

				FlxG.sound.playMusic(Paths.music("freakyMenu"));
				game.callOnScripts("onGameOverConfirm", [false]);
			}
		}

		if (FlxG.sound.music.playing)
			Conductor.songPosition = FlxG.sound.music.time;

		super.update(elapsed);
		game.callOnScripts("onUpdatePost", [elapsed]);
	}

	var isEnding = false;
	function endBullshit():Void
	{
		final ret:Dynamic = game.callOnScripts("onGameOverConfirm", [true], true);
		if (ret == FunkinLua.Function_Stop)
			return;

		isEnding = true;
		boyfriend.playAnim("deathConfirm", true);

		FlxG.sound.music.stop();
		FlxG.sound.play(Paths.sound(endSoundName));
		
		new FlxTimer().start(0.7, (_) -> realCamera.fade(FlxColor.BLACK, 2, false, MusicBeatState.resetState));
	}

	override function destroy()
	{
		game = null;
		instance = null;
		super.destroy();
	}
}
