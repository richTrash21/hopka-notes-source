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
	public var boyfriend:Character;
	public var camFollow(get, never):FlxObject;
	public var updateCamera(default, set):Bool = false;
	public final realCamera:GameCamera = cast FlxG.camera; // whoops😬

	@:noCompletion inline function get_camFollow():FlxObject
		return boyfriend.camFollow;

	@:noCompletion inline function set_updateCamera(bool:Bool):Bool
	{
		if (updateCamera == bool)
			return bool;

		return realCamera.updateLerp = updateCamera = bool;
	}

	// better structurised now
	public static var characterName:String = 'bf-dead';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'gameOver';
	public static var endSoundName:String = 'gameOverEnd';

	public static var instance(default, null):GameOverSubstate;
	public static var game(default, null):PlayState;

	public static function resetVariables(_song:backend.Song.SwagSong)
	{
		if(_song != null)
		{
			characterName	= (_song.gameOverChar	!= null && _song.gameOverChar.trim().length	 > 0) ? _song.gameOverChar	: 'bf-dead';
			deathSoundName	= (_song.gameOverSound	!= null && _song.gameOverSound.trim().length > 0) ? _song.gameOverSound	: 'fnf_loss_sfx';
			loopSoundName	= (_song.gameOverLoop	!= null && _song.gameOverLoop.trim().length	 > 0) ? _song.gameOverLoop	: 'gameOver';
			endSoundName	= (_song.gameOverEnd	!= null && _song.gameOverEnd.trim().length	 > 0) ? _song.gameOverEnd	: 'gameOverEnd';

			if(!PlayState.instance.boyfriendMap.exists(characterName))
				PlayState.instance.addCharacterToList(characterName, 0);
			Paths.sound(deathSoundName);
			Paths.music(loopSoundName);
			Paths.sound(endSoundName);
		}
	}

	override function create()
	{
		instance = this;

		realCamera.updateLerp = realCamera.updateZoom = false;
		realCamera._speed *= 4;
		realCamera.cameraSpeed = 1;

		game.callOnScripts('onGameOverStart');
		boyfriend.animation.callback = onAnimationUpdate;
		boyfriend.animation.finishCallback = onAnimationFinished;
		super.create();
	}

	public function new(x:Float, y:Float)
	{
		game = PlayState.instance;
		super();

		game.setOnScripts('inGameOver', true);
		Conductor.songPosition = 0;

		if(game.boyfriendMap.exists(characterName))
		{
			boyfriend = game.boyfriendMap.get(characterName);
			boyfriend.setPosition(x, y);
			boyfriend.alpha = 1;
		}
		else boyfriend = new Character(x, y, characterName, true);
		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];
		add(boyfriend);

		FlxG.sound.play(Paths.sound(deathSoundName));
		boyfriend.playAnim('firstDeath');

		final midpoint:FlxPoint = boyfriend.getGraphicMidpoint();
		camFollow.setPosition(midpoint.x, midpoint.y);
		add(camFollow);
		midpoint.put();

		realCamera.follow(camFollow, LOCKON, 0);
		realCamera.scroll.set();
	}

	dynamic public function onAnimationUpdate(Name:String, Frame:Int, FrameID:Int):Void
	{
		if (Name == 'firstDeath' && Frame >= 12 && !isFollowingAlready)
			updateCamera = isFollowingAlready = true;
	}

	dynamic public function onAnimationFinished(Name:String):Void
	{
		if (Name == 'firstDeath')
		{
			updateCamera = startedDeath = true;
			FlxG.sound.playMusic(Paths.music(loopSoundName));
			boyfriend.playAnim('deathLoop');
		}
		// in case of missing animations death will continue with music n' shit
		/*else if(!boyfriend.animation.curAnim.name.startsWith('death') && boyfriend.animation.curAnim.finished)
		{
			updateCamera = startedDeath = true;
			FlxG.sound.playMusic(Paths.music(loopSoundName));
		}*/
	}

	public var startedDeath:Bool = false;
	var isFollowingAlready:Bool = false;
	override function update(elapsed:Float)
	{
		game.callOnScripts('onUpdate', [elapsed]);

		if (controls.ACCEPT) endBullshit();
		if (controls.BACK)
		{
			#if desktop DiscordClient.resetClientID(); #end
			FlxG.sound.music.stop();
			PlayState.deathCounter = 0;
			PlayState.seenCutscene = PlayState.chartingMode = false;

			Mods.loadTopMod();
			MusicBeatState.switchState(PlayState.isStoryMode ? new states.StoryMenuState() : new states.FreeplayState());

			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			game.callOnScripts('onGameOverConfirm', [false]);
		}

		if (FlxG.sound.music.playing) Conductor.songPosition = FlxG.sound.music.time;

		super.update(elapsed);
		game.callOnScripts('onUpdatePost', [elapsed]);
	}

	var isEnding:Bool = false;
	function endBullshit():Void
	{
		if (isEnding) return;

		final ret:Dynamic = game.callOnScripts('onGameOverConfirm', [true], true);
		if (ret == FunkinLua.Function_Stop)
			return;

		isEnding = true;
		boyfriend.playAnim('deathConfirm', true);

		FlxG.sound.music.stop();
		FlxG.sound.play(Paths.sound(endSoundName));
		
		new FlxTimer().start(0.7, function(tmr:FlxTimer) realCamera.fade(FlxColor.BLACK, 2, false, function() MusicBeatState.resetState()));
	}

	override function destroy()
	{
		game = null;
		instance = null;
		super.destroy();
	}
}
