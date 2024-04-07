package psychlua;

#if HSCRIPT_ALLOWED
import flixel.FlxBasic;
import psychlua.FunkinLua;
import psychlua.CustomSubstate;

import hscript.Parser;
import hscript.Interp;

/**
	ALL OF THIS (+ some hscript related fixes in PlayState) ARE FROM https://github.com/ShadowMario/FNF-PsychEngine/pull/13304
	MY ONLY CONTRIBUTIONS ARE MORE FUNCTIONS FOR CustomFlxColor
	@richTrash21
**/
class HScript extends Interp
{
	public static function initHaxeModule(parent:FunkinLua)
	{
		if (parent.hscript != null)
			return;

		final times = Date.now().getTime();
		parent.hscript = new HScript(parent);
		trace('initialized hscript interp successfully: ${parent.scriptName} (${Std.int(Date.now().getTime() - times)}ms)');
	}

	public static function initHaxeModuleCode(parent:FunkinLua, code:String)
	{
		initHaxeModule(parent);
		if (parent.hscript != null)
			parent.hscript.executeCode(code);
	}

	inline public static function hscriptTrace(text:String, color = FlxColor.WHITE)
	{
		PlayState.instance.addTextToDebug(text, color);
	}

	public var origin:String;
	public var active:Bool = true;
	public var parser:Parser;
	public var parentLua:FunkinLua;
	public var exception:haxe.Exception;

	public function new(?parent:FunkinLua, ?file:String)
	{
		super();

		final content:String = (file == null ? null : Paths.getTextFromFile(file, false, true));
		parentLua = parent;
		if (parent != null)
			origin = parent.scriptName;
		if (content != null)
			origin = file;

		preset();
		executeCode(content);
	}

	function preset()
	{
		parser = new Parser();
		parser.allowJSON = parser.allowMetadata = parser.allowTypes = true;
		scriptObject = PlayState.instance; // allow use vars from playstate without "game" thing

		// for closing scripts
		setVar("close", function() active = false);

		// classes from SScript (rip)
		setVar("Date",			Date);
		setVar("DateTools",		DateTools);
		setVar("Math",			Math);
		setVar("Reflect",		Reflect);
		setVar("Std",			Std);
		setVar("HScript",		HScript);
		setVar("StringTools",	StringTools);
		setVar("Type",			Type);
		#if sys
		setVar("File",			sys.io.File);
		setVar("FileSystem",	sys.FileSystem);
		setVar("Sys",			Sys);
		#end
		setVar("Assets",		openfl.Assets);

		// Some very commonly used classes
		setVar("FlxG",				flixel.FlxG);
		setVar("FlxSprite",			flixel.FlxSprite);
		setVar("FlxCamera",			flixel.FlxCamera);
		setVar("FlxTimer",			flixel.util.FlxTimer);
		setVar("FlxTween",			flixel.tweens.FlxTween);
		setVar("FlxEase",			flixel.tweens.FlxEase);
		setVar("FlxColor",			Type.resolveClass("flixel.util.FlxColor_HSC")); // LMAOOOOOOOO - rich
		setVar("FlxPoint",			Type.resolveClass("flixel.math.FlxPoint_HSC")); // LMAOOOOOOOO - rich (again)
		setVar("PlayState",			PlayState);
		setVar("Paths",				Paths);
		setVar("Conductor",			Conductor);
		setVar("ClientPrefs",		ClientPrefs);
		setVar("ExtendedSprite",	objects.ExtendedSprite);
		setVar("Character",			objects.Character);
		setVar("Alphabet",			Alphabet);
		setVar("Note",				objects.Note);
		setVar("CustomSubstate",	CustomSubstate);
		setVar("Countdown",			backend.BaseStage.Countdown);
		#if (!flash && sys)
		setVar("FlxRuntimeShader",	flixel.addons.display.FlxRuntimeShader);
		#end
		setVar("ShaderFilter",		openfl.filters.ShaderFilter);

		// Functions & Variables
		setVar("setVar",	 PlayState.instance.variables.set);
		setVar("getVar",	 PlayState.instance.variables.get);
		setVar("removeVar",	 PlayState.instance.variables.remove);
		setVar("debugPrint", (t:String, c:FlxColor) -> PlayState.instance.addTextToDebug(t, c, posInfos()));

		// For adding your own callbacks

		// not very tested but should work
		setVar("createGlobalCallback", function(name:String, func:Dynamic)
		{
			#if LUA_ALLOWED
			for (script in PlayState.instance.luaArray)
				if (script != null && script.lua != null && !script.closed)
					script.set(name, func);
			#end
			FunkinLua.customFunctions.set(name, func);
		});

		// tested
		setVar("createCallback", (name:String, func:Dynamic, ?funk:FunkinLua) ->
		{
			if (funk == null)
				funk = parentLua;

			if (funk == null)
				FunkinLua.luaTrace('createCallback ($name): 3rd argument is null', false, false, FlxColor.RED);
			else
				funk.addLocalCallback(name, func);
		});

		setVar("addHaxeLibrary", (libName:String, ?libPackage:String = "") ->
		{
			var str = "";
			if (!libPackage.isNullOrEmpty())
				str += '$libPackage.';
			str += libName;
			setVar(libName, resolveClassOrEnum(str));
		});
		setVar("parentLua",				parentLua);
		setVar("this",					this);
		setVar("game",					PlayState.instance); // useless cuz u can get vars directly, backward compatibility ig
		setVar("buildTarget",			LuaUtils.getBuildTarget());
		setVar("customSubstate",		CustomSubstate.instance);
		setVar("customSubstateName",	CustomSubstate.name);

		setVar("Function_Stop",			FunkinLua.Function_Stop);
		setVar("Function_Continue",		FunkinLua.Function_Continue);
		setVar("Function_StopLua",		FunkinLua.Function_StopLua); // doesnt do much cuz HScript has a lower priority than Lua
		setVar("Function_StopHScript",	FunkinLua.Function_StopHScript);
		setVar("Function_StopAll",		FunkinLua.Function_StopAll);
	}

	public function executeCode(?codeToRun:String):Dynamic
	{
		if (codeToRun == null || !active)
			return null;

		try
		{
			return execute(parser.parseString(codeToRun, origin));
		}
		catch(e)
			exception = e;

		return null;
	}

	public function executeFunction(?funcToRun:String, ?funcArgs:Array<Dynamic>):Dynamic
	{
		if (active && funcToRun != null && variables.exists(funcToRun))
		{
			try
			{
				return Reflect.callMethod(null, variables.get(funcToRun), funcArgs ?? []) ?? FunkinLua.Function_Continue;
			}
			catch(e)
				exception = e;
		}
		return FunkinLua.Function_Continue;
	}

	#if LUA_ALLOWED
	public static function implement(funk:FunkinLua)
	{
		funk.addLocalCallback("runHaxeCode", (codeToRun:String, ?varsToBring:Any, ?funcToRun:String, ?funcArgs:Array<Dynamic>) ->
		{
			initHaxeModule(funk);
			if (!funk.hscript.active)
				return null;

			if (varsToBring != null)
			{
				for (key in Reflect.fields(varsToBring))
				{
					//trace('Key $key: ' + Reflect.field(varsToBring, key));
					funk.hscript.setVar(key, Reflect.field(varsToBring, key));
				}
			}

			var retVal:Dynamic = funk.hscript.executeCode(codeToRun);
			if (funcToRun != null)
			{
				final retFunc:Dynamic = funk.hscript.executeFunction(funcToRun, funcArgs);
				if (retFunc != null)
					retVal = retFunc;
			}

			if (funk.hscript.exception != null)
			{
				funk.hscript.active = false;
				FunkinLua.luaTrace('ERROR (${funk.lastCalledFunction}) - ${funk.hscript.exception}', false, false, FlxColor.RED);
			}
			return retVal;
		});

		funk.addLocalCallback("runHaxeFunction", (funcToRun:String, ?funcArgs:Array<Dynamic>) ->
		{
			if (!funk.hscript.active)
				return null;

			final retVal:Dynamic = funk.hscript.executeFunction(funcToRun, funcArgs);
			if (funk.hscript.exception != null)
			{
				funk.hscript.active = false;
				FunkinLua.luaTrace('ERROR (${funk.lastCalledFunction}) - ${funk.hscript.exception}', false, false, FlxColor.RED);
			}

			return retVal;
		});
		// This function is unnecessary because import already exists in hscript-improved as a native feature
		funk.addLocalCallback("addHaxeLibrary", (libName:String, ?libPackage:String) ->
		{
			initHaxeModule(funk);
			if (!funk.hscript.active)
				return;

			if (libName == null)
				libName = "";
			try
			{
				funk.hscript.setVar(libName, resolveClassOrEnum((libPackage == null || libPackage.length == 0) ? libName : '$libPackage.$libName'));
			}
			catch(e)
			{
				funk.hscript.active = false;
				FunkinLua.luaTrace('ERROR (${funk.lastCalledFunction}) - $e', false, false, FlxColor.RED);
			}
		});
	}
	#end

	inline public static function resolveClassOrEnum(name:String):Dynamic
	{
		final c:Dynamic = Type.resolveClass(name);
		return c ?? Type.resolveEnum(name);
	}

	public function destroy()
	{
		active = false;
		parser = null;
		origin = null;
		parentLua = null;
		__instanceFields = [];
		binops.clear();
		customClasses.clear();
		declared = [];
		importBlocklist = [];
		locals.clear();
		resetVariables();
	}
}

/*private class CustomFlxColor
{
	public static final TRANSPARENT = FlxColor.TRANSPARENT;
	public static final BLACK       = FlxColor.BLACK;
	public static final WHITE       = FlxColor.WHITE;
	public static final GRAY        = FlxColor.GRAY;
	public static final GREEN       = FlxColor.GREEN;
	public static final LIME        = FlxColor.LIME;
	public static final YELLOW      = FlxColor.YELLOW;
	public static final ORANGE      = FlxColor.ORANGE;
	public static final RED         = FlxColor.RED;
	public static final PURPLE      = FlxColor.PURPLE;
	public static final BLUE        = FlxColor.BLUE;
	public static final BROWN       = FlxColor.BROWN;
	public static final PINK        = FlxColor.PINK;
	public static final MAGENTA     = FlxColor.MAGENTA;
	public static final CYAN        = FlxColor.CYAN;

	public static function fromRGB(red:Int, green:Int, blue:Int, alpha:Int = 255):Int
	{
		return FlxColor.fromRGB(red, green, blue, alpha);
	}
	public static function fromRGBFloat(red:Float, green:Float, blue:Float, alpha:Float = 1):Int
	{
		return FlxColor.fromRGBFloat(red, green, blue, alpha);
	}

	public static function fromCMYK(cyan:Float, magenta:Float, yellow:Float, black:Float, alpha:Float = 1):Int
	{
		return FlxColor.fromCMYK(cyan, magenta, yellow, black, alpha);
	}
	public static function fromHSB(hue:Float, sat:Float, brt:Float, alpha:Float = 1):Int
	{
		return FlxColor.fromHSB(hue, sat, brt, alpha);
	}
	public static function fromHSL(hue:Float, sat:Float, light:Float, alpha:Float = 1):Int
	{
		return FlxColor.fromHSL(hue, sat, light, alpha);
	}
	public static function fromString(str:String):Int
	{
		return FlxColor.fromString(str);
	}

	public static function getHSBColorWheel(alpha:Int = 255):Array<Int>
	{
		return FlxColor.getHSBColorWheel(alpha);
	}
	public static function interpolate(color1:Int, color2:Int, factor:Float = 0.5):Int
	{
		return FlxColor.interpolate(color1, color2, factor);
	}
	public static function gradient(color1:FlxColor, color2:FlxColor, steps:Int, ?ease:Float->Float):Array<Int>
	{
		return FlxColor.gradient(color1, color2, steps, ease);
	}

	public static function multiply(lhs:Int, rhs:Int):Int
	{
		return FlxColor.multiply(lhs, rhs);
	}
	public static function add(lhs:Int, rhs:Int):Int
	{
		return FlxColor.add(lhs, rhs);
	}
	public static function subtract(lhs:Int, rhs:Int):Int
	{
		return FlxColor.subtract(lhs, rhs);
	}
}*/
#end
