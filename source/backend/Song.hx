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

@:allow(states.PlayState)
@:allow(states.editors.ChartingState)
/*@:structInit*/ class Song
{
	static final validFields = Type.getInstanceFields(Song);
	// simple pool system
	static final __pool = new Array<Song>();
	// @:noCompletion static var instanceCount = 0;

	public static function loadFromJson(jsonInput:String, ?folder:String, ?song:Song):Song
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

		final data = onLoadJson(parseJSONshit(rawJson));
		if (song == null)
			song = __pool.length == 0 ? new Song(data) : __pool.pop().load(data);
		else
			song.load(data);

		if (jsonInput != "events")
			StageData.loadDirectory(song);
		return song;
	}

	inline public static function parseJSONshit(rawJson:String):SwagSong
	{
		return cast haxe.Json.parse(rawJson).song;
	}

	@:allow(states.editors.ChartingState)
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
	public var bpm:Float;
	public var needsVoices:Bool;
	public var speed:Float;

	public var player1:String;
	public var player2:String;
	public var gfVersion:String;
	public var stage:String;

	public var gameOverChar:Null<String>;
	public var gameOverSound:Null<String>;
	public var gameOverLoop:Null<String>;
	public var gameOverEnd:Null<String>;

	public var arrowSkin:Null<String>;
	public var splashSkin:Null<String>;
	public var disableNoteRGB:Null<Bool>;
	public var swapNotes:Null<Bool>; // for quickly swapping bf and dad notes

	public function new(?data:SwagSong)
	{
		// trace("new Song instance was created! [" + ++instanceCount + "]");
		load(data);
	}

	public function load(data:SwagSong):Song
	{
		reset();
		if (data != null)
			for (field in Reflect.fields(data))
			{
				if (field == "notes")
				{
					notes = [for (section in data.notes) Section.__pool.length == 0 ? new Section(section) : Section.__pool.pop().load(section)];
				}
				else if (validFields.contains(field))
				{
					Reflect.setField(this, field, Reflect.field(data, field));
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
					Reflect.deleteField(data, field);
				}
			}

		return this;
	}

	public function reset():Song
	{
		song = null;

		if (notes != null)
			while (notes.length != 0)
				Section.__pool.push(notes.pop());
		notes = null;

		if (events != null)
			while (events.length != 0)
				events.pop();
		events = null;

		bpm = 100;
		needsVoices = true;
		speed = 1;

		player1 = "bf";
		player2 = "dad";
		gfVersion = "gf";
		stage = "stage";

		gameOverChar = null;
		gameOverSound = null;
		gameOverLoop = null;
		gameOverEnd = null;

		arrowSkin = null;
		splashSkin = null;
		disableNoteRGB = null;
		swapNotes = null;

		return this;
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
