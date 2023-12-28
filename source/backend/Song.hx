package backend;

#if sys
import sys.io.File;
#end

import backend.Section.SwagSection;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;
	
	@:optional var disableNoteRGB:Bool;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
}

class Song
{
	// IDFK WHAT THESE ARE BUT APARENTLY THEY WERE IN VS FORDICK'S CHARTS LMAO
	//public static final invalidFields:Array<String> = ['player3', 'validScore', 'isHey', 'cutsceneType', 'isSpooky', 'isMoody', 'uiType', 'sectionLengths'];
	public static final validFields:Array<String> = Type.getInstanceFields(Song);

	public var song:String = '';
	public var notes:Array<SwagSection> = [];
	public var events:Array<Dynamic> = [];
	public var bpm:Float = 100;
	public var needsVoices:Bool = true;
	public var speed:Float = 1;

	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var stage:String = 'stage';

	public var gameOverChar:String = null;
	public var gameOverSound:String = null;
	public var gameOverLoop:String = null;
	public var gameOverEnd:String = null;

	public var disableNoteRGB:Bool = false;

	public var arrowSkin:String = null;
	public var splashSkin:String = null;

	public function new(SONG:SwagSong)
	{
		for (field in Reflect.fields(SONG))
		{
			if (validFields.contains(field))
				Reflect.setField(this, field, Reflect.field(SONG, field));
			else
				trace('WARNING!! This chart have invalid field "$field"');
		}
	}

	private static function onLoadJson(songJson:Dynamic):SwagSong // Convert old charts to newest format
	{
		if (songJson.gfVersion == null)
			songJson.gfVersion = songJson.player3;

		if (songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				final sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				final notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					final note:Array<Dynamic> = notes[i];
					if (note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}

		// yeet the garbage!!
		for (field in Reflect.fields(songJson))
			if (!validFields.contains(field))
				Reflect.deleteField(songJson, field);

		return songJson;
	}

	inline public static function loadFromJson(jsonInput:String, ?folder:String):Song
	{
		var rawJson = null;
		
		final formattedFolder:String = Paths.formatToSongPath(folder);
		final formattedSong:String = Paths.formatToSongPath(jsonInput);
		#if MODS_ALLOWED
		final moddyFile:String = Paths.modsJson('$formattedFolder/$formattedSong');
		if (sys.FileSystem.exists(moddyFile)) rawJson = File.getContent(moddyFile).trim();
		#end

		if (rawJson == null)
		{
			#if sys
			rawJson = File.getContent(Paths.json('$formattedFolder/$formattedSong')).trim();
			#else
			rawJson = lime.utils.Assets.getText(Paths.json('$formattedFolder/$formattedSong')).trim();
			#end
		}

		/*var len = rawJson.length;
		while (!rawJson.endsWith("}"))
		{
			rawJson = rawJson.substr(0, --len);
			// LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
		}*/

		final songJson:Song = new Song(onLoadJson(parseJSONshit(rawJson)));
		if (jsonInput != 'events') StageData.loadDirectory(songJson);
		return songJson;
	}

	inline public static function parseJSONshit(rawJson:String):SwagSong
		return cast haxe.Json.parse(rawJson).song;
}
