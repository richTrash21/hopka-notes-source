package backend;

typedef SwagSection =
{
	var sectionNotes:Array<Dynamic>;
	var sectionBeats:Float;
	var typeOfSection:Int;
	var mustHitSection:Bool;
	var gfSection:Bool;
	var bpm:Float;
	var changeBPM:Bool;
	var altAnim:Bool;
}

/*@:structInit*/ class Section
{
	/**
	 *	Copies the first section into the second section!
	 */
	// public static var COPYCAT:Int = 0;
	public static final validFields = Type.getInstanceFields(Section);

	public var sectionNotes:Array<Dynamic> = [];
	public var sectionBeats:Float = 4;
	public var gfSection:Bool = false;
	public var typeOfSection:Int = 0;
	public var mustHitSection:Bool = true;
	public var bpm:Float = 100;
	public var changeBPM:Bool = false;
	public var altAnim:Bool = false;

	public function new(section:SwagSection)
	{
		for (field in Reflect.fields(section))
		{
			if (validFields.contains(field))
				Reflect.setField(this, field, Reflect.field(section, field));
			else
			{
				trace('WARNING!! This section have invalid field "$field"');
				Reflect.deleteField(section, field);
			}
		}
	}
}
