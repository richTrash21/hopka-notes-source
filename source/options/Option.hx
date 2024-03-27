package options;

class Option implements flixel.util.FlxDestroyUtil.IFlxDestroyable
{
	public var child:Alphabet;
	public var text(get, set):String;
	//public var onChange:()->Void;					// Pressed enter (on Bool type options) or pressed/held left/right (on other types)

	public var type(get, default):String = "bool";	// bool, int (or integer), float (or fl), percent, string (or str)
													// Bool will use checkboxes
													// Everything else will use a text

	public var scrollSpeed:Float = 50;				// Only works on int/float, defines how fast it scrolls per second while holding left/right
	private var variable:String;					// Variable from ClientPrefs.hx
	public var defaultValue:Dynamic;

	public var curOption:Int = 0;					// Don't change this
	public var options:Array<String>;				// Only used in string type
	public var changeValue:Dynamic = 1;				// Only used in int/float/percent type, how much is changed when you PRESS
	public var minValue:Dynamic;					// Only used in int/float/percent type
	public var maxValue:Dynamic;					// Only used in int/float/percent type
	public var decimals:Int = 1;					// Only used in float/percent type

	public var displayFormat:String = "%v";			// How String/Float/Percent/Int values are shown, %v = Current value, %d = Default value
	public var description:String = "";
	public var name:String = "Unknown";

	public var value(get, set):Dynamic;

	public function new(name:String, description:String = "", variable:String, type:String = "bool", ?options:Array<String>)
	{
		this.name = name;
		this.description = description;
		this.variable = variable;
		this.type = type;
		this.defaultValue = Reflect.getProperty(ClientPrefs.defaultData, variable);
		this.options = options;

		if (defaultValue == "null variable value")
		{
			switch(type)
			{
				case "bool":		  defaultValue = false;
				case "int" | "float": defaultValue = 0;
				case "percent":		  defaultValue = 1;
				case "string":		  defaultValue = (options.length > 0) ? options[0] : "";
			}
		}

		if (value == null) value = defaultValue;

		switch(type)
		{
			case "string":
				final num:Int = options.indexOf(value);
				if(num > -1) curOption = num;
	
			case "percent":
				displayFormat = "%v%";
				changeValue = 0.01;
				minValue = 0;
				maxValue = 1;
				scrollSpeed = 0.5;
				decimals = 2;
		}
	}

	dynamic public function change() {}

	public function destroy()
	{
		options = null;
		child = null;
		defaultValue = null;
		changeValue = null;
		minValue = null;
		maxValue = null;
	}

	public function get_value():Dynamic
	{
		return Reflect.getProperty(ClientPrefs.data, variable);
	}

	public function set_value(val:Dynamic):Dynamic
	{
		Reflect.setProperty(ClientPrefs.data, variable, val);
		return val;
	}

	function get_text():String
	{
		return child?.text;

	}
	function set_text(newValue:String):String
	{
		return child == null ? null : child.text = newValue;
	}

	function get_type()
	{
		final newValue:String = switch(type.toLowerCase().trim())
			{
				case "int" | "float" | "percent" | "string": type;
				case "integer":	"int";
				case "str":		"string";
				case "fl":		"float";
				default:		"bool";
			}
		return type = newValue;
	}
}