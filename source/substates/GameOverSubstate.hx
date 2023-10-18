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

	// better structurised now
	public static var characterName(default, set):String = 'bf-dead';
	public static var deathSoundName(default, set):String = 'fnf_loss_sfx';
	public static var loopSoundName(default, set):String = 'gameOver';
	public static var endSoundName(default, set):String = 'gameOverEnd';

	public static var instance:GameOverSubstate;

	public static function resetVariables(_song:backend.Song.SwagSong)
	{
		if(_song != null)
		{
			characterName = _song.gameOverChar;
			deathSoundName = _song.gameOverSound;
			loopSoundName = _song.gameOverLoop;
			endSoundName = _song.gameOverEnd;
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

		if(PlayState.instance.boyfriendMap.exists(characterName)) {
			boyfriend = PlayState.instance.boyfriendMap.get(characterName);
			boyfriend.setPosition(x, y);
			boyfriend.alpha = 1;
		}
		else boyfriend = new Character(x, y, characterName, true);
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
		
		FlxG.camera.followLerp = updateCamera ? elapsed * 0.6 / (FlxG.updateFramerate / 60) #if (flixel >= "5.4.0") * 16 #end : 0;

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
				FlxG.sound.play(Paths.sound(endSoundName));
				
				new FlxTimer().start(0.7, function(tmr:FlxTimer)
					FlxG.camera.fade(FlxColor.BLACK, 2, false, function() MusicBeatState.resetState())
				);
			}
		}
	}

	override function destroy()
	{
		instance = null;
		super.destroy();
	}

	@:noCompletion static function set_characterName(value:String):String {
		characterName = (value != null && value.trim().length > 0) ? value : 'bf-dead';
		if(!PlayState.instance.boyfriendMap.exists(characterName)) PlayState.instance.addCharacterToList(characterName, 0);
		return value;
	}
	@:noCompletion static function set_deathSoundName(value:String):String {
		deathSoundName = (value != null) ? value : 'fnf_loss_sfx';
		Paths.sound(deathSoundName);
		return value;
	}
	@:noCompletion static function set_loopSoundName(value:String):String {
		loopSoundName = (value != null) ? value : 'gameOver';
		Paths.sound(loopSoundName);
		return value;
	}
	@:noCompletion static function set_endSoundName(value:String):String {
		endSoundName = (value != null) ? value : 'gameOverEnd';
		Paths.sound(endSoundName);
		return value;
	}
}
