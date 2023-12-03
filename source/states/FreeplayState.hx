package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import objects.HealthIcon;

import substates.GameplayChangersSubstate;
import substates.ResetScoreSubState;

class FreeplayState extends MusicBeatState
{
	final songs:Array<SongMetadata> = [];

	var selector:FlxText;
	private static var curSelected:Int = 0;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private final iconArray:Array<HealthIcon> = [];

	var bg:FlxSprite;
	var intendedColor:Int;
	var colorTween:FlxTween;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	override function create()
	{
		//Paths.clearStoredMemory();
		//Paths.clearUnusedMemory();
		
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		for (i in 0...WeekData.weeksList.length)
		{
			if (weekIsLocked(WeekData.weeksList[i])) continue;

			final leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			final leSongs:Array<String> = [];
			final leChars:Array<String> = [];

			for (song in leWeek.songs)
			{
				leSongs.push(song[0]);
				leChars.push(song[1]);
			}

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				final colrs:Array<Int> = cast song[2];
				final colors:Array<Int> = colrs == null || colrs.length < 3 ? [146, 113, 253] : colrs;
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
		Mods.loadTopMod();

		bg = new FlxSprite(0, 0, Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.active = false;
		add(bg);
		bg.screenCenter();

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			final songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.targetY = i;
			grpSongs.add(songText);

			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.snapToPosition();

			Mods.currentModDirectory = songs[i].folder;
			final icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;

			// too laggy with a lot of songs, so i had to recode the logic for it
			songText.visible = songText.active = songText.isMenuItem = false;
			icon.visible = icon.active = false;

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			add(icon);

			// songText.x += 40;
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
			// songText.screenCenter(X);
		}
		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		scoreText.active = false;

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0x99000000);
		scoreBG.active = false;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		diffText.active = false;
		add(diffText);

		add(scoreText);

		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0x99000000);
		missingTextBG.visible = missingTextBG.active = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = missingText.active = false;
		add(missingText);

		if(curSelected >= songs.length) curSelected = 0;
		bg.color = songs[curSelected].color;
		intendedColor = bg.color;
		lerpSelected = curSelected;

		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));
		changeSelection();

		final penis = FlxG.height - 26;
		final txtBG = new FlxSprite(0, penis).makeGraphic(FlxG.width, 26, 0x99000000);
		txtBG.active = false;
		add(txtBG);

		#if PRELOAD_ALL
		final leText:String = "Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.";
		final size:Int = 16;
		#else
		final leText:String = "Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.";
		final size:Int = 18;
		#end
		final text:FlxText = new FlxText(0, penis + 4, FlxG.width, leText, size);
		text.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, RIGHT);
		text.scrollFactor.set();
		text.active = false;
		add(text);

		FlxG.sound.list.add(vocals);
		updateTexts();
		super.create();
	}

	override function closeSubState()
	{
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));

	function weekIsLocked(name:String):Bool
	{
		final leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	/*public function addWeek(songs:Array<String>, weekNum:Int, weekColor:Int, ?songCharacters:Array<String>)
	{
		if (songCharacters == null)
			songCharacters = ['bf'];

		var num:Int = 0;
		for (song in songs)
		{
			addSong(song, weekNum, songCharacters[num]);
			this.songs[this.songs.length-1].color = weekColor;

			if (songCharacters.length != 1)
				num++;
		}
	}*/

	var instPlaying:Int = -1;
	public static var vocals:FlxSound = new FlxSound();
	var holdTime:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.7) 
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;

		Conductor.songPosition = FlxG.sound.music.time;
		
		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, FlxMath.bound(elapsed * 24, 0, 1)));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, FlxMath.bound(elapsed * 12, 0, 1));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		final ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
		if(ratingSplit.length < 2) //No decimals, add an empty space
			ratingSplit.push('');
		
		while(ratingSplit[1].length < 2) //Less than 2 decimals in it, add decimals then
			ratingSplit[1] += '0';

		scoreText.text = 'PERSONAL BEST: ' + lerpScore + ' (' + ratingSplit.join('.') + '%)';
		positionHighscore();

		final shiftMult:Int = FlxG.keys.pressed.SHIFT ? 3 : 1;
		if(songs.length > 1)
		{
			if (FlxG.keys.justPressed.HOME || FlxG.keys.justPressed.END || controls.UI_UP_P || controls.UI_DOWN_P)
			{ 
				if (FlxG.keys.justPressed.HOME)		 curSelected = 0;
				else if (FlxG.keys.justPressed.END)	 curSelected = songs.length - 1;
				changeSelection(controls.UI_UP_P ? -shiftMult : controls.UI_DOWN_P ? shiftMult : 0);
				holdTime = 0;	
			}

			if(controls.UI_DOWN || controls.UI_UP)
			{
				final checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
				holdTime += elapsed;
				final checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

				if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
					changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
			}

			if(FlxG.mouse.wheel != 0)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
				changeSelection(-shiftMult * FlxG.mouse.wheel, false);
			}
		}

		if (controls.UI_LEFT_P)
		{
			changeDiff(-1);
			_updateSongLastDifficulty();
		}
		else if (controls.UI_RIGHT_P)
		{
			changeDiff(1);
			_updateSongLastDifficulty();
		}

		if (controls.BACK)
		{
			persistentUpdate = false;
			if(colorTween != null) colorTween.cancel();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
		}

		if(FlxG.keys.justPressed.CONTROL)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if (FlxG.keys.justPressed.SPACE)
		{
			if (instPlaying != curSelected)
			{
				try
				{
					#if PRELOAD_ALL
					FlxG.sound.music.volume = 0;
					stopVocals();
					Mods.currentModDirectory = songs[curSelected].folder;
					final poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
					PlayState.SONG = Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());

					Conductor.bpm = PlayState.SONG.bpm;
					FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.7);
					if (PlayState.SONG.needsVoices && !FlxG.keys.pressed.SHIFT)
					{
						vocals.loadEmbedded(Paths.voices(PlayState.SONG.song));
						vocals.play();
						vocals.persist = true;
						vocals.looped = true;
						vocals.volume = 0.7;
					}
					instPlaying = curSelected;
					#end
				}
				catch(e)
				{
					exceptionError(e);
					updateTexts(elapsed);
					super.update(elapsed);
					return;
				}
			}
		}

		else if (controls.ACCEPT)
		{
			persistentUpdate = false;
			final songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
			final poop:String = Highscore.formatSong(songLowercase, curDifficulty);
			/*#if MODS_ALLOWED
			if(!sys.FileSystem.exists(Paths.modsJson(songLowercase + '/' + poop)) && !sys.FileSystem.exists(Paths.json(songLowercase + '/' + poop))) {
			#else
			if(!OpenFlAssets.exists(Paths.json(songLowercase + '/' + poop))) {
			#end
				poop = songLowercase;
				curDifficulty = 1;
				trace('Couldnt find file');
			}*/
			trace(poop);

			try
			{
				PlayState.SONG = Song.loadFromJson(poop, songLowercase);
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = curDifficulty;

				trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
				if(colorTween != null) colorTween.cancel();
			}
			catch(e)
			{
				exceptionError(e);
				updateTexts(elapsed);
				super.update(elapsed);
				return;
			}
			LoadingState.loadAndSwitchState(new PlayState());

			FlxG.sound.music.volume = 0;
			stopVocals();
			#if MODS_ALLOWED
			DiscordClient.loadModRPC();
			#end
		}
		else if(controls.RESET)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		updateTexts(elapsed);
		super.update(elapsed);
	}

	override function sectionHit()
	{
		//trace('$curSection SECTION!! [cur bpm: ${Conductor.bpm}]');
		if (vocals.playing && FlxG.sound.music.time - vocals.time > 20 && FlxG.sound.music.time <= vocals.length)
		{
			trace('[song: ${songs[curSelected].songName} | section: $curSection] syncing vocals!! (${FlxG.sound.music.time - vocals.time} MS apart!!)');
			vocals.time = FlxG.sound.music.time;
		}

		super.sectionHit();
	}

	public static function stopVocals()
	{
		vocals.stop();
	}

	function exceptionError(e:haxe.Exception)
	{
		trace('ERROR! $e');
		final errorStr:String = e.message.startsWith('[file_contents,assets/data/') ? 'Missing file: ${e.message.substring(27, e.message.length-1)}' : e.message;
		missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
		missingText.screenCenter(Y);
		missingText.visible = true;
		missingTextBG.visible = true;
		FlxG.sound.play(Paths.sound('cancelMenu'));
	}

	function changeDiff(change:Int = 0)
	{
		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);

		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		lastDifficultyName = Difficulty.getString(curDifficulty);
		diffText.text = (Difficulty.list.length > 1) 
			? '< ${lastDifficultyName.toUpperCase()} >'
			: lastDifficultyName.toUpperCase();

		positionHighscore();
		missingText.visible = false;
		missingTextBG.visible = false;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		_updateSongLastDifficulty();
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		final lastList:Array<String> = Difficulty.list;
		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length-1);
			
		final newColor:Int = songs[curSelected].color;
		if(newColor != intendedColor) {
			if(colorTween != null) colorTween.cancel();
			intendedColor = newColor;
			colorTween = FlxTween.color(bg, 1, bg.color, intendedColor, {
				onComplete: function(twn:FlxTween) colorTween = null
			});
		}

		for (i in 0...iconArray.length)
			iconArray[i].alpha = i == curSelected ? 1 : 0.6;

		for (item in grpSongs.members)
			item.alpha = item.targetY == curSelected ? 1 : 0.6;
		
		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;
		Difficulty.loadFromWeek();
		
		final savedDiff:String = songs[curSelected].lastDifficulty;
		final lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
		if(savedDiff != null && !lastList.contains(savedDiff) && Difficulty.list.contains(savedDiff))
			curDifficulty = Math.round(Math.max(0, Difficulty.list.indexOf(savedDiff)));
		else if(lastDiff > -1)
			curDifficulty = lastDiff;
		else if(Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		changeDiff();
		_updateSongLastDifficulty();
	}

	inline private function _updateSongLastDifficulty()
		songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty);

	private function positionHighscore() {
		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];
	public function updateTexts(elapsed:Float = 0.0)
	{
		lerpSelected = FlxMath.lerp(lerpSelected, curSelected, FlxMath.bound(elapsed * 9.6, 0, 1));
		for (i in _lastVisibles)
		{
			grpSongs.members[i].visible = grpSongs.members[i].active = false;
			iconArray[i].visible = iconArray[i].active = false;
		}
		_lastVisibles = [];

		final min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance)));
		final max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance)));
		for (i in min...max)
		{
			final item:Alphabet = grpSongs.members[i];
			item.visible = item.active = true;
			item.x = ((item.targetY - lerpSelected) * item.distancePerItem.x) + item.startPosition.x;
			item.y = ((item.targetY - lerpSelected) * 1.3 * item.distancePerItem.y) + item.startPosition.y;

			final icon:HealthIcon = iconArray[i];
			icon.visible = icon.active = true;
			_lastVisibles.push(i);
		}
	}
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";
	public var lastDifficulty:String = null;

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if(this.folder == null) this.folder = '';
	}
}