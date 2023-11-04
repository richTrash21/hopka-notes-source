package substates;

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
	public var camFollow:FlxObject;
	public var updateCamera:Bool = false;

	// better structurised now
	public static var characterName:String = 'bf-dead';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'gameOver';
	public static var endSoundName:String = 'gameOverEnd';

	public static var instance:GameOverSubstate;
	public static var game(default, null):PlayState;

	public static function resetVariables(_song:backend.Song.SwagSong)
	{
		if(_song != null)
		{
			characterName = (_song.gameOverChar != null && _song.gameOverChar.trim().length > 0) ? _song.gameOverChar : 'bf-dead';
			deathSoundName = (_song.gameOverSound != null && _song.gameOverSound.trim().length > 0) ? _song.gameOverSound : 'fnf_loss_sfx';
			loopSoundName = (_song.gameOverLoop != null && _song.gameOverLoop.trim().length > 0) ? _song.gameOverLoop : 'gameOver';
			endSoundName = (_song.gameOverEnd != null && _song.gameOverEnd.trim().length > 0) ? _song.gameOverEnd : 'gameOverEnd';

			if(!PlayState.instance.boyfriendMap.exists(characterName))
				PlayState.instance.addCharacterToList(characterName, 0);
			Paths.sound(deathSoundName);
			Paths.sound(loopSoundName);
			Paths.sound(endSoundName);
		}
	}

	override function create()
	{
		instance = this;
		game.callOnScripts('onGameOverStart');

		super.create();
	}

	public function new(x:Float, y:Float)
	{
		game = PlayState.instance;
		super();

		game.setOnScripts('inGameOver', true);

		Conductor.songPosition = 0;

		if(game.boyfriendMap.exists(characterName)) {
			boyfriend = game.boyfriendMap.get(characterName);
			boyfriend.setPosition(x, y);
			boyfriend.alpha = 1;
		}
		else boyfriend = new Character(x, y, characterName, true);
		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];
		add(boyfriend);

		boyfriend.animation.callback = function(Name:String, Frame:Int, FrameID:Int) {
			if(Name == 'firstDeath' && Frame >= 12 && !isFollowingAlready)
			{
				updateCamera = true;
				isFollowingAlready = true;
			}
		}
		boyfriend.animation.finishCallback = function(Name:String) {
			if (Name == 'firstDeath')
			{
				updateCamera = true;
				startedDeath = true;
				FlxG.sound.playMusic(Paths.music(loopSoundName));
				boyfriend.playAnim('deathLoop');
			}
			// in case of missing animations death will continue with music n' shit
			/*else if(!boyfriend.animation.curAnim.name.startsWith('death') && boyfriend.animation.curAnim.finished)
			{
				updateCamera = true;
				startedDeath = true;
				FlxG.sound.playMusic(Paths.music(loopSoundName));
			}*/
		}

		FlxG.sound.play(Paths.sound(deathSoundName));
		boyfriend.playAnim('firstDeath');

		var midpoint:FlxPoint = boyfriend.getGraphicMidpoint();
		camFollow = new FlxObject(midpoint.x, midpoint.y, 1, 1);
		add(camFollow);
		midpoint.put();

		FlxG.camera.follow(camFollow, LOCKON, 0);
		FlxG.camera.scroll.set();
	}

	public var startedDeath:Bool = false;
	var isFollowingAlready:Bool = false;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		game.callOnScripts('onUpdate', [elapsed]);

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
			game.callOnScripts('onGameOverConfirm', [false]);
		}
		
		FlxG.camera.followLerp = updateCamera ? elapsed * 0.6 #if (flixel < "5.4.0") / #else * #end (FlxG.updateFramerate / 60) : 0;

		if (FlxG.sound.music.playing) Conductor.songPosition = FlxG.sound.music.time;
		game.callOnScripts('onUpdatePost', [elapsed]);
	}

	var isEnding:Bool = false;

	function endBullshit():Void
	{
		if (!isEnding)
		{
			var ret:Dynamic = game.callOnScripts('onGameOverConfirm', [true], true);
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
		game = null;
		instance = null;
		super.destroy();
	}
}
