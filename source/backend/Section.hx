package backend;

import flixel.util.typeLimit.OneOfThree;
import haxe.extern.EitherType;

typedef SwagSection =
{
	var sectionNotes:Array<NoteData>;
	var sectionBeats:Float;
	var mustHitSection:Bool;
	var gfSection:Bool;
	var bpm:Float;
	var changeBPM:Bool;
	var altAnim:Bool;
}

@:allow(backend.Song)
class Section
{
	static final validFields = Type.getInstanceFields(Section);
	static final ignoreList = ["typeOfSection", "lengthInSteps"]; // deleted fields (they were useless lmaooo)
	// simple pool system
	static final __pool = new Array<Section>();
	// @:noCompletion static var instanceCount = 0;

	inline public static function get(?data:SwagSection):Section
	{
		return __pool.length == 0 ? new Section(data) : __pool.pop().load(data);
	}

	public var sectionNotes:Array<NoteData>;
	public var sectionBeats:Float;
	public var gfSection:Bool;
	public var mustHitSection:Bool;
	public var bpm:Float;
	public var changeBPM:Bool;
	public var altAnim:Bool;

	public function new(?data:SwagSection)
	{
		// trace("new Section instance was created! [" + ++instanceCount + "]");
		load(data);
	}

	public function load(data:SwagSection):Section
	{
		reset();
		if (data != null)
			for (field in Reflect.fields(data))
			{
				if (validFields.contains(field))
					Reflect.setField(this, field, Reflect.field(data, field));
				else
				{
					if (!ignoreList.contains(field))
						GameLog.notice('WARNING!! This section have invalid field "$field"');
					Reflect.deleteField(data, field);
				}
			}

		return this;
	}

	public function reset():Section
	{
		/*if (sectionNotes != null)
		{
			var a:Array<Dynamic>;
			while (sectionNotes.length != 0)
			{
				a = sectionNotes.pop();
				if (a != null)
					while (a.length != 0)
						a.pop();
			}
		}*/
		sectionNotes = null;

		bpm = 100.0;
		sectionBeats = 4.0;
		mustHitSection = true;
		gfSection = false;
		changeBPM = false;
		altAnim = false;
		return this;
	}

	public function copyFrom(data:Section):Section
	{
		if (data != null)
		{
			if (sectionNotes == null)	
				sectionNotes = [for (noteData in data.sectionNotes) noteData.copy()];
			else
			{
				while (sectionNotes.length > data.sectionNotes.length)
					sectionNotes.pop();

				var __noteData:NoteData;
				for (i => noteData in data.sectionNotes)
				{
					__noteData = sectionNotes[i];
					if (__noteData == null)
						sectionNotes[i] = noteData.copy();
					else
					{
						__noteData.strumTime	 = noteData.strumTime;
						__noteData.noteData		 = noteData.noteData;
						__noteData.sustainLength = noteData.sustainLength;
						__noteData.noteType		 = noteData.noteType;
					}
				}
			}
			sectionBeats = data.sectionBeats;
			gfSection = data.gfSection;
			mustHitSection = data.mustHitSection;
			bpm = data.bpm;
			changeBPM = data.changeBPM;
			altAnim = data.altAnim;
		}
		return this;
	}
}

abstract NoteData(Array<OneOfThree<Float, Int, String>>) from Array<OneOfThree<Float, Int, String>> to Array<OneOfThree<Float, Int, String>>
{
	public var strumTime(get, set):Float;
	public var noteData(get, set):Int;
	public var sustainLength(get, set):Float;
	public var noteType(get, set):EitherType<String, Int>;

	inline public function copy():NoteData
	{
		return this.copy();
	}

	@:noCompletion inline function get_strumTime():Float					return this[0];
	@:noCompletion inline function get_noteData():Int						return this[1];
	@:noCompletion inline function get_sustainLength():Float				return this[2];
	@:noCompletion inline function get_noteType():EitherType<String, Int>	return this[3];
	@:noCompletion inline function set_strumTime(v):Float					return this[0] = v;
	@:noCompletion inline function set_noteData(v):Int						return this[1] = v;
	@:noCompletion inline function set_sustainLength(v):Float				return this[2] = v;
	@:noCompletion inline function set_noteType(v):EitherType<String, Int>	return this[3] = v;
}
