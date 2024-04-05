package states;

import openfl.utils.Assets as OpenFlAssets;
import openfl.display.BitmapData;
import openfl.utils.AssetType;
import lime.utils.Assets;

import flixel.addons.transition.FlxTransitionableState;
import flixel.util.typeLimit.NextState;
import flixel.graphics.FlxGraphic;
import flixel.FlxState;

import backend.Song;
import backend.StageData;
import objects.Character;

import sys.thread.Thread;
import sys.thread.Mutex;
import sys.FileSystem;
import sys.io.File;
import haxe.Json;

using flixel.util.FlxArrayUtil;

class LoadingState extends FlxState
{
	public static var loaded = 0;
	public static var loadMax = 0;

	static var dontPreloadDefaultVoices = false;
	static var __preloadSong = false;

	static final requestedBitmaps = new Map<String, BitmapData>();
	static final imagesToPrepare = new Array<String>();
	static final soundsToPrepare = new Array<String>();
	static final musicToPrepare = new Array<String>();
	static final songsToPrepare = new Array<String>();

	static final mutex = new Mutex();

	static var __preloadPending = false;

	@:allow(Main)
	static function preloadState(state:FlxState)
	{
		if (!__preloadPending)
			return;

		state.alive = state.exists = false; // bypass killMembers()
		startThreads();
		prepareToSong();
		__preloadSong = false;
		while (true)
		{
			if (checkLoaded())
				break;

			// wait 0.01 sec until next loop...
			Sys.sleep(.01);
		}
		imagesToPrepare.clearArray();
		soundsToPrepare.clearArray();
		musicToPrepare.clearArray();
		songsToPrepare.clearArray();
		state.alive = state.exists = true;
		__preloadPending = false;
	}

	inline static public function loadAndSwitchState(target:NextState, stopMusic = false, intrusive = false)
	{
		MusicBeatState.switchState(getNextState(target, stopMusic, intrusive));
	}

	static function checkLoaded():Bool
	{
		for (key => bitmap in requestedBitmaps)
			trace(((bitmap == null || Paths.cacheBitmap(key, bitmap) == null) ? "failed to cache" : "finished preloading") + ' image $key');

		requestedBitmaps.clear();
		return (loaded == loadMax);
	}

	static function getNextState(target:NextState, stopMusic:Bool, intrusive:Bool):NextState
	{
		var directory = "default";
		if (StageData.forceNextDirectory != null && StageData.forceNextDirectory.length != 0)
			directory = StageData.forceNextDirectory;

		StageData.forceNextDirectory = null;
		Paths.currentLevel = directory;
		trace('Setting asset folder to $directory');

		clearInvalids();
		if (intrusive)
		{
			if (imagesToPrepare.length != 0 || soundsToPrepare.length != 0 || musicToPrepare.length != 0 || songsToPrepare.length != 0)
				return LoadingState.new.bind(target, stopMusic);
		}
		else // preload before state creation
			__preloadPending = true;

		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		return target;
	}

	public static function prepare(?images:Array<String>, ?sounds:Array<String>, ?music:Array<String>)
	{
		inline function addItems(from:Array<String>, to:Array<String>)
		{
			if (from != null)
				for (item in from)
					to.push(item);
		}
		addItems(images, imagesToPrepare);
		addItems(sounds, soundsToPrepare);
		addItems(music, musicToPrepare);
		/*if (images != null)
			imagesToPrepare = imagesToPrepare.concat(images);
		if (sounds != null)
			soundsToPrepare = soundsToPrepare.concat(sounds);
		if (music != null)
			musicToPrepare = musicToPrepare.concat(music);*/
	}

	public static function prepareToSong()
	{
		if (!__preloadSong)
		{
			__preloadSong = true;
			return;
		}
		__preloadSong = false;
		final folder = Paths.formatToSongPath(PlayState.SONG.song);
		/*try
		{
			var json:Dynamic;
			var path = Paths.json('$folder/preload');
			#if MODS_ALLOWED
			var moddyFile:String = Paths.modsJson('$folder/preload');
			json =	if (FileSystem.exists(moddyFile))
						Json.parse(File.getContent(moddyFile));
					else
						Json.parse(File.getContent(path));
			#else
			json = Json.parse(Assets.getText(path));
			#end

			if (json != null)
				prepare((!ClientPrefs.data.lowQuality || json.images_low) ? json.images : json.images_low, json.sounds, json.music);
		}
		catch(e)
		{
			trace(e);
		}*/

		if (PlayState.SONG.stage == null || PlayState.SONG.stage.length == 0)
			PlayState.SONG.stage = StageData.vanillaSongStage(folder);

		final stageData = StageData.getStageFile(PlayState.SONG.stage);
		// if (stageData != null && stageData.preload != null)
		//	prepare((!ClientPrefs.data.lowQuality || stageData.preload.images_low) ? stageData.preload.images : stageData.preload.images_low, stageData.preload.sounds, stageData.preload.music);

		pushSong('$folder/Inst');
		final prefixVocals = PlayState.SONG.needsVoices ? '$folder/Voices' : null;
		if (PlayState.SONG.gfVersion == null)
			PlayState.SONG.gfVersion = "gf";

		dontPreloadDefaultVoices = false;
		preloadCharacter(PlayState.SONG.player1, prefixVocals);
		if (PlayState.SONG.player2 != PlayState.SONG.player1)
			preloadCharacter(PlayState.SONG.player2, prefixVocals);
		if (!stageData.hide_girlfriend && PlayState.SONG.gfVersion != PlayState.SONG.player2 && PlayState.SONG.gfVersion != PlayState.SONG.player1)
			preloadCharacter(PlayState.SONG.gfVersion);
		
		if (!dontPreloadDefaultVoices && PlayState.SONG.needsVoices)
			pushSong(prefixVocals);
	}

	inline static function pushSong(song:String)
	{
		if (!songsToPrepare.contains(song))
			songsToPrepare.push(song);
	}

	public static function clearInvalids()
	{
		final SOUND_EXT = "." + Paths.SOUND_EXT;
		clearInvalidFrom(imagesToPrepare, "images", ".png", IMAGE);
		clearInvalidFrom(soundsToPrepare, "sounds", SOUND_EXT, SOUND);
		clearInvalidFrom(musicToPrepare, "music", SOUND_EXT, SOUND);
		clearInvalidFrom(songsToPrepare, "songs", SOUND_EXT, SOUND, "songs");

		inline function nullCheck(arr:Array<String>)
		{
			while (arr.contains(null))
				arr.remove(null);
		}

		nullCheck(imagesToPrepare);
		nullCheck(soundsToPrepare);
		nullCheck(musicToPrepare);
		nullCheck(songsToPrepare);
		/*for (arr in [imagesToPrepare, soundsToPrepare, musicToPrepare, songsToPrepare])
			while (arr.contains(null))
				arr.remove(null);*/
	}

	static function clearInvalidFrom(arr:Array<String>, prefix:String, ext:String, type:AssetType, ?library:String)
	{
		for (folder in arr)
			if (folder.trim().endsWith("/"))
			{
				for (subfolder in Mods.directoriesWithFile(Paths.getSharedPath(), '$prefix/$folder'))
					for (file in FileSystem.readDirectory(subfolder))
						if (file.endsWith(ext))
							arr.push(folder + file.substr(0, file.length - ext.length));

				// trace('Folder detected! $folder');
			}

		var i = 0;
		final isSongsLibrary = library == "songs";
		while (i < arr.length)
		{
			final member = arr[i];
			final myKey = isSongsLibrary ? '$member$ext' : '$prefix/$member$ext';
			// trace('attempting on $prefix: $myKey');
			var doTrace = false;
			if (member.endsWith("/") || (!Paths.fileExists(myKey, type, false, library) && (doTrace = true)))
			{
				arr.remove(member);
				if (doTrace)
					trace('Removed invalid $prefix: $member');
			}
			else
				i++;
		}
	}

	public static function startThreads()
	{
		loadMax = imagesToPrepare.length + soundsToPrepare.length + musicToPrepare.length + songsToPrepare.length;
		loaded = 0;

		//then start threads
		for (sound in soundsToPrepare)
			initThread(() -> Paths.sound(sound), 'sound $sound');
		for (music in musicToPrepare)
			initThread(() -> Paths.music(music), 'music $music');
		for (song in songsToPrepare)
			initThread(() -> Paths.returnSound("songs", song), 'song $song');

		// for images, they get to have their own thread
		for (image in imagesToPrepare)
			Thread.create(() ->
			{
				mutex.acquire();
				try
				{
					var file:String;
					var bitmap:BitmapData = null;
					#if MODS_ALLOWED
					file = Paths.modsImages(image);
					if (Paths.hasGraphic(file))
					{
						mutex.release();
						loaded++;
						return;
					}
					else if (FileSystem.exists(file))
						bitmap = BitmapData.fromFile(file);
					else
					#end
					{
						file = Paths.getPath('images/$image.png', IMAGE);
						if (Paths.hasGraphic(file))
						{
							mutex.release();
							loaded++;
							return;
						}
						else if (OpenFlAssets.exists(file, IMAGE))
							bitmap = OpenFlAssets.getBitmapData(file);
						else
						{
							trace('no such image $image exists');
							mutex.release();
							loaded++;
							return;
						}
					}
					mutex.release();

					if (bitmap == null)
						trace('oh no the image is null NOOOO ($image)');
					else
						requestedBitmaps.set(file, bitmap);
				}
				catch(e)
				{
					mutex.release();
					trace('ERROR! fail on preloading image $image\n$e');
				}
				loaded++;
			});
	}

	inline static function initThread(func:Void->Dynamic, traceData:String)
	{
		Thread.create(() ->
		{
			mutex.acquire();
			try
			{
				var ret:Dynamic = func();
				mutex.release();
				trace((ret == null ? "ERROR! fail on" : "finished") + ' preloading $traceData');
			}
			catch(e)
			{
				mutex.release();
				trace('ERROR! fail on preloading $traceData\n$e');
			}
			loaded++;
		});
	}

	inline static function preloadCharacter(char:String, ?prefixVocals:String)
	{
		try
		{
			// also caches jsons
			var character:CharacterFile = Character.resolveCharacterData(char);
			/*var path:String = Paths.getPath('characters/$char.json', TEXT, null, true);
			#if MODS_ALLOWED
			character = cast Json.parse(File.getContent(path));
			#else
			character = cast Json.parse(Assets.getText(path));
			#end*/
			
			imagesToPrepare.push(character.image);
			if (prefixVocals != null)
			{
				// pushSong(prefixVocals + "-Opponent");
				// pushSong(prefixVocals + "-Player");
				pushSong(prefixVocals);
				if (char == PlayState.SONG.player1)
					dontPreloadDefaultVoices = true;
			}
		}
		catch(e)
		{
			trace(e);
		}
	}
	
	var target:NextState;
	var stopMusic:Bool = false;

	var bar:FlxSprite;
	var barWidth:Float = 0;
	var intendedPercent:Float = 0;
	var curPercent:Float = 0;
	// var canChangeState:Bool = true;

	var transitioning:Bool = false;
	var finishedLoading:Bool = false;

	function new(target:NextState, stopMusic:Bool)
	{
		this.target = target;
		this.stopMusic = stopMusic;
		startThreads();
		prepareToSong();
		__preloadSong = false;
		super();
	}

	override function create()
	{
		if (checkLoaded())
		{
			onLoad();
			return;
		}

		final bg = new FlxSprite(Paths.image(FlxG.random.getObject(AchievementsMenuState.randomShit))); // "funkay"
		bg.scaleBySize().updateHitbox();
		// bg.setGraphicSize(FlxG.width, FlxG.height);
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.alpha = 0.5;
		add(bg.screenCenter());

		bar = new FlxSprite(bg.x + 5, FlxG.height - 25).makeGraphic(1, 1, 0xff808080);
		bar.scale.set(0, 15);
		bar.updateHitbox();
		add(bar);
		barWidth = bg.width - 10;

		final text = new FlxText(bar.x, bar.y - 25, "Loading...", 18);
		add(text.setBorderStyle(OUTLINE, FlxColor.BLACK));

		persistentUpdate = true;
		FlxTransitionableState.skipNextTransOut = FlxTransitionableState.skipNextTransIn = true;
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!transitioning)
		{
			if (/*canChangeState && */!finishedLoading && checkLoaded())
			{
				transitioning = true;
				onLoad();
				// return;
			}
			intendedPercent = loaded / loadMax;
		}

		if (curPercent != intendedPercent)
		{
			curPercent = if (Math.abs(curPercent - intendedPercent) < 0.001)
							intendedPercent;
						 else
							FlxMath.lerp(intendedPercent, curPercent, Math.exp(-elapsed * 15));

			bar.scale.x = barWidth * curPercent;
			bar.updateHitbox();
		}
	}

	inline function onLoad()
	{
		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		imagesToPrepare.clearArray();
		soundsToPrepare.clearArray();
		musicToPrepare.clearArray();
		songsToPrepare.clearArray();

		// FlxG.camera.visible = false;
		MusicBeatState.switchState(target);
		transitioning = true;
		finishedLoading = true;
	}
}