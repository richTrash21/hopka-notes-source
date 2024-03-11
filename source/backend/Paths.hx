package backend;

import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;

import openfl.display.BitmapData;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;

import lime.utils.Assets;
import flash.media.Sound;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

#if MODS_ALLOWED
import backend.Mods;
#end

@:access(flixel.system.frontEnds.BitmapFrontEnd)
class Paths
{
	public static final SOUND_EXT = #if web "mp3" #else "ogg" #end;
	public static final VIDEO_EXT = "mp4";
	public static final SUB_EXT = "srt"; 

	inline public static function excludeAsset(key:String)
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions =
	[
		'assets/music/freakyMenu.$SOUND_EXT',
		'assets/music/breakfast.$SOUND_EXT',
		'assets/music/tea-time.$SOUND_EXT',
	];

	public static final PNG_REGEX = ~/^.+\.png$/i;
	public static final LUA_REGEX = ~/^.+\.lua$/i;
	public static final HX_REGEX  = ~/^.+\.hx$/i;

	// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory()
	{
		// clear non local assets in the tracked assets list
		for (key => obj in currentTrackedAssets)
		{
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				if (obj != null)
				{
					// remove the key from all cache maps
					FlxG.bitmap._cache.remove(key);
					openfl.Assets.cache.removeBitmapData(key);
					currentTrackedAssets.remove(key);

					// and get rid of the object
					obj.persist = false; // make sure the garbage collector actually clears it up
					obj.destroyOnNoUse = true;
					obj.destroy();
				}
			}
		}

		// run the garbage collector for good measure lmfao
		openfl.system.System.gc();
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];
	public static function clearStoredMemory(?cleanUnused:Bool = false)
	{
		// clear anything not in the tracked assets list
		for (key => obj in FlxG.bitmap._cache)
		{
			if (obj != null && !currentTrackedAssets.exists(key))
			{
				openfl.Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				obj.destroy();
			}
		}

		// clear all sounds that are cached
		for (key in currentTrackedSounds.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && key != null)
			{
				//trace('test: ' + dumpExclusions, key);
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		#if !html5 openfl.Assets.cache.clear("songs"); #end
	}

	static public var currentLevel(default, set):String;
	inline static function set_currentLevel(level:String):String
	{
		return currentLevel = level.toLowerCase();
	}

	public static function getPath(file:String, ?type:AssetType = TEXT, ?library:Null<String> = null, ?modsAllowed:Bool = false):String
	{
		#if MODS_ALLOWED
		if (modsAllowed)
		{
			final modded = modFolders(file);
			if (FileSystem.exists(modded))
				return modded;
		}
		#end

		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null)
		{
			if (currentLevel != "default")
			{
				final levelPath = getLibraryPathForce(file, "week_assets", currentLevel);
				if (OpenFlAssets.exists(levelPath, type))
					return levelPath;
			}

			final levelPath = getLibraryPathForce(file, "default");
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		return getSharedPath(file); // getPreloadPath(file);
	}

	inline static public function getLibraryPath(file:String, library = "default"):String
		return (library == "shared" || library == "default") ? getSharedPath(file) : getLibraryPathForce(file, library);
		// return (library == "preload" || library == "default") ? getPreloadPath(file) : getLibraryPathForce(file, library);

	inline static function getLibraryPathForce(file:String, library:String, ?level:String):String
		return '$library:assets/${level ?? library}/$file';

	// getting rid of shared AND preload hehe (preload will still exist in source code cuz its contents will anyway go to the "assets" folder lmao)
	inline public static function getSharedPath(file:String = ''):String
		return getPreloadPath(file); // return 'assets/shared/$file';

	inline public static function getPreloadPath(file:String = ''):String
		return 'assets/$file';

	inline static public function txt(key:String, ?library:String):String
		return getPath('data/$key.txt', TEXT, library);

	inline static public function xml(key:String, ?library:String):String
		return getPath('data/$key.xml', TEXT, library);

	inline static public function json(key:String, ?library:String):String
		return getPath('data/$key.json', TEXT, library);

	inline static public function shaderFragment(key:String, ?library:String):String
		return getPath('shaders/$key.frag', TEXT, library);

	inline static public function shaderVertex(key:String, ?library:String):String
		return getPath('shaders/$key.vert', TEXT, library);

	inline static public function lua(key:String, ?library:String):String
		return getPath('$key.lua', TEXT, library);

	inline static public function video(key:String):String
	{
		#if MODS_ALLOWED
		final file = modsVideo(key);
		if (FileSystem.exists(file))
			return file;
		#end
		return 'assets/videos/$key.$VIDEO_EXT';
	}

	inline static public function srt(key:String, ?library:String):String
	{
		#if MODS_ALLOWED
		final file = modFolders('data/$key.srt');
		if (FileSystem.exists(file))
			return file;
		#end
		return 'assets/data/$key.$SUB_EXT';
	}

	static public function sound(key:String, ?library:String):Sound
		return returnSound('sounds', key, library);

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
		return sound(key + FlxG.random.int(min, max), library);

	inline static public function music(key:String, ?library:String):Sound
		return returnSound('music', key, library);

	inline static public function voices(song:String):Any
	{
		#if html5
		return 'songs:assets/songs/${formatToSongPath(song)}/Voices.$SOUND_EXT';
		#else
		return returnSound('songs', '${formatToSongPath(song)}/Voices');
		#end
	}

	inline static public function inst(song:String):Any
	{
		#if html5
		return 'songs:assets/songs/${formatToSongPath(song)}/Inst.$SOUND_EXT';
		#else
		return returnSound('songs', '${formatToSongPath(song)}/Inst');
		#end
	}

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	static public function image(key:String, ?library:String, ?allowGPU = true, ?posInfos:haxe.PosInfos):FlxGraphic
	{
		var bitmap:BitmapData = null;
		var file:String;

		#if MODS_ALLOWED
		file = modsImages(key);
		if (currentTrackedAssets.exists(file))
		{
			localTrackedAssets.push(file);
			return currentTrackedAssets.get(file);
		}
		else if (FileSystem.exists(file))
			bitmap = BitmapData.fromFile(file);
		else
		{
		#end
			file = getPath('images/$key.png', IMAGE, library);
			if (currentTrackedAssets.exists(file))
			{
				localTrackedAssets.push(file);
				return currentTrackedAssets.get(file);
			}
			else if (OpenFlAssets.exists(file, IMAGE))
				bitmap = OpenFlAssets.getBitmapData(file);
		#if MODS_ALLOWED
		}
		#end

		if (bitmap != null)
			return cacheBitmap(file, bitmap, allowGPU);

		// pos info from https://github.com/ShadowMario/FNF-PsychEngine/pull/13679
		trace('Image with key "$key" could not be found${library == null ? "" : ' in the library "$library"'}! (${posInfos.fileName}, ${posInfos.lineNumber})');
		return null;
	}

	// new psych
	@:access(openfl.display.BitmapData.image)
	@:access(openfl.display.BitmapData.__texture)
	public static function cacheBitmap(file:String, ?bitmap:BitmapData, ?allowGPU = true):FlxGraphic
	{
		if (bitmap == null)
		{
			#if MODS_ALLOWED
			if (FileSystem.exists(file))
				bitmap = BitmapData.fromFile(file);
			else
			#end
			if (OpenFlAssets.exists(file, IMAGE))
				bitmap = OpenFlAssets.getBitmapData(file);

			if (bitmap == null)
				return null;
		}

		if (allowGPU && ClientPrefs.data.cacheOnGPU && bitmap.image != null)
		{
			bitmap.lock();
			if (bitmap.__texture == null)
			{
				bitmap.image.premultiplied = true;
				bitmap.getTexture(FlxG.stage.context3D);
			}
			bitmap.getSurface();
			bitmap.disposeImage();
			bitmap.image.data = null;
			bitmap.image = null;
		}
		final graph = FlxGraphic.fromBitmapData(bitmap, false, file);
		graph.persist = true;
		graph.destroyOnNoUse = false;

		currentTrackedAssets.set(file, graph);
		localTrackedAssets.push(file);
		return graph;
	}

	// use internal asset system only when asset is String and path is not absolete
	inline public static function resolveGraphicAsset(asset:FlxGraphicAsset):FlxGraphicAsset
	{
		return ((asset is String && !(asset.startsWith("assets/") || PNG_REGEX.match(asset))) ? Paths.image(asset) : asset);
	}

	static public function getTextFromFile(key:String, ?ignoreMods = false, ?absolute = false):String
	{
		if (absolute)
		{
			#if sys
			if (FileSystem.exists(key))
				return File.getContent(key);
			#end
			if (OpenFlAssets.exists(key, TEXT))
				return Assets.getText(key);

			return null;
		}
		#if sys
		#if MODS_ALLOWED
		if (!ignoreMods && FileSystem.exists(modFolders(key)))
			return File.getContent(modFolders(key));
		#end

		// if (FileSystem.exists(getPreloadPath(key)))
		//	return File.getContent(getPreloadPath(key));
		if (FileSystem.exists(getSharedPath(key)))
			return File.getContent(getSharedPath(key));

		if (currentLevel != null)
		{
			if (currentLevel != "default")
			{
				final levelPath = getLibraryPathForce(key, 'week_assets', currentLevel);
				if (FileSystem.exists(levelPath))
					return File.getContent(levelPath);
			}

			final levelPath = getLibraryPathForce(key, "default");
			if (FileSystem.exists(levelPath))
				return File.getContent(levelPath);
		}
		#end
		final path = getPath(key, TEXT);
		if (OpenFlAssets.exists(path, TEXT))
			return Assets.getText(path);

		return null;
	}

	inline static public function font(key:String)
	{
		#if MODS_ALLOWED
		final file = modsFont(key);
		if (FileSystem.exists(file))
			return file;
		#end
		return 'assets/fonts/$key';
	}

	public static function fileExists(key:String, type:AssetType, ?ignoreMods = false, ?library:String):Bool
	{
		#if MODS_ALLOWED
		if (!ignoreMods)
		{
			for (mod in Mods.getGlobalMods())
				if (FileSystem.exists(mods('$mod/$key')))
					return true;

			if (FileSystem.exists(mods('${Mods.currentModDirectory}/$key')) || FileSystem.exists(mods(key)))
				return true;
		}
		#end

		return OpenFlAssets.exists(getPath(key, type, library, false));
	}

	// less optimized but automatic handling
	static public function getAtlas(key:String, ?library:String, ?allowGPU = true):FlxAtlasFrames
	{
		#if MODS_ALLOWED
		if (FileSystem.exists(modsXml(key)) || OpenFlAssets.exists(getPath('images/$key.xml', library), TEXT))
		#else
		if (OpenFlAssets.exists(getPath('images/$key.xml', library)))
		#end
			return getSparrowAtlas(key, library, allowGPU);

		return getPackerAtlas(key, library, allowGPU);
	}

	inline static public function getSparrowAtlas(key:String, ?library:String, ?allowGPU = true):FlxAtlasFrames
	{
		try
		{
			#if MODS_ALLOWED
			final xml = modsXml(key);
			return FlxAtlasFrames.fromSparrow(image(key, allowGPU) ?? image(key, library, allowGPU),
										(FileSystem.exists(xml) ? File.getContent(xml) : getPath('images/$key.xml', library)));
			#else
			return FlxAtlasFrames.fromSparrow(image(key, library, allowGPU), getPath('images/$key.xml', library));
			#end
		}
		catch(e)
		{
			trace('[getSparrowAtlas] - ERROR WHILE LOADING "$key" xml: ${e.message}.');
			lime.app.Application.current.window.alert('${e.message}\n\ntl;dr; no spritesheet lmao.\nbtw, this message won\'t crash the game! :D', 'XML ERROR!!');
			return null;
		}
	}

	inline static public function getPackerAtlas(key:String, ?library:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		#if MODS_ALLOWED
		final txt = modsTxt(key);
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, allowGPU) ?? image(key, library, allowGPU),
												(FileSystem.exists(txt) ? File.getContent(txt) : getPath('images/$key.txt', library)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library, allowGPU), getPath('images/$key.txt', library));
		#end
	}

	inline static public function formatToSongPath(path:String)
	{
		final invalidChars = ~/[~&\\;:<>#]/;
		final hideChars = ~/[.,'"%?!]/;
		final path = invalidChars.split(path.replace(' ', '-')).join("-");
		return hideChars.split(path).join("").toLowerCase();
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static function returnSound(path:String, key:String, ?library:String)
	{
		try
		{
			#if MODS_ALLOWED
			final file:String = modsSounds(path, key);
			if (FileSystem.exists(file))
			{
				if (!currentTrackedSounds.exists(file))
					currentTrackedSounds.set(file, Sound.fromFile(file));
				localTrackedAssets.push(key);
				return currentTrackedSounds.get(file);
			}
			#end
			// I hate this so god damn much
			var gottenPath:String = getPath('$path/$key.$SOUND_EXT', SOUND, library);
			gottenPath = gottenPath.substring(gottenPath.indexOf(':') + 1, gottenPath.length);
			// trace(gottenPath);
			if (!currentTrackedSounds.exists(gottenPath))
			#if MODS_ALLOWED
				currentTrackedSounds.set(gottenPath, Sound.fromFile('./$gottenPath'));
			#else
			{
				final folder = path == "songs" ? 'songs:' : '';
				currentTrackedSounds.set(gottenPath, OpenFlAssets.getSound(folder + getPath('$path/$key.$SOUND_EXT', SOUND, library)));
			}
			#end
			localTrackedAssets.push(gottenPath);
			return currentTrackedSounds.get(gottenPath);
		}
		catch(e) // FUCKING OPENFL - richTrash21
		{
			trace('${e.message}\nfucking openfl...');
			return null;
		}
	}

	#if MODS_ALLOWED
	inline static public function mods(key:String = '')
		return 'mods/$key';

	inline static public function modsFont(key:String)
		return modFolders('fonts/$key');

	inline static public function modsJson(key:String)
		return modFolders('data/$key.json');

	inline static public function modsVideo(key:String)
		return modFolders('videos/$key.$VIDEO_EXT');

	inline static public function modsSounds(path:String, key:String)
		return modFolders('$path/$key.$SOUND_EXT');

	inline static public function modsImages(key:String)
		return modFolders('images/$key.png');

	inline static public function modsXml(key:String)
		return modFolders('images/$key.xml');

	inline static public function modsTxt(key:String)
		return modFolders('images/$key.txt');

	/* Goes unused for now

	inline static public function modsShaderFragment(key:String, ?library:String)
		return modFolders('shaders/$key.frag');

	inline static public function modsShaderVertex(key:String, ?library:String)
		return modFolders('shaders/$key.vert');

	inline static public function modsAchievements(key:String)
		return modFolders('achievements/$key.json');
	
	*/

	static public function modFolders(key:String)
	{
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			final fileToCheck:String = mods('${Mods.currentModDirectory}/$key');
			if (FileSystem.exists(fileToCheck))
				return fileToCheck;
		}
		for (mod in Mods.getGlobalMods())
		{
			final fileToCheck:String = mods('$mod/$key');
			if (FileSystem.exists(fileToCheck))
				return fileToCheck;
		}
		return 'mods/$key';
	}
	#end
}
