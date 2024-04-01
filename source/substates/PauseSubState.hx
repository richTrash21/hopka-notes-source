package substates;

import flixel.util.FlxDestroyUtil;
import flixel.addons.transition.FlxTransitionableState;
import flixel.util.FlxStringUtil;

import options.OptionsState;

class PauseSubState extends MusicBeatSubstate
{
	public static var songName:String;

	var grpMenuShit:FlxTypedGroup<Alphabet>;

	var menuItems:Array<String> = [];
	var menuItemsOG:Array<String> = ["Resume", "Restart Song", "Change Difficulty", "Options", "Exit to menu"];
	var difficultyChoices = [];
	var curSelected:Int = 0;

	var pauseMusic:FlxSound;
	var practiceText:FlxText;
	var skipTimeText:FlxText;
	var skipTimeTracker:Alphabet;
	var curTime:Float = Math.max(0, Conductor.songPosition);

	// var missingTextBG:FlxSprite;
	// var missingText:FlxText;

	var errorScreen:ErrorScreen;
	var game = PlayState.instance;

	public function new(?camera:FlxCamera)
	{
		super(0x00000000);
		this.camera = camera ?? FlxG.cameras.list[FlxG.cameras.list.length - 1];
		if (FlxG.renderTile)
			_bgSprite.camera = this.camera;

		persistentUpdate = true;
		destroySubStates = false;
		errorScreen = new ErrorScreen(this.camera);

		if (Difficulty.list.length < 2) // No need to change difficulty if there is only one!
			menuItemsOG.remove("Change Difficulty");

		if (PlayState.chartingMode)
		{
			menuItemsOG.insert(2, "Leave Charting Mode");
			
			var num = 0;
			if (!game.startingSong)
			{
				num = 1;
				menuItemsOG.insert(3, "Skip Time");
			}
			menuItemsOG.insert(3 + num, "End Song");
			menuItemsOG.insert(4 + num, "Toggle Practice Mode");
			menuItemsOG.insert(5 + num, "Toggle Botplay");
		}
		menuItems = menuItemsOG;

		for (i in 0...Difficulty.list.length)
			difficultyChoices.push(Difficulty.getString(i));

		difficultyChoices.push("BACK");

		final musicEnabled = ClientPrefs.data.pauseMusic != "None";
		if (musicEnabled || (songName != null || songName.length != 0))
		{
			pauseMusic = FlxG.sound.load(Paths.music(musicEnabled ? Paths.formatToSongPath(ClientPrefs.data.pauseMusic) : songName), 0, true);
			pauseMusic.play(false, FlxG.random.float(0, pauseMusic.length * 0.5));
			pauseMusic.fadeIn(40, 0, 0.5, (_) -> pauseMusic.fadeTween = null);
		}

		final levelInfo = new FlxText(20, 15, 0, PlayState.SONG.song, 32);
		levelInfo.setFormat(Paths.font("vcr.ttf"), 32);
		levelInfo.x = FlxG.width - levelInfo.width - 20;
		add(levelInfo);

		final levelDifficulty = new FlxText(20, 47, 0, Difficulty.getString().toUpperCase(), 32);
		levelDifficulty.setFormat(Paths.font("vcr.ttf"), 32);
		levelDifficulty.x = FlxG.width - levelDifficulty.width - 20;
		add(levelDifficulty);

		final blueballedTxt = new FlxText(20, 79, 0, "Blueballed: " + PlayState.deathCounter, 32);
		blueballedTxt.setFormat(Paths.font("vcr.ttf"), 32);
		blueballedTxt.x = FlxG.width - blueballedTxt.width - 20;
		add(blueballedTxt);

		practiceText = new FlxText(0, 116, 0, "PRACTICE MODE", 32);
		practiceText.setFormat(Paths.font("vcr.ttf"), 32);
		practiceText.x = FlxG.width - practiceText.width - 20;
		practiceText.visible = game.practiceMode;
		add(practiceText);

		final chartingText = new FlxText(0, 0, 0, "CHARTING MODE", 32);
		chartingText.setFormat(Paths.font("vcr.ttf"), 32);
		chartingText.setPosition(FlxG.width - chartingText.width - 20, FlxG.height - chartingText.height - 20);
		chartingText.visible = PlayState.chartingMode;
		add(chartingText);

		blueballedTxt.alpha = levelDifficulty.alpha = levelInfo.alpha = 0;

		FlxTween.num(0, .6, 0.4, {ease: FlxEase.quartInOut}, (a) -> { bgColor.alphaFloat = a; if (FlxG.renderTile) bgColor = bgColor; });
		FlxTween.tween(levelInfo, {alpha: 1, y: 20}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(levelDifficulty, {alpha: 1, y: levelDifficulty.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.5});
		FlxTween.tween(blueballedTxt, {alpha: 1, y: blueballedTxt.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.7});

		grpMenuShit = new FlxTypedGroup<Alphabet>();
		add(grpMenuShit);

		/*missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0x99000000);
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, "", 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.visible = false;
		add(missingText);*/

		regenMenu();
	}

	var holdTime:Float = 0;
	var cantUnpause:Float = 0.1;
	@:access(flixel.sound.FlxSound._sound)
	override function update(elapsed:Float)
	{
		cantUnpause -= elapsed;
		// if (pauseMusic != null && pauseMusic.volume < 0.5)
		//	pauseMusic.volume += 0.01 * elapsed;

		super.update(elapsed);
		updateSkipTextStuff();

		if (controls.UI_UP_P)
			changeSelection(-1);
		if (controls.UI_DOWN_P)
			changeSelection(1);

		final daSelected = menuItems[curSelected];
		switch (daSelected)
		{
			case "Skip Time":
				final prevTime = curTime;
				final LEFT = controls.UI_LEFT;
				final LEFT_P = controls.UI_LEFT_P;

				if (LEFT_P || controls.UI_RIGHT_P)
				{
					FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);
					curTime += LEFT_P ? -1000 : 1000;
					holdTime = 0;
				}
				else if ((LEFT || controls.UI_RIGHT) && (holdTime += elapsed) > 0.5)
					curTime += (LEFT ? -45000 : 45000) * elapsed;

				if (curTime != prevTime)
				{
					curTime = FlxMath.wrap(Std.int(curTime), 0, Std.int(FlxG.sound.music.length)-1); // CoolUtil.fwrap(curTime, 0, FlxG.sound.music.length);
					updateSkipTimeText();
				}
		}

		if (controls.ACCEPT && (cantUnpause <= 0 || !controls.controllerMode))
		{
			if (menuItems == difficultyChoices)
			{
				try
				{
					if (menuItems.length - 1 != curSelected && difficultyChoices.contains(daSelected))
					{
						PlayState.SONG = backend.Song.loadFromJson(backend.Highscore.formatSong(PlayState.SONG.song, curSelected), PlayState.SONG.song);
						PlayState.storyDifficulty = curSelected;
						MusicBeatState.resetState();
						FlxG.sound.music.volume = 0;
						PlayState.changedDifficulty = true;
						PlayState.chartingMode = false;
						return;
					}					
				}
				catch(e)
				{
					errorScreen.exception = e;
					openSubState(errorScreen);
					/*var errorStr = e.toString();
					if (errorStr.startsWith("[file_contents,assets/data/"))
						errorStr = "Missing file: " + errorStr.substring(27, errorStr.length-1); // Missing chart
					missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
					missingText.screenCenter(Y);
					missingText.visible = true;
					missingTextBG.visible = true;
					FlxG.sound.play(Paths.sound("cancelMenu"));*/

					// super.update(elapsed);
					return;
				}

				menuItems = menuItemsOG;
				regenMenu();
			}

			switch (daSelected)
			{
				case "Resume":
					exitPause();

				case "Change Difficulty":
					menuItems = difficultyChoices;
					deleteSkipTimeText();
					regenMenu();

				case "Toggle Practice Mode":
					game.practiceMode = !game.practiceMode;
					PlayState.changedDifficulty = true;
					practiceText.visible = game.practiceMode;

				case "Restart Song":
					restartSong();

				case "Leave Charting Mode":
					restartSong();
					PlayState.chartingMode = false;

				case "Skip Time":
					if (curTime < Conductor.songPosition)
					{
						PlayState.startOnTime = curTime;
						restartSong(true);
					}
					else
					{
						if (curTime != Conductor.songPosition)
						{
							game.clearNotesBefore(curTime);
							game.setSongTime(curTime);
						}
						else if (curTime == FlxG.sound.music.length)
							endSong();

						exitPause();
					}

				case "End Song":
					endSong();

				case "Toggle Botplay":
					game.cpuControlled = !game.cpuControlled;

				case "Options":
					game.paused = true; // For lua
					if (game.vocals != null)
						game.vocals.volume = 0;
					MusicBeatState.switchState(OptionsState.new);
					if (pauseMusic != null)
					{
						FlxG.sound.playMusic(pauseMusic._sound, pauseMusic.volume);
						FlxG.sound.music.fadeIn(0.8, pauseMusic.volume, 1);
						FlxG.sound.music.time = pauseMusic.time;
						if (pauseMusic.fadeTween != null)
							pauseMusic.fadeTween.cancel();
						pauseMusic.stop();
					}
					OptionsState.onPlayState = true;

				case "Exit to menu":
					if (pauseMusic != null)
					{
						if (pauseMusic.fadeTween != null)
							pauseMusic.fadeTween.cancel();
						pauseMusic.stop();
					}
					#if hxdiscord_rpc
					DiscordClient.resetClientID();
					#end
					PlayState.seenCutscene = false;
					PlayState.deathCounter = 0;

					Mods.loadTopMod();
					MusicBeatState.switchState(PlayState.isStoryMode ? states.StoryMenuState.new : states.FreeplayState.new);
					PlayState.cancelMusicFadeTween();
					FlxG.sound.playMusic(Paths.music("freakyMenu"));
					FlxG.camera.pixelPerfectRender = false;
					PlayState.changedDifficulty = false;
					PlayState.chartingMode = false;
					// FlxG.camera.followLerp = 0;

					objects.HealthIcon.jsonCache.clear();
					objects.Character.jsonCache.clear();
			}
		}
	}

	inline function endSong()
	{
		exitPause();
		game.clearNotesBefore(FlxG.sound.music.length);
		game.finishSong(true);
	}

	public var closing:Bool = false;
	dynamic public function exitPause():Void
	{
		if (closing) // doesn't need to close the thing twice
			return;

		FlxTween.num(.6, 0, .1, {ease: FlxEase.quartInOut}, (a) -> { bgColor.alphaFloat = a; if (FlxG.renderTile) bgColor = bgColor; });
		// var oldMult = 1.;
		// FlxTween.num(1, 0, .1, {ease: FlxEase.quartInOut}, (a) -> forEachOfType(FlxSprite, (obj) -> obj.alpha = obj.alpha / oldMult * (oldMult = a)));
		forEachOfType(FlxSprite, (obj) -> FlxTween.tween(obj, {alpha: 0}, 0.1, {ease: FlxEase.quartInOut}), true);
		if (pauseMusic != null)
		{
			if (pauseMusic.fadeTween != null)
				pauseMusic.fadeTween.cancel();
			pauseMusic.fadeOut(0.1, 0, (_) -> close());
		}
		closing = true;
	}

	inline function deleteSkipTimeText()
	{
		if (skipTimeText != null)
			remove(skipTimeText).destroy();

		skipTimeText = null;
		skipTimeTracker = null;
	}

	public static function restartSong(noTrans = false)
	{
		PlayState.instance.paused = true; // For lua
		FlxG.sound.music.volume = 0;
		if (PlayState.instance.vocals != null)
			PlayState.instance.vocals.volume = 0;

		if (noTrans)
			FlxTransitionableState.skipNextTransIn = FlxTransitionableState.skipNextTransOut = true;

		MusicBeatState.resetState();
	}

	@:access(flixel.system.frontEnds.SoundFrontEnd.destroySound)
	override function destroy()
	{
		if (game.videoPlayer != null)
			game.videoPlayer.resume();

		if (pauseMusic != null)
		{
			FlxG.sound.destroySound(pauseMusic);
			pauseMusic = null;
		}
		errorScreen = FlxDestroyUtil.destroy(errorScreen);
		game = null;
		menuItems = null;
		menuItemsOG = null;
		difficultyChoices = null;
		grpMenuShit = null;
		practiceText = null;
		skipTimeText = null;
		skipTimeTracker = null;
		super.destroy();
	}

	function changeSelection(change = 0):Void
	{
		FlxG.sound.play(Paths.sound("scrollMenu"), 0.4);

		curSelected = FlxMath.wrap(curSelected + change, 0, menuItems.length-1);

		var bullShit = 0;
		for (item in grpMenuShit.members)
		{
			item.targetY = bullShit++ - curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
				if (item == skipTimeTracker)
				{
					curTime = Math.max(0, Conductor.songPosition);
					updateSkipTimeText();
				}
			}
		}
		if (subState != null)
			subState.close();
		// missingText.visible = false;
		// missingTextBG.visible = false;
	}

	function regenMenu():Void
	{
		while (grpMenuShit.members.length > 0)
			grpMenuShit.members.pop().destroy();

		for (i in 0...menuItems.length)
		{
			final item = new Alphabet(90, 320, menuItems[i], true);
			item.isMenuItem = true;
			item.targetY = i;
			grpMenuShit.add(item);

			if (menuItems[i] == "Skip Time")
			{
				skipTimeText = new FlxText(0, 0, 0, "", 64);
				skipTimeText.setFormat(Paths.font("vcr.ttf"), 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				skipTimeText.borderSize = 2;
				skipTimeTracker = item;
				add(skipTimeText);

				updateSkipTextStuff();
				updateSkipTimeText();
			}
		}
		curSelected = 0;
		changeSelection();
	}
	
	inline function updateSkipTextStuff()
	{
		if (skipTimeText == null || skipTimeTracker == null)
			return;

		skipTimeText.x = skipTimeTracker.x + skipTimeTracker.width + 60;
		skipTimeText.y = skipTimeTracker.y;
		skipTimeText.visible = (skipTimeTracker.alpha >= 1);
	}

	inline function updateSkipTimeText()
	{
		skipTimeText.text = FlxStringUtil.formatTime(curTime * 0.001, false) + " / " + FlxStringUtil.formatTime(FlxG.sound.music.length * 0.001, false);
	}
}

@:noCompletion private class ErrorScreen extends flixel.FlxSubState
{
	public var exception:haxe.Exception;
	var text:FlxText;

	public function new(camera:FlxCamera)
	{
		super(0x99000000);
		this.camera = camera;
		if (FlxG.renderTile)
			_bgSprite.camera = camera;

		text = new FlxText(50, 0, FlxG.width - 100, "", 24);
		text.font = Paths.font("vcr.ttf");
		text.alignment = CENTER;
		add(text.setBorderStyle(OUTLINE, FlxColor.BLACK));

		openCallback = () ->
		{
			Main.warn('ERROR! $exception');
			var errorStr = exception.toString();
			if (errorStr.startsWith("[file_contents,assets/data/"))
				errorStr = "Missing file: " + errorStr.substring(27, errorStr.length-1); // Missing chart

			text.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
			text.screenCenter(Y);
			FlxG.sound.play(Paths.sound("cancelMenu"));
		}
	}

	override public function destroy()
	{
		super.destroy();
		exception = null;
		text = null;
	}
}
