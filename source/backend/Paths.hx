package backend;

import haxe.PosInfos;
import flixel.util.FlxArrayUtil;
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

@:access(openfl.display.BitmapData.__texture)
@:access(flixel.system.frontEnds.BitmapFrontEnd)
class Paths
{
	public static final SOUND_EXT = #if web "mp3" #else "ogg" #end;
	public static final VIDEO_EXT = "mp4";
	// had to change it to "subs" since vlc loads subtitles by itself and i cant disable it!
	public static final SUB_EXT = "subs"; // "srt";

	public static var currentLevel(default, set):String = "default";

	public static var dumpExclusions = [
		'assets/music/freakyMenu.$SOUND_EXT',
		'assets/music/breakfast.$SOUND_EXT',
		'assets/music/tea-time.$SOUND_EXT',
		"assets/images/alphabet.png"
	];

	public static final PNG_REGEX = ~/^.+\.png$/i;
	public static final LUA_REGEX = ~/^.+\.lua$/i;
	public static final HX_REGEX  = ~/^.+\.hx$/i;

	// define the locally tracked assets
	public static final localTrackedAssets   = new Array<String>(); // all assets
	public static final currentTrackedAssets = new Array<String>(); // graphics
	public static final currentTrackedSounds = new Array<String>(); // sounds

	static final INVALID_CHARS = ~/[~&\\;:<>#]/;
	static final HIDE_CHARS = ~/[.,'"%?!]/;

	// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory()
	{
		__clear__null__items(currentTrackedAssets);

		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets)
		{
			// if it is not currently contained within the used local assets
			if (localTrackedAssets.contains(key) || dumpExclusions.contains(key) || key.endsWith('.$SOUND_EXT'))
				continue;

			// remove the key from all cache maps
			currentTrackedAssets.remove(key);
			__destroy__graphic(FlxG.bitmap.get(key));
		}

		// run the garbage collector for good measure lmfao
		openfl.system.System.gc();
	}

	public static function clearStoredMemory(cleanUnused = false)
	{
		// clear anything not in the tracked assets list
		for (key in FlxG.bitmap._cache.keys())
		{
			if (currentTrackedAssets.contains(key) || dumpExclusions.contains(key))
				continue;

			localTrackedAssets.remove(key);
			__destroy__graphic(FlxG.bitmap.get(key));
		}

		__clear__null__items(currentTrackedSounds);

		// clear all sounds that are cached
		var snd:Sound;
		for (key in currentTrackedSounds)
		{
			if (localTrackedAssets.contains(key) || dumpExclusions.contains(key))
				continue;

			// thx redar
			snd = OpenFlAssets.cache.getSound(key);
			if (snd != null)
				snd.close();

			currentTrackedSounds.remove(key);
			OpenFlAssets.cache.removeSound(key);
		}
		// flags everything to be cleared out next unused memory clear
		FlxArrayUtil.clearArray(localTrackedAssets);
		#if !html5
		OpenFlAssets.cache.clear("songs");
		#end
		// run gc once
		if (cleanUnused)
			clearUnusedMemory();
		else
			openfl.system.System.gc();
	}

	public static function getPath(file:String, type:AssetType = TEXT, ?library:String, modsAllowed = false):String
	{
		var levelPath:String;
		#if MODS_ALLOWED
		if (modsAllowed)
			if (FileSystem.exists(levelPath = modFolders(file)))
				return levelPath;
		#end

		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null)
		{
			if (currentLevel != "default")
				if (OpenFlAssets.exists(levelPath = getLibraryPathForce(file, "week_assets", currentLevel), type))
					return levelPath;

			if (OpenFlAssets.exists(levelPath = getLibraryPathForce(file, "default"), type))
				return levelPath;
		}
		return getSharedPath(file);
	}

	inline static public function getLibraryPath(file:String, library = "default"):String
	{
		return (library == "shared" || library == "default") ? getSharedPath(file) : getLibraryPathForce(file, library);
	}

	inline static function getLibraryPathForce(file:String, library:String, ?level:String):String
	{
		return '$library:assets/${level ?? library}/$file';
	}

	// getting rid of shared AND preload hehe (preload will still exist in source code cuz its contents will anyway go to the "assets" folder lmao)
	inline public static function getSharedPath(file = ""):String
	{
		return 'assets/$file';
	}

	inline static public function txt(key:String, ?library:String):String
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline static public function xml(key:String, ?library:String):String
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	inline static public function json(key:String, ?library:String):String
	{
		return getPath('data/$key.json', TEXT, library);
	}

	inline static public function shaderFragment(key:String, ?library:String):String
	{
		return getPath('shaders/$key.frag', TEXT, library);
	}

	inline static public function shaderVertex(key:String, ?library:String):String
	{
		return getPath('shaders/$key.vert', TEXT, library);
	}

	inline static public function lua(key:String, ?library:String):String
	{
		return getPath('$key.lua', TEXT, library);
	}

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
		final file = modFolders('videos/$key.$SUB_EXT');
		if (FileSystem.exists(file))
			return file;
		#end
		return 'assets/videos/$key.$SUB_EXT';
	}

	inline static public function sound(key:String, ?library:String, ?pos:PosInfos):Sound
	{
		return returnSound("sounds", key, library, pos);
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String, ?pos:PosInfos):Sound
	{
		return sound(key + FlxG.random.int(min, max), library, pos);
	}

	inline static public function music(key:String, ?library:String, ?pos:PosInfos):Sound
	{
		return returnSound("music", key, library, pos);
	}

	inline static public function voices(song:String, ?suffix:String, ?pos:PosInfos):#if html5 String #else Sound #end
	{
		song = formatToSongPath(song);
		var file = #if html5 'songs:assets/songs/$song/Voices' #else '$song/Voices' #end;
		if (suffix != null)
			file += suffix.startsWith("-") ? suffix : '-$suffix';

		return #if html5 '$file.$SOUND_EXT' #else returnSound("songs", file, null, pos) #end;
	}

	inline static public function inst(song:String, ?pos:PosInfos):#if html5 String #else Sound #end
	{
		song = formatToSongPath(song);
		return #if html5 'songs:assets/songs/$song/Inst.$SOUND_EXT' #else returnSound("songs", '$song/Inst', null, pos) #end;
	}

	static public function image(key:String, ?library:String, allowGPU = true, ?pos:PosInfos):FlxGraphic
	{
		var file:String;
		var bitmap:BitmapData = null;

		#if MODS_ALLOWED
		file = modsImages(key);
		if (hasGraphic(file))
		{
			__try__push(localTrackedAssets, file);
			return FlxG.bitmap.get(file);
		}
		else if (FileSystem.exists(file))
			bitmap = BitmapData.fromFile(file);
		else
		{
		#end
			file = getPath('images/$key.png', IMAGE, library);
			if (hasGraphic(file))
			{
				__try__push(localTrackedAssets, file);
				return FlxG.bitmap.get(file);
			}
			else if (OpenFlAssets.exists(file, IMAGE))
				bitmap = OpenFlAssets.getBitmapData(file);
		#if MODS_ALLOWED
		}
		#end

		final graphic = cacheBitmap(file, bitmap, allowGPU);
		if (graphic == null)
		{
			// pos info from https://github.com/ShadowMario/FNF-PsychEngine/pull/13679
			var t = 'Image with key "$key" could not be found';
			if (library != null)
				t += ' in the library "$library"';
			Main.warn('$t!', pos);
		}
		else
		{
			currentTrackedAssets.push(file);
			__try__push(localTrackedAssets, file);
		}
		return graphic;
	}

	// new psych
	public static function cacheBitmap(file:String, ?bitmap:BitmapData, allowGPU = true):FlxGraphic
	{
		if (bitmap == null)
			return null;

		if (allowGPU && ClientPrefs.data.cacheOnGPU && bitmap.image != null && bitmap.__texture == null)
		{
			bitmap.lock();
			bitmap.getSurface();
			bitmap.disposeImage();
			bitmap.getTexture(FlxG.stage.context3D);
			bitmap.unlock();
		}
		final graphic = FlxGraphic.fromBitmapData(bitmap, false, file);
		graphic.destroyOnNoUse = false;
		graphic.persist = true;
		return graphic;
	}

	// use internal asset system only when asset is String and path is not absolete
	inline public static function resolveGraphicAsset(asset:FlxGraphicAsset, ?pos:PosInfos):FlxGraphicAsset
	{
		return ((asset is String && !(asset.startsWith("assets/") || PNG_REGEX.match(asset))) ? image(asset, pos) : asset);
	}

	static public function getTextFromFile(key:String, ignoreMods = false, absolute = false, ?pos:PosInfos):String
	{
		inline function warn(k:String, p:PosInfos)
		{
			Main.warn('Counld not find "$k"!', p);
		}

		if (absolute)
		{
			#if sys
			if (FileSystem.exists(key))
				return File.getContent(key);
			#end
			if (OpenFlAssets.exists(key, TEXT))
				return Assets.getText(key);

			warn(key, pos);
			return null;
		}
		var path:String;
		#if sys
		#if MODS_ALLOWED
		if (!ignoreMods && FileSystem.exists(path = modFolders(key)))
			return File.getContent(path);
		#end

		if (FileSystem.exists(path = getSharedPath(key)))
			return File.getContent(path);

		if (currentLevel != null)
		{
			if (currentLevel != "default")
				if (FileSystem.exists(path = getLibraryPathForce(key, "week_assets", currentLevel)))
					return File.getContent(path);

			if (FileSystem.exists(path = getLibraryPathForce(key, "default")))
				return File.getContent(path);
		}
		#end
		if (OpenFlAssets.exists(path = getPath(key, TEXT), TEXT))
			return Assets.getText(path);

		warn(key, pos);
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

	public static function fileExists(key:String, type:AssetType, ignoreMods = false, ?library:String):Bool
	{
		#if MODS_ALLOWED
		if (!ignoreMods)
		{
			for (mod in Mods.getGlobalMods())
				if (FileSystem.exists(mods('$mod/$key')))
					return true;

			if (FileSystem.exists(mods(Mods.currentModDirectory + '/$key')) || FileSystem.exists(mods(key)))
				return true;
		}
		#end

		return OpenFlAssets.exists(getPath(key, type, library, false));
	}

	// less optimized but automatic handling
	static public function getAtlas(key:String, ?library:String, allowGPU = true, ?pos:PosInfos):FlxAtlasFrames
	{
		if (#if MODS_ALLOWED FileSystem.exists(modsXml(key)) || #end OpenFlAssets.exists(getPath('images/$key.xml', library), TEXT))
			return getSparrowAtlas(key, library, allowGPU, pos);

		return getPackerAtlas(key, library, allowGPU, pos);
	}

	/*inline*/ static public function getSparrowAtlas(key:String, ?library:String, allowGPU = true, ?pos:PosInfos):FlxAtlasFrames
	{
		try
		{
			final graphic = #if MODS_ALLOWED image(key, allowGPU, pos) ?? #end image(key, library, allowGPU, pos);

			var xml:String;
			#if MODS_ALLOWED
			xml = modsXml(key);
			if (FileSystem.exists(xml))
				xml = File.getContent(xml);
			else
			#end
				xml = getPath('images/$key.xml', library);

			return FlxAtlasFrames.fromSparrow(graphic, xml);
		}
		catch(e)
		{
			Main.warn('[getSparrowAtlas] - ERROR WHILE LOADING "$key" xml: $e.', pos);
			lime.app.Application.current.window.alert('$e\n\ntl;dr; no spritesheet lmao.\nbtw, this message won\'t crash the game! :D', "XML ERROR!!");
			return null;
		}
	}

	/*inline*/ static public function getPackerAtlas(key:String, ?library:String = null, ?allowGPU:Bool = true, ?pos:PosInfos):FlxAtlasFrames
	{
		final graphic = #if MODS_ALLOWED image(key, allowGPU, pos) ?? #end image(key, library, allowGPU, pos);

		var txt:String;
		#if MODS_ALLOWED
		txt = modsTxt(key);
		if (FileSystem.exists(txt))
			txt = File.getContent(txt);
		else
		#end
			txt = getPath('images/$key.txt', library);

		return FlxAtlasFrames.fromSpriteSheetPacker(graphic, txt);
	}

	inline static public function formatToSongPath(path:String)
	{
		return HIDE_CHARS.split(INVALID_CHARS.split(path.replace(" ", "-")).join("-")).join("").toLowerCase();
	}

	public static function returnSound(path:String, key:String, ?library:String, ?pos:PosInfos):Sound
	{
		try
		{
			var file:String;
			var sound:Sound = null;
			#if MODS_ALLOWED
			file = modsSounds(path, key);
			if (hasSound(file))
				sound = OpenFlAssets.getSound(file);
			else if (FileSystem.exists(file))
			{
				sound = Sound.fromFile(file);
				OpenFlAssets.cache.setSound(file, sound);
				currentTrackedSounds.push(file);
			}

			if (sound != null)
			{
				__try__push(localTrackedAssets, file);
				return sound;
			}
			#end

			// I hate this so god damn much
			file = getPath('$path/$key.$SOUND_EXT', SOUND, library);
			final i = file.indexOf(":");
			if (i != -1)
				file = file.substring(i+1, file.length);

			if (hasSound(file))
				sound = OpenFlAssets.getSound(file);
			else
			{
				#if MODS_ALLOWED
				sound = Sound.fromFile('./$file');
				OpenFlAssets.cache.setSound(file, sound);
				#else
				sound = OpenFlAssets.getSound(path == "songs" ? '$path:$file' : file);
				#end
				currentTrackedSounds.push(file);
			}
			__try__push(localTrackedAssets, file);
			return sound;
		}
		catch(e) // FUCKING OPENFL - richTrash21
		{
			Main.warn('$e (fucking openfl...)', pos);
			return null;
		}
	}

	inline public static function hasAsset(path:String):Bool
	{
		return hasSound(path) || hasGraphic(path);
	}

	inline public static function hasSound(path:String):Bool
	{
		return currentTrackedSounds.contains(path);
	}

	inline public static function hasGraphic(path:String):Bool
	{
		return currentTrackedAssets.contains(path);
	}

	#if MODS_ALLOWED
	inline static public function mods(key = ""):String
	{
		return 'mods/$key';
	}

	inline static public function modsFont(key:String):String
	{
		return modFolders('fonts/$key');
	}

	inline static public function modsJson(key:String):String
	{
		return modFolders('data/$key.json');
	}

	inline static public function modsVideo(key:String):String
	{
		return modFolders('videos/$key.$VIDEO_EXT');
	}

	inline static public function modsSounds(path:String, key:String):String
	{
		return modFolders('$path/$key.$SOUND_EXT');
	}

	inline static public function modsImages(key:String):String
	{
		return modFolders('images/$key.png');
	}

	inline static public function modsXml(key:String):String
	{
		return modFolders('images/$key.xml');
	}

	inline static public function modsTxt(key:String):String
	{
		return modFolders('images/$key.txt');
	}

	static public function modFolders(key:String):String
	{
		var fileToCheck:String;
		if (!Mods.currentModDirectory.isNullOrEmpty())
			if (FileSystem.exists(fileToCheck = mods(Mods.currentModDirectory + '/$key')))
				return fileToCheck;

		for (mod in Mods.getGlobalMods())
			if (FileSystem.exists(fileToCheck = mods('$mod/$key')))
				return fileToCheck;

		return mods(key);
	}
	#end

	inline public static function excludeAsset(key:String):Int
	{
		return __try__push(dumpExclusions, key);
	}

	@:noCompletion extern inline static function __clear__null__items<T>(__array:Array<T>)
	{
		while (__array.contains(null))
			__array.remove(null);
	}

	@:noCompletion extern inline static function __try__push<T>(__array:Array<T>, __item:T):Int
	{
		final __id = __array.indexOf(__item);
		return __id == -1 ? __array.push(__item) : __id;
	}

	// thx redar
	@:noCompletion extern inline static function __destroy__graphic(__graphic:FlxGraphic)
	{
		if (__graphic != null && __graphic.bitmap != null && __graphic.bitmap.__texture != null)
		{
			__graphic.bitmap.__texture.dispose();
			__graphic.bitmap.__texture = null;
		}
		FlxG.bitmap.remove(__graphic);
	}

	@:noCompletion inline static function set_currentLevel(level:String):String
	{
		return currentLevel = level.toLowerCase();
	}
}
