package states;

import sys.io.File;
import sys.FileSystem;
import haxe.Json;
import lime.utils.Assets;
import openfl.display.BitmapData;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.FlxGraphic;
import flixel.util.typeLimit.NextState;

import backend.Song;
import backend.StageData;
import objects.Character;

import sys.thread.Thread;
import sys.thread.Mutex;

class LoadingState extends MusicBeatState
{
	public static var loaded:Int = 0;
	public static var loadMax:Int = 0;

	static var requestedBitmaps:Map<String, BitmapData> = [];
	static var mutex:Mutex = new Mutex();

	function new(target:NextState, stopMusic:Bool)
	{
		this.target = target;
		this.stopMusic = stopMusic;
		startThreads();
		
		super();
	}

	inline static public function loadAndSwitchState(target:NextState, stopMusic = false, intrusive = true)
	{
		MusicBeatState.switchState(getNextState(target, stopMusic, intrusive));
	}
	
	var target:NextState;
	var stopMusic:Bool = false;

	var bar:FlxSprite;
	var barWidth:Int = 0;
	var intendedPercent:Float = 0;
	var curPercent:Float = 0;
	var canChangeState:Bool = true;

	override function create()
	{
		if (checkLoaded())
		{
			active = false;
			super.create();
			onLoad();
			return;
		}

		final bg = new FlxSprite(Paths.image("funkay"));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		bar = new FlxSprite(bg.x + 5, FlxG.height - 25).makeGraphic(1, 1, 0xff808080);
		bar.scale.set(0, 15);
		bar.updateHitbox();
		add(bar);
		barWidth = Std.int(bg.width - 10);

		persistentUpdate = true;
		super.create();
	}

	var transitioning:Bool = false;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!transitioning)
		{
			if (canChangeState && !finishedLoading && checkLoaded())
			{
				transitioning = true;
				onLoad();
				return;
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
	
	var finishedLoading:Bool = false;
	function onLoad()
	{
		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		imagesToPrepare = [];
		soundsToPrepare = [];
		musicToPrepare = [];
		songsToPrepare = [];

		FlxG.camera.visible = false;
		FlxTransitionableState.skipNextTransIn = true;
		MusicBeatState.switchState(target);
		transitioning = true;
		finishedLoading = true;
	}

	static function checkLoaded():Bool
	{
		for (key => bitmap in requestedBitmaps)
		{
			if (bitmap != null && Paths.cacheBitmap(key, bitmap) != null)
				trace('finished preloading image $key');
			else
				trace('failed to cache image $key');
		}
		requestedBitmaps.clear();
		return (loaded == loadMax);
	}

	static function getNextState(target:NextState, stopMusic = false, intrusive:Bool = true):NextState
	{
		var directory:String = 'default';
		var weekDir:String = StageData.forceNextDirectory;
		StageData.forceNextDirectory = null;

		if (weekDir != null && weekDir.length > 0 && weekDir != '') directory = weekDir;

		Paths.currentLevel = directory;
		trace('Setting asset folder to $directory');

		var doPrecache:Bool = false;
		clearInvalids();
		if (intrusive)
		{
			if (imagesToPrepare.length > 0 || soundsToPrepare.length > 0 || musicToPrepare.length > 0 || songsToPrepare.length > 0)
				return LoadingState.new.bind(target, stopMusic);
		}
		else
			doPrecache = true;

		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();
		
		if (doPrecache)
		{
			startThreads();
			while (true)
			{
				if (checkLoaded())
				{
					imagesToPrepare = [];
					soundsToPrepare = [];
					musicToPrepare = [];
					songsToPrepare = [];
					break;
				}
				else
					Sys.sleep(.01);
			}
		}
		return target;
	}

	static var imagesToPrepare:Array<String> = [];
	static var soundsToPrepare:Array<String> = [];
	static var musicToPrepare:Array<String> = [];
	static var songsToPrepare:Array<String> = [];
	public static function prepare(images:Array<String> = null, sounds:Array<String> = null, music:Array<String> = null)
	{
		if (images != null) imagesToPrepare = imagesToPrepare.concat(images);
		if (sounds != null) soundsToPrepare = soundsToPrepare.concat(sounds);
		if (music != null) musicToPrepare = musicToPrepare.concat(music);
	}

	static var dontPreloadDefaultVoices:Bool = false;
	public static function prepareToSong()
	{
		var song:SwagSong = PlayState.SONG;
		var folder:String = Paths.formatToSongPath(song.song);
		try
		{
			var path:String = Paths.json('$folder/preload');
			var json:Dynamic = null;

			#if MODS_ALLOWED
			var moddyFile:String = Paths.modsJson('$folder/preload');
			json =	if (FileSystem.exists(moddyFile))
						Json.parse(File.getContent(moddyFile));
					else
						Json.parse(File.getContent(path));
			#else
			json = Json.parse(Assets.getText(path));
			#end

			// if (json != null)
			//	prepare((!ClientPrefs.data.lowQuality || json.images_low) ? json.images : json.images_low, json.sounds, json.music);
		}
		catch(e:Dynamic) {}

		if (song.stage == null || song.stage.length < 1)
			song.stage = StageData.vanillaSongStage(folder);

		var stageData:StageFile = StageData.getStageFile(song.stage);
		// if (stageData != null && stageData.preload != null)
		//	prepare((!ClientPrefs.data.lowQuality || stageData.preload.images_low) ? stageData.preload.images : stageData.preload.images_low, stageData.preload.sounds, stageData.preload.music);

		songsToPrepare.push('$folder/Inst');

		var player1:String = song.player1;
		var player2:String = song.player2;
		var gfVersion:String = song.gfVersion;
		var needsVoices:Bool = song.needsVoices;
		var prefixVocals:String = needsVoices ? '$folder/Voices' : null;
		if (gfVersion == null) gfVersion = 'gf';

		dontPreloadDefaultVoices = false;
		preloadCharacter(player1, prefixVocals);
		if (player2 != player1) preloadCharacter(player2, prefixVocals);
		if (!stageData.hide_girlfriend && gfVersion != player2 && gfVersion != player1)
			preloadCharacter(gfVersion);
		
		if (!dontPreloadDefaultVoices && needsVoices) songsToPrepare.push(prefixVocals);
	}

	public static function clearInvalids()
	{
		clearInvalidFrom(imagesToPrepare, 'images', '.png', IMAGE);
		clearInvalidFrom(soundsToPrepare, 'sounds', '.${Paths.SOUND_EXT}', SOUND);
		clearInvalidFrom(musicToPrepare, 'music',' .${Paths.SOUND_EXT}', SOUND);
		clearInvalidFrom(songsToPrepare, 'songs', '.${Paths.SOUND_EXT}', SOUND, 'songs');

		for (arr in [imagesToPrepare, soundsToPrepare, musicToPrepare, songsToPrepare])
			while (arr.contains(null))
				arr.remove(null);
	}

	static function clearInvalidFrom(arr:Array<String>, prefix:String, ext:String, type:AssetType, ?library:String = null)
	{
		for (i in 0...arr.length)
		{
			var folder:String = arr[i];
			if(folder.trim().endsWith('/'))
			{
				for (subfolder in Mods.directoriesWithFile(Paths.getSharedPath(), '$prefix/$folder'))
					for (file in FileSystem.readDirectory(subfolder))
						if(file.endsWith(ext))
							arr.push(folder + file.substr(0, file.length - ext.length));

				//trace('Folder detected! ' + folder);
			}
		}

		var i:Int = 0;
		while(i < arr.length)
		{
			var member:String = arr[i];
			var myKey = '$prefix/$member$ext';
			if(library == 'songs') myKey = '$member$ext';

			//trace('attempting on $prefix: $myKey');
			var doTrace:Bool = false;
			if(member.endsWith('/') || (!Paths.fileExists(myKey, type, false, library) && (doTrace = true)))
			{
				arr.remove(member);
				if(doTrace) trace('Removed invalid $prefix: $member');
			}
			else i++;
		}
	}

	public static function startThreads()
	{
		loadMax = imagesToPrepare.length + soundsToPrepare.length + musicToPrepare.length + songsToPrepare.length;
		loaded = 0;

		//then start threads
		for (sound in soundsToPrepare) initThread(() -> Paths.sound(sound), 'sound $sound');
		for (music in musicToPrepare) initThread(() -> Paths.music(music), 'music $music');
		for (song in songsToPrepare) initThread(() -> Paths.returnSound(null, song, 'songs'), 'song $song');

		// for images, they get to have their own thread
		for (image in imagesToPrepare)
			Thread.create(() -> {
				mutex.acquire();
				try {
					var bitmap:BitmapData;
					var file:String = null;

					#if MODS_ALLOWED
					file = Paths.modsImages(image);
					if (Paths.currentTrackedAssets.exists(file)) {
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
						if (Paths.currentTrackedAssets.exists(file)) {
							mutex.release();
							loaded++;
							return;
						}
						else if (OpenFlAssets.exists(file, IMAGE))
							bitmap = OpenFlAssets.getBitmapData(file);
						else {
							trace('no such image $image exists');
							mutex.release();
							loaded++;
							return;
						}
					}
					mutex.release();

					if (bitmap != null) requestedBitmaps.set(file, bitmap);
					else trace('oh no the image is null NOOOO ($image)');
				}
				catch(e:Dynamic) {
					mutex.release();
					trace('ERROR! fail on preloading image $image');
				}
				loaded++;
			});
	}

	static function initThread(func:Void->Dynamic, traceData:String)
	{
		Thread.create(() -> {
			mutex.acquire();
			try {
				var ret:Dynamic = func();
				mutex.release();

				if (ret != null) trace('finished preloading $traceData');
				else trace('ERROR! fail on preloading $traceData');
			}
			catch(e:Dynamic) {
				mutex.release();
				trace('ERROR! fail on preloading $traceData');
			}
			loaded++;
		});
	}

	inline private static function preloadCharacter(char:String, ?prefixVocals:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT, null, true);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			
			imagesToPrepare.push(character.image);
			if (prefixVocals != null)
			{
				// songsToPrepare.push(prefixVocals + "-Opponent");
				// songsToPrepare.push(prefixVocals + "-Player");
				songsToPrepare.push(prefixVocals);
				if(char == PlayState.SONG.player1) dontPreloadDefaultVoices = true;
			}
		}
		catch(e:Dynamic) {}
	}
}