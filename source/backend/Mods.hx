package backend;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef ModsList = {
	enabled:Array<String>,
	disabled:Array<String>,
	all:Array<String>
};

class Mods
{
	static public var currentModDirectory:String = '';
	public static var ignoreModFolders:Array<String> = [
		#if ACHIEVEMENTS_ALLOWED 'achievements', #end
		'characters',
		'custom_events',
		'custom_notetypes',
		'data',
		'songs',
		'music',
		'sounds',
		'shaders',
		'videos',
		'images',
		'stages',
		'weeks',
		'fonts',
		'scripts'
	];

	private static var globalMods:Array<String> = [];
	inline public static function getGlobalMods():Array<String> return globalMods;

	inline public static function pushGlobalMods() // prob a better way to do this but idc
	{
		globalMods = [];
		for (mod in parseList().enabled)
		{
			final pack:Dynamic = getPack(mod);
			if (pack != null && pack.runsGlobally)
				globalMods.push(mod);
		}
		return globalMods;
	}

	inline public static function getModDirectories():Array<String>
	{
		final list:Array<String> = [];
		#if MODS_ALLOWED
		final modsFolder:String = Paths.mods();
		if (FileSystem.exists(modsFolder))
		{
			for (folder in FileSystem.readDirectory(modsFolder))
			{
				final path = haxe.io.Path.join([modsFolder, folder]);
				if (sys.FileSystem.isDirectory(path) && !ignoreModFolders.contains(folder.toLowerCase()) && !list.contains(folder))
					list.push(folder);
			}
		}
		#end
		return list;
	}
	
	inline public static function mergeAllTextsNamed(path:String, ?defaultDirectory:String, allowDuplicates:Bool = false)
	{
		if (defaultDirectory == null)
			defaultDirectory = Paths.getPreloadPath();

		defaultDirectory = defaultDirectory.trim();
		if (!defaultDirectory.endsWith("/"))
			defaultDirectory += "/";
		if (!defaultDirectory.startsWith("assets/"))
			defaultDirectory = "assets/$defaultDirectory";

		final mergedList = new Array<String>();
		final paths = directoriesWithFile(defaultDirectory, path);

		final defaultPath = defaultDirectory + path;
		if (paths.contains(defaultPath))
		{
			paths.remove(defaultPath);
			paths.insert(0, defaultPath);
		}

		for (file in paths)
			for (value in CoolUtil.coolTextFile(file))
				if ((allowDuplicates || !mergedList.contains(value)) && value.length > 0)
					mergedList.push(value);

		return mergedList;
	}

	inline public static function directoriesWithFile(path:String, fileToFind:String, mods:Bool = true)
	{
		final foldersToCheck:Array<String> = [];
		#if sys
		if (FileSystem.exists(path + fileToFind))
		#end
			foldersToCheck.push(path + fileToFind);

		#if MODS_ALLOWED
		if (mods)
		{
			// Global mods first
			for (mod in globalMods)
			{
				final folder:String = Paths.mods('$mod/$fileToFind');
				if (FileSystem.exists(folder)) foldersToCheck.push(folder);
			}

			// Then "PsychEngine/mods/" main folder
			final folder:String = Paths.mods(fileToFind);
			if (FileSystem.exists(folder)) foldersToCheck.push(folder);

			// And lastly, the loaded mod's folder
			if (currentModDirectory != null && currentModDirectory.length > 0
				&& !globalMods.contains(currentModDirectory)) // IGNORES CURRENT MOD IF IT'S LOADED AS GLOBAL I WANT TO KYS
			{
				final folder:String = Paths.mods('$currentModDirectory/$fileToFind');
				if (FileSystem.exists(folder)) foldersToCheck.push(folder);
			}
		}
		#end
		return foldersToCheck;
	}

	public static function getPack(?folder:String):Dynamic
	{
		#if MODS_ALLOWED
		if (folder == null)
			folder = currentModDirectory;

		final path = Paths.mods('$folder/pack.json');
		if(FileSystem.exists(path)) {
			try
			{
				final rawJson = #if sys File.getContent(path) #else lime.utils.Assets.getText(path) #end;
				if (rawJson?.length > 0)
					return haxe.Json.parse(rawJson);
			}
			catch(e)
				trace(e);
		}
		#end
		return null;
	}

	public static var updatedOnState:Bool = false;
	inline public static function parseList():ModsList
	{
		if (!updatedOnState)
			updateModList();
		final list:ModsList = {enabled: [], disabled: [], all: []};

		#if MODS_ALLOWED
		try
		{
			for (mod in CoolUtil.coolTextFile('modsList.txt'))
			{
				//trace('Mod: $mod');
				if (mod.trim().length < 1)
					continue;

				final dat = mod.split("|");
				list.all.push(dat[0]);
				if (dat[1] == "1")
					list.enabled.push(dat[0]);
				else
					list.disabled.push(dat[0]);
			}
		}
		catch(e)
			trace(e);
		#end
		return list;
	}
	
	private static function updateModList()
	{
		#if MODS_ALLOWED
		// Find all that are already ordered
		final list:Array<Array<haxe.extern.EitherType<String, Bool>>> = [];
		final added:Array<String> = [];
		try
		{
			for (mod in CoolUtil.coolTextFile('modsList.txt'))
			{
				final dat:Array<String> = mod.split("|");
				final folder:String = dat[0];
				if (folder.trim().length > 0 && FileSystem.exists(Paths.mods(folder)) && FileSystem.isDirectory(Paths.mods(folder)) && !added.contains(folder))
				{
					added.push(folder);
					list.push([folder, (dat[1] == "1")]);
				}
			}
		}
		catch(e)
			trace(e);
		
		// Scan for folders that aren't on modsList.txt yet
		for (folder in getModDirectories())
		{
			if (folder.trim().length > 0 && FileSystem.exists(Paths.mods(folder)) && FileSystem.isDirectory(Paths.mods(folder))
				&& !ignoreModFolders.contains(folder.toLowerCase()) && !added.contains(folder))
			{
				added.push(folder);
				list.push([folder, true]); //i like it false by default. -bb //Well, i like it True! -Shadow Mario (2022)
				//Shadow Mario (2023): What the fuck was bb thinking
			}
		}

		// Now save file
		var fileStr:String = '';
		for (values in list)
		{
			if (fileStr.length > 0)
				fileStr += '\n';
			fileStr += values[0] + '|' + (values[1] ? '1' : '0');
		}

		File.saveContent('modsList.txt', fileStr);
		updatedOnState = true;
		#end
	}

	public static function loadTopMod()
	{
		currentModDirectory = '';
		#if MODS_ALLOWED
		final list = parseList().enabled;
		if (list != null && list[0] != null)
			currentModDirectory = list[0];
		#end
	}
}