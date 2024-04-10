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

/*@:structInit*/ class Section
{
	@:allow(backend.Song)
	static final validFields = Type.getInstanceFields(Section);
	static final ignoreList = ["typeOfSection", "lengthInSteps"]; // deleted fields (they were useless lmaooo)

	public var sectionNotes:Array<NoteData>;
	public var sectionBeats:Float = 4;
	public var gfSection:Bool;
	public var mustHitSection:Bool = true;
	public var bpm:Float = 100;
	public var changeBPM:Bool;
	public var altAnim:Bool;

	public function new(section:SwagSection)
	{
		for (field in Reflect.fields(section))
		{
			if (validFields.contains(field))
				Reflect.setField(this, field, Reflect.field(section, field));
			else
			{
				if (!ignoreList.contains(field))
					trace('WARNING!! This section have invalid field "$field"');
				Reflect.deleteField(section, field);
			}
		}
	}
}

abstract NoteData(Array<OneOfThree<Float, Int, String>>) from Array<OneOfThree<Float, Int, String>> to Array<OneOfThree<Float, Int, String>>
{
	public var strumTime(get, set):Float;
	public var noteData(get, set):Int;
	public var sustainLength(get, set):Float;
	public var noteType(get, set):EitherType<String, Int>;

	@:noCompletion inline function get_strumTime():Float					return this[0];
	@:noCompletion inline function get_noteData():Int						return this[1];
	@:noCompletion inline function get_sustainLength():Float				return this[2];
	@:noCompletion inline function get_noteType():EitherType<String, Int>	return this[3];
	@:noCompletion inline function set_strumTime(v):Float					return this[0] = v;
	@:noCompletion inline function set_noteData(v):Int						return this[1] = v;
	@:noCompletion inline function set_sustainLength(v):Float				return this[2] = v;
	@:noCompletion inline function set_noteType(v):EitherType<String, Int>	return this[3] = v;
}
