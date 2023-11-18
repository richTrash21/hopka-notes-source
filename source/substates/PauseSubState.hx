package substates;

import flixel.addons.transition.FlxTransitionableState;
import flixel.util.FlxStringUtil;

import options.OptionsState;

class PauseSubState extends MusicBeatSubstate
{
	var grpMenuShit:FlxTypedGroup<Alphabet>;

	var menuItems:Array<String> = [];
	var menuItemsOG:Array<String> = ['Resume', 'Restart Song', 'Change Difficulty', 'Options', 'Exit to menu'];
	var difficultyChoices = [];
	var curSelected:Int = 0;

	var pauseMusic:FlxSound;
	var practiceText:FlxText;
	var skipTimeText:FlxText;
	var skipTimeTracker:Alphabet;
	var curTime:Float = Math.max(0, Conductor.songPosition);

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	public static var songName:String = null;

	public function new()
	{
		super();
		if(Difficulty.list.length < 2) menuItemsOG.remove('Change Difficulty'); //No need to change difficulty if there is only one!

		if(PlayState.chartingMode)
		{
			menuItemsOG.insert(2, 'Leave Charting Mode');
			
			var num:Int = 0;
			if(!PlayState.instance.startingSong)
			{
				num = 1;
				menuItemsOG.insert(3, 'Skip Time');
			}
			menuItemsOG.insert(3 + num, 'End Song');
			menuItemsOG.insert(4 + num, 'Toggle Practice Mode');
			menuItemsOG.insert(5 + num, 'Toggle Botplay');
		}
		menuItems = menuItemsOG;

		for (i in 0...Difficulty.list.length)
			difficultyChoices.push(Difficulty.getString(i));

		difficultyChoices.push('BACK');

		pauseMusic = new FlxSound();
		if (songName != null)
			pauseMusic.loadEmbedded(Paths.music(songName), true, true);
		else if (songName != 'None')
			pauseMusic.loadEmbedded(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)), true, true);
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length * 0.5)));
		pauseMusic.fadeIn(40, 0, 0.5, function(_) pauseMusic.fadeTween = null);
		FlxG.sound.list.add(pauseMusic);

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0x99000000);
		bg.alpha = 0;
		add(bg);

		var levelInfo:FlxText = new FlxText(20, 15, 0, PlayState.SONG.song, 32);
		levelInfo.setFormat(Paths.font("vcr.ttf"), 32);
		levelInfo.x = FlxG.width - levelInfo.width - 20;
		add(levelInfo);

		var levelDifficulty:FlxText = new FlxText(20, 47, 0, Difficulty.getString().toUpperCase(), 32);
		levelDifficulty.setFormat(Paths.font('vcr.ttf'), 32);
		levelDifficulty.x = FlxG.width - levelDifficulty.width - 20;
		add(levelDifficulty);

		var blueballedTxt:FlxText = new FlxText(20, 79, 0, "Blueballed: " + PlayState.deathCounter, 32);
		blueballedTxt.setFormat(Paths.font('vcr.ttf'), 32);
		blueballedTxt.x = FlxG.width - blueballedTxt.width - 20;
		add(blueballedTxt);

		practiceText = new FlxText(0, 116, 0, "PRACTICE MODE", 32);
		practiceText.setFormat(Paths.font('vcr.ttf'), 32);
		practiceText.x = FlxG.width - practiceText.width - 20;
		practiceText.visible = PlayState.instance.practiceMode;
		add(practiceText);

		var chartingText:FlxText = new FlxText(0, 0, 0, "CHARTING MODE", 32);
		chartingText.setFormat(Paths.font('vcr.ttf'), 32);
		chartingText.setPosition(FlxG.width - chartingText.width - 20, FlxG.height - chartingText.height - 20);
		chartingText.visible = PlayState.chartingMode;
		add(chartingText);

		blueballedTxt.alpha = levelDifficulty.alpha = levelInfo.alpha = 0;

		FlxTween.num(0, 1, 0.4, {ease: FlxEase.quartInOut}, function(a:Float) bg.alpha = a);
		FlxTween.tween(levelInfo, {alpha: 1, y: 20}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(levelDifficulty, {alpha: 1, y: levelDifficulty.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.5});
		FlxTween.tween(blueballedTxt, {alpha: 1, y: blueballedTxt.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.7});

		grpMenuShit = new FlxTypedGroup<Alphabet>();
		add(grpMenuShit);

		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0x99000000);
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.visible = false;
		add(missingText);

		regenMenu();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	var holdTime:Float = 0;
	var cantUnpause:Float = 0.1;
	override function update(elapsed:Float)
	{
		cantUnpause -= elapsed;
		//if (pauseMusic.volume < 0.5) pauseMusic.volume += 0.01 * elapsed;

		super.update(elapsed);
		updateSkipTextStuff();

		if (controls.UI_UP_P)	changeSelection(-1);
		if (controls.UI_DOWN_P)	changeSelection(1);

		var daSelected:String = menuItems[curSelected];
		switch (daSelected)
		{
			case 'Skip Time':
				if (controls.UI_LEFT_P)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					curTime -= 1000;
					holdTime = 0;
				}
				if (controls.UI_RIGHT_P)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					curTime += 1000;
					holdTime = 0;
				}

				if(controls.UI_LEFT || controls.UI_RIGHT)
				{
					holdTime += elapsed;
					if(holdTime > 0.5) curTime += 45000 * elapsed * (controls.UI_LEFT ? -1 : 1);

					if (curTime >= FlxG.sound.music.length) curTime -= FlxG.sound.music.length;
					else if (curTime < 0) curTime += FlxG.sound.music.length;
					updateSkipTimeText();
				}
		}

		if (controls.ACCEPT && (cantUnpause <= 0 || !controls.controllerMode))
		{
			if (menuItems == difficultyChoices)
			{
				try {
					if (menuItems.length - 1 != curSelected && difficultyChoices.contains(daSelected)) {
						var name:String = PlayState.SONG.song;
						PlayState.SONG = backend.Song.loadFromJson(backend.Highscore.formatSong(name, curSelected), name);
						PlayState.storyDifficulty = curSelected;
						MusicBeatState.resetState();
						FlxG.sound.music.volume = 0;
						PlayState.changedDifficulty = true;
						PlayState.chartingMode = false;
						return;
					}					
				} catch(e:Dynamic) {
					trace('ERROR! $e');

					var errorStr:String = e.toString();
					if(errorStr.startsWith('[file_contents,assets/data/')) errorStr = 'Missing file: ' + errorStr.substring(27, errorStr.length-1); //Missing chart
					missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
					missingText.screenCenter(Y);
					missingText.visible = true;
					missingTextBG.visible = true;
					FlxG.sound.play(Paths.sound('cancelMenu'));

					super.update(elapsed);
					return;
				}

				menuItems = menuItemsOG;
				regenMenu();
			}

			switch (daSelected)
			{
				case "Resume":
					exitPause();

				case 'Change Difficulty':
					menuItems = difficultyChoices;
					deleteSkipTimeText();
					regenMenu();

				case 'Toggle Practice Mode':
					PlayState.instance.practiceMode = !PlayState.instance.practiceMode;
					PlayState.changedDifficulty = true;
					practiceText.visible = PlayState.instance.practiceMode;

				case "Restart Song":
					restartSong();

				case "Leave Charting Mode":
					restartSong();
					PlayState.chartingMode = false;

				case 'Skip Time':
					if(curTime < Conductor.songPosition)
					{
						PlayState.startOnTime = curTime;
						restartSong(true);
					}
					else
					{
						if (curTime != Conductor.songPosition)
						{
							PlayState.instance.clearNotesBefore(curTime);
							PlayState.instance.setSongTime(curTime);
						}
						exitPause();
					}

				case 'End Song':
					CustomFadeTransition.nextCamera = FlxG.camera;
					exitPause();
					PlayState.instance.notes.clear();
					PlayState.instance.unspawnNotes = [];
					PlayState.instance.finishSong(true);

				case 'Toggle Botplay':
					PlayState.instance.cpuControlled = !PlayState.instance.cpuControlled;
				case 'Options':
					PlayState.instance.paused = true; // For lua
					PlayState.instance.vocals.volume = 0;
					MusicBeatState.switchState(new OptionsState());
					if(ClientPrefs.data.pauseMusic != 'None')
					{
						@:privateAccess
						FlxG.sound.playMusic(pauseMusic._sound, pauseMusic.volume);
						FlxG.sound.music.fadeIn(0.8, pauseMusic.volume, 1);
						FlxG.sound.music.time = pauseMusic.time;
						if(pauseMusic.fadeTween != null) pauseMusic.fadeTween.cancel();
						pauseMusic.stop();
					}
					OptionsState.onPlayState = true;

				case "Exit to menu":
					if(pauseMusic.fadeTween != null) pauseMusic.fadeTween.cancel();
					pauseMusic.stop();
					#if desktop DiscordClient.resetClientID(); #end
					PlayState.seenCutscene = false;
					PlayState.deathCounter = 0;

					Mods.loadTopMod();
					MusicBeatState.switchState(PlayState.isStoryMode ? new states.StoryMenuState() : new states.FreeplayState());
					PlayState.cancelMusicFadeTween();
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
					FlxG.camera.pixelPerfectRender = false;
					PlayState.changedDifficulty = false;
					PlayState.chartingMode = false;
					FlxG.camera.followLerp = 0;
			}
		}
	}

	public var closing:Bool = false;
	dynamic public function exitPause():Void
	{
		if (!closing) // doesn't need to close the thing twice
		{
			forEachOfType(FlxSprite, function(obj:FlxSprite)
				FlxTween.tween(obj, {alpha: 0}, 0.1, {ease: FlxEase.quartInOut}), true);
			if(pauseMusic.fadeTween != null) pauseMusic.fadeTween.cancel();
			pauseMusic.fadeOut(0.1, 0, function(_) close());
			closing = true;
		}
	}

	function deleteSkipTimeText()
	{
		if(skipTimeText != null)
		{
			skipTimeText.kill();
			remove(skipTimeText);
			skipTimeText.destroy();
		}
		skipTimeText = null;
		skipTimeTracker = null;
	}

	public static function restartSong(noTrans:Bool = false)
	{
		PlayState.instance.paused = true; // For lua
		FlxG.sound.music.volume = 0;
		PlayState.instance.vocals.volume = 0;

		if(noTrans)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}
		MusicBeatState.resetState();
	}

	override function destroy()
	{
		pauseMusic.destroy();
		super.destroy();
	}

	function changeSelection(change:Int = 0):Void
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected = FlxMath.wrap(curSelected + change, 0, menuItems.length-1);

		var bullShit:Int = 0;
		for (item in grpMenuShit.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
				if(item == skipTimeTracker)
				{
					curTime = Math.max(0, Conductor.songPosition);
					updateSkipTimeText();
				}
			}
		}
		missingText.visible = false;
		missingTextBG.visible = false;
	}

	function regenMenu():Void {
		for (i in 0...grpMenuShit.members.length) {
			var obj = grpMenuShit.members[0];
			obj.kill();
			grpMenuShit.remove(obj, true);
			obj.destroy();
		}

		for (i in 0...menuItems.length) {
			var item = new Alphabet(90, 320, menuItems[i], true);
			item.isMenuItem = true;
			item.targetY = i;
			grpMenuShit.add(item);

			if(menuItems[i] == 'Skip Time')
			{
				skipTimeText = new FlxText(0, 0, 0, '', 64);
				skipTimeText.setFormat(Paths.font("vcr.ttf"), 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				//skipTimeText.scrollFactor.set();
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
	
	function updateSkipTextStuff()
	{
		if(skipTimeText == null || skipTimeTracker == null) return;

		skipTimeText.x = skipTimeTracker.x + skipTimeTracker.width + 60;
		skipTimeText.y = skipTimeTracker.y;
		skipTimeText.visible = (skipTimeTracker.alpha >= 1);
	}

	function updateSkipTimeText()
		skipTimeText.text = '${FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false)} / ${FlxStringUtil.formatTime(Math.max(0, Math.floor(FlxG.sound.music.length / 1000)), false)}';
}
