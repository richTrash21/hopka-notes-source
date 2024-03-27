package substates;

import objects.GameCamera;
import objects.Character;
import flixel.FlxObject;

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

		characterName  = _song.gameOverChar?.length  > 0 ? _song.gameOverChar  : DEFAULT_CHAR;
		deathSoundName = _song.gameOverSound?.length > 0 ? _song.gameOverSound : DEFAULT_SOUND;
		loopSoundName  = _song.gameOverLoop?.length  > 0 ? _song.gameOverLoop  : DEFAULT_LOOP;
		endSoundName   = _song.gameOverEnd?.length   > 0 ? _song.gameOverEnd   : DEFAULT_END;

		if (!PlayState.instance.boyfriendMap.exists('GameOverSubstate__$characterName'))
		{
			// PlayState.instance.addCharacterToList('GameOverSubstate__$characterName', 0);
			final char = new Character(0, 0, characterName, true);
			PlayState.instance.boyfriendMap.set('GameOverSubstate__$characterName', char);
			char.precache();
			PlayState.instance.startCharacterScripts(char.curCharacter);
		}

		Paths.sound(deathSoundName);
		Paths.music(loopSoundName);
		Paths.sound(endSoundName);
	}

	public function new(x:Float, y:Float)
	{
		super();
		instance = this;
		game = PlayState.instance;
		realCamera = game.camGame;

		game.setOnScripts("inGameOver", true);
		Conductor.songPosition = 0;

		if (game.boyfriendMap.exists('GameOverSubstate__$characterName'))
		{
			boyfriend = game.boyfriendMap.get('GameOverSubstate__$characterName');
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

		final midpoint = boyfriend.getGraphicMidpoint();
		boyfriend.camFollow.setPosition(midpoint.x, midpoint.y);
		// add(boyfriend.camFollow);
		midpoint.put();

		realCamera.target = boyfriend.camFollow;
		realCamera.scroll.set();
	}

	override function create()
	{
		realCamera.updateLerp = realCamera.updateZoom = false;
		realCamera._speed *= 0.25;
		realCamera.cameraSpeed = 1;

		callOnScripts("onGameOverStart");
		boyfriend.animation.callback = onAnimationUpdate;
		boyfriend.animation.finishCallback = onAnimationFinished;
		super.create();
	}

	dynamic public /*static*/ function onAnimationUpdate(name:String, frame:Int, frameID:Int):Void
	{
		if (name == "firstDeath" && frame >= 12 && !/*instance.*/isFollowingAlready)
			/*instance.*/updateCamera = /*instance.*/isFollowingAlready = true;
	}

	dynamic public /*static*/ function onAnimationFinished(name:String):Void
	{
		if (name == "firstDeath")
		{
			/*instance.*/updateCamera = /*instance.*/startedDeath = true;
			FlxG.sound.playMusic(Paths.music(loopSoundName));
			/*instance.*/boyfriend.playAnim("deathLoop");
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
		callOnScripts("onUpdate", [elapsed]);

		if (!isEnding)
		{
			if (controls.ACCEPT)
				endBullshit();
			else if (controls.BACK)
			{
				#if hxdiscord_rpc
				DiscordClient.resetClientID();
				#end
				FlxG.sound.music.stop();
				PlayState.deathCounter = 0;
				PlayState.seenCutscene = PlayState.chartingMode = false;

				Mods.loadTopMod();
				MusicBeatState.switchState(PlayState.isStoryMode ? states.StoryMenuState.new : states.FreeplayState.new);

				FlxG.sound.playMusic(Paths.music("freakyMenu"));
				callOnScripts("onGameOverConfirm", [false]);
			}
		}

		if (FlxG.sound.music.playing)
			Conductor.songPosition = FlxG.sound.music.time;

		super.update(elapsed);
		callOnScripts("onUpdatePost", [elapsed]);
	}

	var isEnding = false;
	function endBullshit():Void
	{
		final ret:Dynamic = callOnScripts("onGameOverConfirm", [true], true);
		if (ret == FunkinLua.Function_Stop)
			return;

		isEnding = true;
		boyfriend.playAnim("deathConfirm", true);

		FlxG.sound.music.stop();
		FlxG.sound.play(Paths.sound(endSoundName));
		new FlxTimer().start(0.7, (_) -> realCamera.fade(FlxColor.BLACK, 2, false, MusicBeatState.resetState));
	}

	inline function callOnScripts(funcToCall:String, ?args:Array<Dynamic>, ignoreStops = false, ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>):Dynamic
	{
		return game == null ? FunkinLua.Function_Continue : game.callOnScripts(funcToCall, args, ignoreStops, exclusions, excludeValues);
	}

	override function destroy()
	{
		realCamera.target = null;
		super.destroy();
		realCamera = null;
		boyfriend = null;
		instance = null;
		game = null;
	}
}
