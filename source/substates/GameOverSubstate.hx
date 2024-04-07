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
	inline public static final DEFAULT_CHAR  = "bf-dead";
	inline public static final DEFAULT_SOUND = "fnf_loss_sfx";
	inline public static final DEFAULT_LOOP  = "gameOver";
	inline public static final DEFAULT_END   = "gameOverEnd";

	public var boyfriend:Character;
	public var camFollow(default, null):FlxObject;
	public var updateCamera(default, set):Bool;
	public var realCamera(default, null):GameCamera;

	// better structurised now
	public static var characterName  = DEFAULT_CHAR;
	public static var deathSoundName = DEFAULT_SOUND;
	public static var loopSoundName  = DEFAULT_LOOP;
	public static var endSoundName   = DEFAULT_END;

	public static var instance(default, null):GameOverSubstate;
	public static var game(default, null):PlayState;

	static final __midpoint = FlxPoint.get();

	public static function resetVariables(_song:backend.Song)
	{
		if (_song == null)
			return;

		characterName  = _song.gameOverChar.isNullOrEmpty()  ? DEFAULT_CHAR  : _song.gameOverChar;
		deathSoundName = _song.gameOverSound.isNullOrEmpty() ? DEFAULT_SOUND : _song.gameOverSound;
		loopSoundName  = _song.gameOverLoop.isNullOrEmpty()  ? DEFAULT_LOOP  : _song.gameOverLoop;
		endSoundName   = _song.gameOverEnd.isNullOrEmpty()   ? DEFAULT_END   : _song.gameOverEnd;

		if (!PlayState.instance.boyfriendMap.exists('GameOverSubstate__$characterName'))
		{
			final char = new Character(characterName, true);
			PlayState.instance.boyfriendMap.set('GameOverSubstate__$characterName', char);
			char.precache();
			char.kill();
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
			boyfriend.addPosition(x, y);
			boyfriend.revive();
		}
		else
			boyfriend = new Character(x, y, characterName, true);

		add(boyfriend);
		boyfriend.playAnim("firstDeath");

		boyfriend.getGraphicMidpoint(__midpoint);
		boyfriend.camFollow.setPosition(__midpoint.x, __midpoint.y);
		realCamera.target = (camFollow = boyfriend.camFollow);
		realCamera.scroll.set();
	}

	override function create()
	{
		FlxG.sound.play(Paths.sound(deathSoundName));
		realCamera.updateZoom = false;
		realCamera.followLerp = 0.0;

		game.callOnScripts("onGameOverStart");
		boyfriend.animation.callback = onAnimationUpdate;
		boyfriend.animation.finishCallback = onAnimationFinished;
	}

	dynamic public function onAnimationUpdate(name:String, frame:Int, frameID:Int):Void
	{
		if (name == "firstDeath" && frame >= 12 && !isFollowingAlready)
			updateCamera = isFollowingAlready = true;
	}

	dynamic public function onAnimationFinished(name:String):Void
	{
		if (name == "firstDeath")
		{
			updateCamera = startedDeath = true;
			FlxG.sound.playMusic(Paths.music(loopSoundName));
			boyfriend.playAnim("deathLoop");
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
				#if hxdiscord_rpc
				DiscordClient.resetClientID();
				#end
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

	override public function beatHit()
	{
		if (boyfriend.animation.curAnim == null || boyfriend.animation.curAnim.name != "deathLoop")
			return;

		game.tryDance(boyfriend, curBeat);
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
		realCamera.target = null;
		super.destroy();
		realCamera = null;
		boyfriend = null;
		instance = null;
		game = null;
	}

	@:noCompletion inline function set_updateCamera(bool:Bool):Bool
	{
		if (updateCamera != bool)
			realCamera.followLerp = (updateCamera = bool) ? 0.01 : 0.0;

		return bool;
	}
}
