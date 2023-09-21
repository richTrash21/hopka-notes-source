package substates;

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
	public var boyfriend:Character;
	public var camFollow:FlxObject;
	public var updateCamera:Bool = false;

	public static var characterName:String = 'bf-dead';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'gameOver';
	public static var endSoundName:String = 'gameOverEnd';

	public static var instance:GameOverSubstate;

	// better structurised now
	public static function resetVariables(_song:backend.Song.SwagSong)
	{
		if(_song != null)
		{
			characterName = (_song.gameOverChar != null && _song.gameOverChar.trim().length > 0) ? _song.gameOverChar : 'bf-dead';
			deathSoundName = (_song.gameOverSound != null && _song.gameOverSound.trim().length > 0) ? _song.gameOverSound : 'fnf_loss_sfx';
			loopSoundName = (_song.gameOverLoop != null && _song.gameOverLoop.trim().length > 0) ? _song.gameOverLoop : 'gameOver';
			endSoundName = (_song.gameOverEnd != null && _song.gameOverEnd.trim().length > 0) ? _song.gameOverEnd : 'gameOverEnd';
		}
		else
		{
			characterName = 'bf-dead';
			deathSoundName = 'fnf_loss_sfx';
			loopSoundName = 'gameOver';
			endSoundName = 'gameOverEnd';
		}
	}

	override function create()
	{
		instance = this;
		PlayState.instance.callOnScripts('onGameOverStart');

		super.create();
	}

	public function new(x:Float, y:Float)
	{
		super();

		PlayState.instance.setOnScripts('inGameOver', true);

		Conductor.songPosition = 0;

		boyfriend = new Character(x, y, characterName, true);
		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];
		add(boyfriend);

		FlxG.sound.play(Paths.sound(deathSoundName));
		FlxG.camera.scroll.set();
		FlxG.camera.target = null;

		boyfriend.playAnim('firstDeath');

		camFollow = new FlxObject(boyfriend.getGraphicMidpoint().x, boyfriend.getGraphicMidpoint().y, 1, 1);
		FlxG.camera.focusOn(new flixel.math.FlxPoint(FlxG.camera.scroll.x + (FlxG.camera.width * 0.5), FlxG.camera.scroll.y + (FlxG.camera.height * 0.5)));
		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, 0);
		//FlxG.camera.snapToTarget();
	}

	public var startedDeath:Bool = false;
	var isFollowingAlready:Bool = false;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		PlayState.instance.callOnScripts('onUpdate', [elapsed]);

		if (controls.ACCEPT) endBullshit();

		if (controls.BACK)
		{
			#if desktop DiscordClient.resetClientID(); #end
			FlxG.sound.music.stop();
			PlayState.deathCounter = 0;
			PlayState.seenCutscene = false;
			PlayState.chartingMode = false;

			Mods.loadTopMod();
			MusicBeatState.switchState(PlayState.isStoryMode ? new states.StoryMenuState() : new states.FreeplayState());

			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			PlayState.instance.callOnScripts('onGameOverConfirm', [false]);
		}
		
		if (boyfriend.animation.curAnim != null)
		{
			if (boyfriend.animation.curAnim.name == 'firstDeath' && boyfriend.animation.curAnim.finished && startedDeath)
				boyfriend.playAnim('deathLoop');

			if(boyfriend.animation.curAnim.name == 'firstDeath')
			{
				if(boyfriend.animation.curAnim.curFrame >= 12 && !isFollowingAlready)
				{
					updateCamera = true;
					isFollowingAlready = true;
				}

				if (boyfriend.animation.curAnim.finished)
				{
					updateCamera = true;
					startedDeath = true;
					FlxG.sound.playMusic(Paths.music(loopSoundName));
				}
			}
			// in case of missing animations death will continue with music n' shit
			/*else if(!boyfriend.animation.curAnim.name.startsWith('death') && boyfriend.animation.curAnim.finished)
			{
				updateCamera = true;
				startedDeath = true;
				FlxG.sound.playMusic(Paths.music(loopSoundName));
			}*/
		}
		
		if(updateCamera) FlxG.camera.followLerp = FlxMath.bound(elapsed * 0.6 / (FlxG.updateFramerate / 60), 0, 1);
		else FlxG.camera.followLerp = 0;

		if (FlxG.sound.music.playing) Conductor.songPosition = FlxG.sound.music.time;
		PlayState.instance.callOnScripts('onUpdatePost', [elapsed]);
	}

	var isEnding:Bool = false;

	function endBullshit():Void
	{
		if (!isEnding)
		{
			var ret:Dynamic = PlayState.instance.callOnScripts('onGameOverConfirm', [true], true);
			if (ret != FunkinLua.Function_Stop) {
				isEnding = true;
				boyfriend.playAnim('deathConfirm', true);
				FlxG.sound.music.stop();
				var endSound = Paths.music(endSoundName);
				FlxG.sound.play(endSound != null ? endSound : Paths.sound(endSoundName));
				new FlxTimer().start(0.7, function(tmr:FlxTimer)
				{
					FlxG.camera.fade(FlxColor.BLACK, 2, false, function() MusicBeatState.resetState());
				});
			//PlayState.instance.callOnScripts('onGameOverConfirm', [true]);
			}
		}
	}

	override function destroy()
	{
		instance = null;
		super.destroy();
	}
}
