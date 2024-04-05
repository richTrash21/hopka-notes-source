package backend;

#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#else
import openfl.utils.Assets;
#end

typedef StageFile = {
	var directory:String;
	var defaultZoom:Float;
	var isPixelStage:Bool;
	var stageUI:String;

	var boyfriend:Array<Float>;
	var girlfriend:Array<Float>;
	var opponent:Array<Float>;
	var hide_girlfriend:Bool;

	var camera_boyfriend:Array<Float>;
	var camera_opponent:Array<Float>;
	var camera_girlfriend:Array<Float>;
	@:optional var camera_speed:Float;
}

class StageData
{
	inline public static function dummy():StageFile
	{
		return {
			directory: "",
			defaultZoom: 0.9,
			isPixelStage: false,
			stageUI: "normal",

			boyfriend: [770, 100],
			girlfriend: [400, 130],
			opponent: [100, 100],
			hide_girlfriend: false,

			camera_boyfriend: [0, 0],
			camera_opponent: [0, 0],
			camera_girlfriend: [0, 0],
			camera_speed: 1
		};
	}

	public static var forceNextDirectory:String;
	public static function loadDirectory(SONG:backend.Song)
	{
		// final stage = SONG.stage ?? "stage";
		/*if (SONG.stage != null)
		 	stage = SONG.stage;
		else if (SONG.song != null)
		 	stage = "stage";*/

		forceNextDirectory = getStageFile(SONG.stage ?? "stage")?.directory ?? ""; // preventing crashes
	}

	inline public static function getStageFile(stage:String):StageFile
	{
		var rawJson:String = null;
		final path = Paths.getSharedPath('stages/$stage.json');
		#if MODS_ALLOWED
		final modPath = Paths.modFolders('stages/$stage.json');
		if (FileSystem.exists(modPath))
			rawJson = File.getContent(modPath);
		else if (FileSystem.exists(path))
			rawJson = File.getContent(path);
		#else
		if (Assets.exists(path))
			rawJson = Assets.getText(path);
		#end

		return rawJson == null ? null : cast haxe.Json.parse(rawJson);
	}

	// LMFAOOOOOOOOOOOOOOOOOO GET BUTCHERED!!!!!!!!!!!!
	inline public static function vanillaSongStage(songName):String
	{
		return "stage";
	}
}
