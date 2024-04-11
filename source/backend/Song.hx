package backend;

import haxe.extern.EitherType;
#if sys
import sys.io.File;
#end

typedef SwagSong =
{
	var song:String;
	var notes:Array<Section.SwagSection>;
	var events:Array<EventNoteData>;
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
	
	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
	@:optional var disableNoteRGB:Bool;
	@:optional var swapNotes:Bool;
}

/*@:structInit*/ class Song
{
	// IDFK WHAT THESE ARE BUT APARENTLY THEY WERE IN VS FORDICK'S CHARTS LMAO
	// public static final invalidFields = ["player3", "validScore", "isHey", "cutsceneType", "isSpooky", "isMoody", "uiType", "sectionLengths"];
	static final validFields = Type.getInstanceFields(Song);

	public static function loadFromJson(jsonInput:String, ?folder:String):Song
	{
		var rawJson:String = null;
		
		final formattedFolder = Paths.formatToSongPath(folder);
		final formattedSong = Paths.formatToSongPath(jsonInput);
		#if MODS_ALLOWED
		final moddyFile = Paths.modsJson('$formattedFolder/$formattedSong');
		if (sys.FileSystem.exists(moddyFile))
			rawJson = File.getContent(moddyFile);
		#end

		if (rawJson == null)
		{
			rawJson = Paths.json('$formattedFolder/$formattedSong');
			rawJson = #if sys File.getContent(rawJson) #else lime.utils.Assets.getText(rawJson) #end;
		}

		final songJson = new Song(onLoadJson(parseJSONshit(rawJson)));
		if (jsonInput != "events")
			StageData.loadDirectory(songJson);
		return songJson;
	}

	inline public static function parseJSONshit(rawJson:String):SwagSong
	{
		return cast haxe.Json.parse(rawJson).song;
	}

	static function onLoadJson(songJson:Dynamic):SwagSong // Convert old charts to newest format
	{
		if (songJson.gfVersion == null)
			songJson.gfVersion = songJson.player3;

		if (songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				final notes:Array<Dynamic> = songJson.notes[secNum].sectionNotes;
				var len = notes.length;
				var i = 0;
				while (i < len)
				{
					final note:Array<Dynamic> = notes[i];
					if (note[1] == -1)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else
						i++;
				}
			}
		}

		// yeet the garbage!!
		for (field in Reflect.fields(songJson))
		{
			if (field == "notes")
			{
				for (section in cast (songJson.notes, Array<Dynamic>))
					for (sectionField in Reflect.fields(section))
						if (!Section.validFields.contains(sectionField))
							Reflect.deleteField(section, sectionField);
			}
			else if (!validFields.contains(field))
				Reflect.deleteField(songJson, field);
		}

		return songJson;
	}

	public var song:String;
	public var notes:Array<Section>;
	public var events:Array<EventNoteData>;
	public var bpm:Float = 100;
	public var needsVoices:Bool = true;
	public var speed:Float = 1;

	public var player1:String = "bf";
	public var player2:String = "dad";
	public var gfVersion:String = "gf";
	public var stage:String = "stage";

	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;

	public var arrowSkin:String;
	public var splashSkin:String;
	public var disableNoteRGB:Null<Bool>;
	public var swapNotes:Null<Bool>; // for quickly swapping bf and dad notes

	public function new(SONG:SwagSong)
	{
		for (field in Reflect.fields(SONG))
		{
			if (field == "notes")
				notes = [for (section in SONG.notes) new Section(section)];
			else if (validFields.contains(field))
			{
				Reflect.setField(this, field, Reflect.field(SONG, field));
				// clear some original psych chart editor bullshit
				if (field == "events")
				{
					var a:Array<Dynamic>;
					for (eventNote in events)
					{
						a = eventNote;
						while (a.length > 2)
							a.pop();
					}
				}
			}
			else
			{
				trace('WARNING!! This chart have invalid field "$field"');
				Reflect.deleteField(SONG, field);
			}
		}
	}

	public function toString():String
	{
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("song", song),
			LabelValuePair.weak("bpm", bpm),
			LabelValuePair.weak("needsVoices", needsVoices),
			LabelValuePair.weak("sections", notes.length),
			LabelValuePair.weak("events", events.length),
			LabelValuePair.weak("speed", speed)
		]);
	}
}

abstract EventNoteData(Array<EitherType<Float, Array<EventData>>>) from Array<EitherType<Float, Array<EventData>>> to Array<EitherType<Float, Array<EventData>>>
{
	public var strumTime(get, set):Float;
	public var events(get, set):Array<EventData>;

	@:noCompletion inline function get_strumTime():Float		   return this[0];
	@:noCompletion inline function get_events():Array<EventData>   return this[1];
	@:noCompletion inline function set_strumTime(v):Float		   return this[0] = v;
	@:noCompletion inline function set_events(v):Array<EventData>  return this[1] = v;
}

abstract EventData(Array<String>) from Array<String> to Array<String>
{
	public var name(get, set):String;
	public var value1(get, set):String;
	public var value2(get, set):String;

	@:noCompletion inline function get_name():String	 return this[0];
	@:noCompletion inline function get_value1():String	 return this[1];
	@:noCompletion inline function get_value2():String	 return this[2];
	@:noCompletion inline function set_name(v):String	 return this[0] = v;
	@:noCompletion inline function set_value1(v):String	 return this[1] = v;
	@:noCompletion inline function set_value2(v):String	 return this[2] = v;
}
