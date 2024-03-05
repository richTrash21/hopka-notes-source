package psychlua;

/*enum abstract FunctionReturn(Null<Int>) from Null<Int> from Int to Int
{
	var CONTINUE	  = 0x000;
	var STOP		  = 0x001;
	var STOP_LUA	  = 0x011;
	var STOP_HSCRIPT  = 0x101;
	var STOP_ALL	  = 0x111;

	public var stop(get, never):Bool;
	public var lua(get, never):Bool;
	public var hscript(get, never):Bool;

	inline function get_stop():Bool		return this != null && (this & 0xf) == 1;
	inline function get_lua():Bool		return this != null && ((this >> 4) & 0xf) == 1;
	inline function get_hscript():Bool	return this != null && ((this >> 8) & 0xf) == 1;

	@:to inline function toString():String
	{
		return "##PSYCHLUA_FUNCTION" + switch (cast (this : FunctionReturn))
		{
			case CONTINUE:		"CONTINUE";
			case STOP:			"STOP";
			case STOP_LUA:		"STOPLUA";
			case STOP_HSCRIPT:	"STOPHSCRIPT";
			case STOP_ALL:		"STOPALL";
			default:			null;
		}
	}

	@:from inline static function fromString(s:String):FunctionReturn
	{
		return switch (s.contains("##PSYCHLUA_FUNCTION") ? s.substr(19) : s)
		{
			case "CONTINUE":	 CONTINUE;
			case "STOP":		 STOP;
			case "STOPLUA":		 STOP_LUA;
			case "STOPHSCRIPT":	 STOP_HSCRIPT;
			case "STOPALL":		 STOP_ALL;
			default:			 null;
		}
	}
}*/
