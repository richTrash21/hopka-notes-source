package psychlua;

#if HSCRIPT_ALLOWED
import psychlua.FunkinLua;
import psychlua.CustomSubstate;

import hscript.Parser;
import hscript.Interp;

/**
	ALL OF THIS (+ some hscript related fixes in PlayState) ARE FROM https://github.com/ShadowMario/FNF-PsychEngine/pull/13304
	MY ONLY CONTRIBUTIONS ARE MORE FUNCTIONS FOR CustomFlxColor
	UPD: i lied a bit whoops 🤷‍♀️🤷‍♀️
	@richTrash21
**/
@:access(hscript.Interp)
class HScript extends flixel.FlxBasic
{
	public static function initHaxeModule(parent:FunkinLua)
	{
		if (parent.hscript != null)
			return;

		var times = openfl.Lib.getTimer();
		parent.hscript = new HScript(parent);
		times = openfl.Lib.getTimer() - times;
		trace("initialized hscript interp successfully: " + parent.scriptName + " [" + (times == 0 ? "instantly" : times + "ms") + "]");
	}

	public static function initHaxeModuleCode(parent:FunkinLua, code:String)
	{
		initHaxeModule(parent);
		if (parent.hscript != null)
			parent.hscript.executeCode(code);
	}

	#if LUA_ALLOWED
	public static function implement(funk:FunkinLua)
	{
		funk.addLocalCallback("runHaxeCode", (codeToRun:String, ?varsToBring:Any, ?funcToRun:String, ?funcArgs:Array<Dynamic>) ->
		{
			initHaxeModule(funk);
			if (!(funk.hscript.exists || funk.hscript.active))
				return null;

			if (varsToBring != null)
			{
				for (key in Reflect.fields(varsToBring))
				{
					//trace('Key $key: ' + Reflect.field(varsToBring, key));
					funk.hscript.interp.setVar(key, Reflect.field(varsToBring, key));
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
				funk.hscript.kill();
				FunkinLua.luaTrace('ERROR (${funk.lastCalledFunction}) - ${funk.hscript.exception}', false, false, FlxColor.RED);
			}
			return retVal;
		});

		funk.addLocalCallback("runHaxeFunction", (funcToRun:String, ?funcArgs:Array<Dynamic>) ->
		{
			if (!(funk.hscript.exists || funk.hscript.active))
				return null;

			final retVal:Dynamic = funk.hscript.executeFunction(funcToRun, funcArgs);
			if (funk.hscript.exception != null)
			{
				funk.hscript.kill();
				FunkinLua.luaTrace('ERROR (${funk.lastCalledFunction}) - ${funk.hscript.exception}', false, false, FlxColor.RED);
			}
			return retVal;
		});
		// This function is unnecessary because import already exists in hscript-improved as a native feature
		funk.addLocalCallback("addHaxeLibrary", (libName:String, ?libPackage:String) ->
		{
			initHaxeModule(funk);
			if (!(funk.hscript.exists || funk.hscript.active))
				return;

			if (libName == null)
				libName = "";
			try
			{
				funk.hscript.interp.setVar(libName, resolveClassOrEnum((libPackage.isNullOrEmpty()) ? libName : '$libPackage.$libName'));
			}
			catch(e)
			{
				funk.hscript.kill();
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

	public static function preset(hscript:HScript)
	{
		final game = PlayState.instance;
		hscript.parser = new Parser();
		hscript.interp = new Interp();
		hscript.parser.allowJSON = hscript.parser.allowMetadata = hscript.parser.allowTypes = true;
		hscript.interp.scriptObject = game; // allow use vars from playstate without "game" thing

		// for closing scripts
		hscript.interp.setVar("close", hscript.kill);

		// classes from SScript (rip)
		hscript.interp.setVar("Date",		  Date);
		hscript.interp.setVar("DateTools",	  DateTools);
		hscript.interp.setVar("Math",		  Math);
		hscript.interp.setVar("Reflect",	  Reflect);
		hscript.interp.setVar("Std",		  Std);
		hscript.interp.setVar("HScript",	  HScript);
		hscript.interp.setVar("StringTools",  StringTools);
		hscript.interp.setVar("Type",		  Type);
		#if sys
		hscript.interp.setVar("File",		  sys.io.File);
		hscript.interp.setVar("FileSystem",	  sys.FileSystem);
		hscript.interp.setVar("Sys",		  Sys);
		#end
		hscript.interp.setVar("Assets",		  openfl.Assets);

		// Some very commonly used classes
		hscript.interp.setVar("FlxG",			   flixel.FlxG);
		hscript.interp.setVar("FlxSprite",		   flixel.FlxSprite);
		hscript.interp.setVar("FlxCamera",		   flixel.FlxCamera);
		hscript.interp.setVar("FlxTimer",		   flixel.util.FlxTimer);
		hscript.interp.setVar("FlxTween",		   flixel.tweens.FlxTween);
		hscript.interp.setVar("FlxEase",		   flixel.tweens.FlxEase);
		hscript.interp.setVar("FlxColor",		   Type.resolveClass("flixel.util.FlxColor_HSC")); // LMAOOOOOOOO - rich
		hscript.interp.setVar("FlxPoint",		   Type.resolveClass("flixel.math.FlxPoint_HSC")); // LMAOOOOOOOO - rich (again)
		hscript.interp.setVar("PlayState",		   PlayState);
		hscript.interp.setVar("Paths",			   Paths);
		hscript.interp.setVar("Conductor",		   Conductor);
		hscript.interp.setVar("ClientPrefs",	   ClientPrefs);
		hscript.interp.setVar("ExtendedSprite",	   objects.ExtendedSprite);
		hscript.interp.setVar("Character",		   objects.Character);
		hscript.interp.setVar("Alphabet",		   Alphabet);
		hscript.interp.setVar("Note",			   objects.Note);
		hscript.interp.setVar("CustomSubstate",	   CustomSubstate);
		hscript.interp.setVar("Countdown",		   backend.BaseStage.Countdown);
		#if (!flash && sys)
		hscript.interp.setVar("FlxRuntimeShader",  flixel.addons.display.FlxRuntimeShader);
		#end
		hscript.interp.setVar("ShaderFilter",	   openfl.filters.ShaderFilter);

		// Functions & Variables
		hscript.interp.setVar("setVar",		 game.variables.set);
		hscript.interp.setVar("getVar",		 game.variables.get);
		hscript.interp.setVar("removeVar",	 game.variables.remove);
		hscript.interp.setVar("debugPrint",	 Reflect.makeVarArgs((a) ->
		{
			var c:Null<FlxColor> = null;
			if (a.length > 1 && a[a.length-1] is Int)
				c = a.pop();

			game.addTextToDebug(a.join(", "), c, hscript.interp.posInfos());
		}));

		// For adding your own callbacks

		// not very tested but should work
		hscript.interp.setVar("createGlobalCallback", (name:String, func:Dynamic) ->
		{
			#if LUA_ALLOWED
			for (script in game.luaArray)
				if (script != null && script.lua != null && !script.closed)
					script.set(name, func);
			#end
			FunkinLua.customFunctions.set(name, func);
		});

		// tested
		hscript.interp.setVar("createCallback", (name:String, func:Dynamic, ?funk:FunkinLua) ->
		{
			if (funk == null)
				funk = hscript.parentLua;

			if (funk == null)
				FunkinLua.luaTrace('createCallback ($name): 3rd argument is null', false, false, FlxColor.RED);
			else
				funk.addLocalCallback(name, func);
		});

		hscript.interp.setVar("addHaxeLibrary", (libName:String, ?libPackage:String) ->
		{
			var str = "";
			if (!libPackage.isNullOrEmpty())
				str += '$libPackage.';
			str += libName;
			hscript.interp.setVar(libName, resolveClassOrEnum(str));
		});
		hscript.interp.setVar("parentLua",				hscript.parentLua);
		hscript.interp.setVar("this",					hscript);
		hscript.interp.setVar("game",					game); // useless cuz u can get vars directly, backward compatibility ig
		hscript.interp.setVar("buildTarget",			LuaUtils.getBuildTarget());
		hscript.interp.setVar("CustomSubstate",			CustomSubstate); // better than bottom ones
		hscript.interp.setVar("customSubstate",			CustomSubstate.instance);
		hscript.interp.setVar("customSubstateName",		CustomSubstate.name);

		hscript.interp.setVar("Function_Stop",			FunkinLua.Function_Stop);
		hscript.interp.setVar("Function_Continue",		FunkinLua.Function_Continue);
		hscript.interp.setVar("Function_StopLua",		FunkinLua.Function_StopLua); // doesnt do much cuz HScript has a lower priority than Lua
		hscript.interp.setVar("Function_StopHScript",	FunkinLua.Function_StopHScript);
		hscript.interp.setVar("Function_StopAll",		FunkinLua.Function_StopAll);
	}

	public var origin:String;
	public var parser:Parser;
	public var interp:Interp;
	public var parentLua:FunkinLua;
	public var exception:haxe.Exception;

	public function new(?parent:FunkinLua, ?file:String)
	{
		super();
		visible = false;

		final content = (file.isNullOrEmpty() ? null : Paths.getTextFromFile(file, false, true));
		parentLua = parent;
		if (parent != null)
			origin = parent.scriptName;
		if (content != null)
			origin = file;

		preset(this);
		executeCode(content);
	}

	public function executeCode(?codeToRun:String):Dynamic
	{
		if (exists && active && codeToRun != null)
		{
			try
			{
				return interp.execute(parser.parseString(codeToRun, origin));
			}
			catch(e)
				exception = e;
		}
		return null;
	}

	public function executeFunction(?funcToRun:String, ?funcArgs:Array<Dynamic>):Dynamic
	{
		if (exists && active && funcToRun != null && interp.variables.exists(funcToRun))
		{
			try
			{
				return Reflect.callMethod(null, interp.variables.get(funcToRun), funcArgs ?? []) ?? FunkinLua.Function_Continue;
			}
			catch(e)
				exception = e;
		}
		return FunkinLua.Function_Continue;
	}

	override public function toString():String
	{
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("origin", origin),
			LabelValuePair.weak("parentLua", parentLua),
			LabelValuePair.weak("active", active),
			LabelValuePair.weak("alive", alive),
			LabelValuePair.weak("exists", exists),
			LabelValuePair.weak("exception", exception)
		]);
	}

	override public function destroy()
	{
		super.destroy();
		origin = null;
		parentLua = null;
		exception = null;

		if (parser != null)
		{
			parser.preprocesorValues.clear();
			parser.opRightAssoc.clear();
			parser.opPriority.clear();
			parser = null;
		}

		if (interp != null)
		{
			@:bypassAccessor
			interp.scriptObject = null;
			interp.__instanceFields.clearArray();
			interp.importBlocklist.clearArray();
			interp.declared.clearArray();
			interp.locals.clear();
			interp.binops.clear();
			interp = null;
		}
	}

	// yeah fuck you
	@:noCompletion override function get_camera():FlxCamera			  throw "Don't reference \"camera\" in HScript instance!";
	@:noCompletion override function set_camera(_):FlxCamera		  throw "Don't reference \"camera\" in HScript instance!";
	@:noCompletion override function get_cameras():Array<FlxCamera>	  throw "Don't reference \"cameras\" in HScript instance!";
	@:noCompletion override function set_cameras(_):Array<FlxCamera>  throw "Don't reference \"cameras\" in HScript instance!";

	#if FLX_DEBUG
	override public function update(elapsed:Float) {}
	override public function draw() {}
	#end
}
#end
