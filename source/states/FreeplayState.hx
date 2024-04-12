package states;

import flixel.FlxSubState;
import backend.WeekData;
import backend.Highscore;
import backend.Song;

import objects.HealthIcon;

import substates.GameplayChangersSubstate;
import substates.ResetScoreSubState;

using flixel.util.FlxArrayUtil;

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
		// Paths.clearStoredMemory();
		// Paths.clearUnusedMemory();

		#if (flixel < "6.0.0")
		FlxG.cameras.reset(new objects.GameCamera());
		#end
		
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if hxdiscord_rpc
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		for (i in 0...WeekData.weeksList.length)
		{
			if (weekIsLocked(WeekData.weeksList[i]))
				continue;

			final leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
				addSong(song.songName, i, song.iconName, song.bgColor);
		}
		Mods.loadTopMod();

		bg = new FlxSprite(0, 0, Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.screenCenter();
		bg.active = false;
		bg.scrollFactor.set();
		add(bg);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		// prevent crash
		if (songs.length == 0)
		{
			Main.warn("WARNING!! No songs loaded, defaulting to \"Test\" to prevent crash!");
			addSong("Test", 0, "dad", 0xFF7C7C7C); // "songs": [["Test", "dad", [124, 124, 124]]]
		}

		for (i in 0...songs.length)
		{
			final songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.targetY = i;
			songText.isMenuItem = true;
			songText.snapToPosition();
			songText.isMenuItem = false; // doesn't need this anymore
			grpSongs.add(songText);

			Mods.currentModDirectory = songs[i].folder;
			final icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			//icon.sprTracker = songText;
			icon.setPosition(songText.x + songText.width + icon.width * 0.15, songText.y - icon.height * 0.25);

			if (curSelected != i)
				songText.alpha = icon.alpha = 0.6;

			// too laggy with a lot of songs, so i had to recode the logic for it
			/*songText.visible = songText.active = songText.isMenuItem = false;
			icon.visible = icon.active = false;*/

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
		scoreText.scrollFactor.set();

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0x99000000);
		scoreBG.active = false;
		scoreBG.scrollFactor.set();

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		diffText.active = false;
		diffText.scrollFactor.set();

		add(scoreBG);
		add(diffText);
		add(scoreText);

		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0x99000000);
		missingTextBG.visible = missingTextBG.active = false;
		missingTextBG.scrollFactor.set();
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.visible = missingText.active = false;
		missingText.scrollFactor.set();
		
		add(missingTextBG);
		add(missingText);

		bg.color = songs[curSelected].color;
		intendedColor = bg.color;
		lerpSelected = curSelected;

		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));
		changeSelection();

		final penis = FlxG.height - 26;
		final txtBG = new FlxSprite(0, penis).makeGraphic(FlxG.width, 26, 0x99000000);
		txtBG.active = false;
		txtBG.scrollFactor.set();

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
		
		add(txtBG);
		add(text);

		if (vocals == null)
		{
			vocals = FlxG.sound.list.recycle(FlxSound);
			vocals.persist = true;
		}
		super.create();
		FlxG.camera.follow(iconArray[curSelected], NO_DEAD_ZONE, 0.16);
		FlxG.camera.snapToTarget();
	}

	override function closeSubState()
	{
		changeSelection(0, false);
		// persistentUpdate = true;
		// FlxG.camera.followLerp = 0.16;
		super.closeSubState();
	}

	/*override function openSubState(SubState:FlxSubState)
	{
		FlxG.camera.followLerp = 0;
		super.openSubState(SubState);
	}*/

	inline public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		// songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
		songs.push({
			songName: songName,
			week: weekNum,
			songCharacter: songCharacter,
			color: color,
			folder: Mods.currentModDirectory ?? ""
		});
	}

	inline function weekIsLocked(name:String):Bool
	{
		final leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	var instPlaying:Int = -1;
	public static var vocals:FlxSound;
	var holdTime:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.7) 
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;

		Conductor.songPosition = FlxG.sound.music.time;
		lerpScore = if (Math.abs(lerpScore - intendedScore) <= 10)
						intendedScore;
					else
						Math.floor(CoolUtil.lerpElapsed(lerpScore, intendedScore, 0.4));

		lerpRating = if (Math.abs(lerpRating - intendedRating) <= 0.01)
						 intendedRating;
					 else
						 CoolUtil.lerpElapsed(lerpRating, intendedRating, 0.2);

		final ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split(".");
		if(ratingSplit.length < 2) // No decimals, add an empty space
			ratingSplit.push("");
		
		while(ratingSplit[1].length < 2) // Less than 2 decimals in it, add decimals then
			ratingSplit[1] += "0";

		scoreText.text = 'PERSONAL BEST: $lerpScore (' + ratingSplit.join(".") + "%)";
		positionHighscore();

		if (subState != null)
			return super.update(elapsed);

		final shiftMult:Int = FlxG.keys.pressed.SHIFT ? 3 : 1;
		if (songs.length > 1)
		{
			if (FlxG.keys.justPressed.HOME || FlxG.keys.justPressed.END || controls.UI_UP_P || controls.UI_DOWN_P)
			{ 
				if (FlxG.keys.justPressed.HOME)		 curSelected = 0;
				else if (FlxG.keys.justPressed.END)	 curSelected = songs.length - 1;
				changeSelection(controls.UI_UP_P ? -shiftMult : controls.UI_DOWN_P ? shiftMult : 0);
				holdTime = 0;	
			}

			if (controls.UI_DOWN || controls.UI_UP)
			{
				final checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
				holdTime += elapsed;
				final checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

				if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
					changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
			}

			if (FlxG.mouse.wheel != 0)
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
			MusicBeatState.switchState(MainMenuState.new);
		}

		if (FlxG.keys.justPressed.CONTROL)
		{
			// persistentUpdate = false;
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
						vocals.looped = true;
						vocals.volume = 0.7;
					}
					instPlaying = curSelected;
					#end
				}
				catch(e)
				{
					exceptionError(e);
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
			trace(poop);

			try
			{
				PlayState.SONG = Song.loadFromJson(poop, songLowercase);
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = curDifficulty;

				trace("CURRENT WEEK: " + WeekData.getWeekFileName());
				if (colorTween != null)
					colorTween.cancel();
				
				LoadingState.prepareToSong();
				LoadingState.loadAndSwitchState(new PlayState());
				MainMenuState.pizzaTime = false;

				FlxG.sound.music.stop();
				stopVocals();
				#if (hxdiscord_rpc && MODS_ALLOWED)
				DiscordClient.loadModRPC();
				#end
			}
			catch(e)
			{
				exceptionError(e);
				return super.update(elapsed);
			}
		}
		else if (controls.RESET)
		{
			// persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		super.update(elapsed);
	}

	override function sectionHit()
	{
		super.sectionHit();
		if (vocals == null)
			return;

		final diff = Math.abs(FlxG.sound.music.time - vocals.time);
		if (vocals.playing && diff > 20 && FlxG.sound.music.time <= vocals.length)
		{
			trace("[song: " + PlayState.SONG.song + ' | section: $curSection] syncing vocals!! ($diff MS apart!!)');
			vocals.time = FlxG.sound.music.time;
		}
	}

	public static function stopVocals()
	{
		if (vocals != null)
			vocals.stop();
	}

	function exceptionError(e:haxe.Exception)
	{
		trace('ERROR! $e');
		final errorStr:String = e.message.startsWith("[file_contents,assets/data/") ? "Missing file: " + e.message.substring(27, e.message.length-1) : e.message;
		missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
		missingText.screenCenter(Y);
		missingText.visible = true;
		missingTextBG.visible = true;
		FlxG.sound.play(Paths.sound("cancelMenu"));
	}

	function changeDiff(change:Int = 0)
	{
		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);

		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		lastDifficultyName = Difficulty.getString(curDifficulty);
		diffText.text = (Difficulty.list.length > 1) ? '< ${lastDifficultyName.toUpperCase()} >' : lastDifficultyName.toUpperCase();

		positionHighscore();
		missingText.visible = false;
		missingTextBG.visible = false;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		_updateSongLastDifficulty();
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		grpSongs.members[curSelected].alpha = iconArray[curSelected].alpha = 0.6;
		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length-1);
			
		final newColor:Int = songs[curSelected].color;
		if (newColor != intendedColor)
		{
			if (colorTween != null)
				colorTween.cancel();
			colorTween = FlxTween.color(bg, 1, bg.color, intendedColor = newColor, {onComplete: (_) -> colorTween = null});
		}

		final daIcon = iconArray[curSelected];
		grpSongs.members[curSelected].alpha = daIcon.alpha = 1;

		// propertly centering camera
		FlxG.camera.targetOffset.x = FlxG.width * 0.5 + curSelected * 20 - (daIcon.x + daIcon.width * 0.5);
		FlxG.camera.target = daIcon;
		
		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;
		Difficulty.loadFromWeek();
		
		final lastList:Array<String> = Difficulty.list;
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
		scoreBG.x = FlxG.width - (scoreBG.scale.x * .5);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width * .5));
		diffText.x -= diffText.width * .5;
	}
}

@:structInit class SongMetadata
{
	public var songName:String;
	public var week:Int;
	public var songCharacter:String;
	public var color:Int;
	public var folder:String;
	public var lastDifficulty:String = "";

	/*public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory ?? "";
	}*/
}