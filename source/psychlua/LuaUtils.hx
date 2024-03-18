package psychlua;

import flixel.math.FlxPoint;
import openfl.display.BlendMode;
import animateatlas.AtlasFrameMaker;

#if LUA_ALLOWED
import llua.Lua;
#end

typedef LuaTweenOptions = {
	type:FlxTweenType,
	startDelay:Float,
	?onUpdate:String,
	?onStart:String,
	?onComplete:String,
	loopDelay:Float,
	ease:EaseFunction
}

class LuaUtils
{
	@:allow(Init)
	@:noCompletion static final __easeMap = new Map<String, EaseFunction>();
	@:noCompletion static final __tweenTypeMap = [
		"backward"	=> FlxTweenType.BACKWARD,
		"looping"	=> FlxTweenType.LOOPING,
		"loop"		=> FlxTweenType.LOOPING,
		"persist"	=> FlxTweenType.PERSIST,
		"pingpong"	=> FlxTweenType.PINGPONG,
		"oneshot"	=> FlxTweenType.ONESHOT
	];

	public static function getLuaTween(options:Dynamic):LuaTweenOptions
	{
		return {
			type: getTweenTypeByString(options.type),
			startDelay: options.startDelay,
			onUpdate: options.onUpdate,
			onStart: options.onStart,
			onComplete: options.onComplete,
			loopDelay: options.loopDelay,
			ease: getTweenEaseByString(options.ease)
		};
	}

	public static function setVarInArray(instance:Dynamic, variable:String, value:Dynamic, ?allowMaps = false, ?bypassAccessor = false):Any
	{
		if (value is String)
			value = boolCkeck(value);

		final splitProps = variable.split("[");
		if (splitProps.length > 1)
		{
			var target:Dynamic = null;
			if (PlayState.instance.variables.exists(splitProps[0]))
			{
				var retVal:Dynamic = PlayState.instance.variables.get(splitProps[0]);
				if (retVal != null)
					target = retVal;
			}
			else
				target = bypassAccessor ? Reflect.field(instance, splitProps[0]) : Reflect.getProperty(instance, splitProps[0]);

			for (i in 1...splitProps.length)
			{
				final j:Dynamic = splitProps[i].substr(0, splitProps[i].length - 1);
				if (i >= splitProps.length-1)
					target[j] = value; // Last array
				else
					target = target[j]; // Anything else
			}
			return target;
		}

		if (allowMaps && isMap(instance))
		{
			instance.set(variable, value);
			return value;
		}

		if (PlayState.instance.variables.exists(variable))
		{
			PlayState.instance.variables.set(variable, value);
			return value;
		}
		bypassAccessor ? Reflect.setField(instance, variable, value) : Reflect.setProperty(instance, variable, value);
		return value;
	}

	public static function getVarInArray(instance:Dynamic, variable:String, ?allowMaps = false, ?bypassAccessor = false):Any
	{
		final splitProps = variable.split("[");
		if (splitProps.length > 1)
		{
			var target:Dynamic = null;
			if (PlayState.instance.variables.exists(splitProps[0]))
			{
				var retVal:Dynamic = PlayState.instance.variables.get(splitProps[0]);
				if (retVal != null)
					target = retVal;
			}
			else
				target = bypassAccessor ? Reflect.field(instance, splitProps[0]) : Reflect.getProperty(instance, splitProps[0]);

			for (i in 1...splitProps.length)
			{
				var j:Dynamic = splitProps[i].substr(0, splitProps[i].length - 1);
				target = target[j];
			}
			return target;
		}
		
		if (allowMaps && isMap(instance))
			return instance.get(variable);

		if (PlayState.instance.variables.exists(variable))
		{
			final retVal:Dynamic = PlayState.instance.variables.get(variable);
			if (retVal != null)
				return retVal;
		}
		return bypassAccessor ? Reflect.field(instance, variable) : Reflect.getProperty(instance, variable);
	}
	
	inline public static function isMap(variable:Dynamic):Bool
	{
		return variable is haxe.Constraints.IMap; // variable.exists != null && variable.keyValueIterator != null;
	}

	public static function setGroupStuff(leArray:Dynamic, variable:String, value:Dynamic, ?allowMaps:Bool = false, ?bypassAccessor:Bool = false):Any
	{
		if (value is String)
			value = boolCkeck(value);

		final split = variable.split(".");
		if (split.length > 1)
		{
			var obj:Dynamic = Reflect.getProperty(leArray, split[0]);
			for (i in 1...split.length-1)
				obj = Reflect.getProperty(obj, split[i]);

			leArray = obj;
			variable = split[split.length-1];
		}
		if (allowMaps && isMap(leArray))
			leArray.set(variable, value);
		else
			bypassAccessor ? Reflect.setField(leArray, variable, value) : Reflect.setProperty(leArray, variable, value);

		return value;
	}

	public static function getGroupStuff(leArray:Dynamic, variable:String, ?allowMaps:Bool = false, ?bypassAccessor:Bool = false):Any
	{
		final split = variable.split(".");
		if (split.length > 1)
		{
			var obj:Dynamic = Reflect.getProperty(leArray, split[0]);
			for (i in 1...split.length-1)
				obj = Reflect.getProperty(obj, split[i]);

			leArray = obj;
			variable = split[split.length-1];
		}
		if (allowMaps && isMap(leArray))
			return leArray.get(variable);
	
		return bypassAccessor ? Reflect.field(leArray, variable) : Reflect.getProperty(leArray, variable);
	}

	public static function getPropertyLoop(split:Array<String>, ?checkForTextsToo:Bool = true, ?getProperty:Bool=true, ?allowMaps:Bool = false):Any
	{
		var obj:Dynamic = getObjectDirectly(split[0], checkForTextsToo);
		for (i in 1...(getProperty ? split.length-1 : split.length))
			obj = getVarInArray(obj, split[i], allowMaps);

		return obj;
	}

	inline public static function getObjectDirectly(objectName:String, ?checkForTextsToo = true, ?allowMaps = false):Any
	{
		return switch (objectName)
		{
			case "this" | "instance" | "game":
				PlayState.instance;
			default:
				PlayState.instance.getLuaObject(objectName, checkForTextsToo) ?? getVarInArray(getTargetInstance(), objectName, allowMaps);
		}
	}

	inline public static function getTextObject(name:String):FlxText
	{
		return #if LUA_ALLOWED PlayState.instance.modchartTexts.exists(name) ? PlayState.instance.modchartTexts.get(name) : #end Reflect.getProperty(PlayState.instance, name);
	}

	inline public static function isOfTypes(value:Dynamic, types:Array<Dynamic>)
	{
		for (type in types)
			if (Std.isOfType(value, type))
				return true;

		return false;
	}

	inline public static function boolCkeck(value:String):Any // should fix bool values
	{
		if (value == null)
			return value;

		value = value.toLowerCase();
		return (value == "true" || value == "false") ? value == "true" : value;
	}
	
	public static inline function getTargetInstance()
	{
		return PlayState.instance.isDead ? substates.GameOverSubstate.instance : PlayState.instance;
	}

	public static inline function getLowestCharacterGroup():FlxTypedSpriteGroup<objects.Character>
	{
		var group = PlayState.instance.gfGroup;
		var pos = PlayState.instance.members.indexOf(group);

		var newPos = PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup);
		if (newPos < pos)
		{
			group = PlayState.instance.boyfriendGroup;
			pos = newPos;
		}
		
		newPos = PlayState.instance.members.indexOf(PlayState.instance.dadGroup);
		if (newPos < pos)
		{
			group = PlayState.instance.dadGroup;
			pos = newPos;
		}
		return group;
	}
	
	public static function addAnimByIndices(obj:String, name:String, prefix:String, indices:Any = null, framerate:Int = 24, loop:Bool = false)
	{
		final obj:FlxSprite = getObjectDirectly(obj, false);
		if (obj == null)
			return false;

		if (indices == null)
			indices = [];

		if (Std.isOfType(indices, String))
			indices = [for (i in cast (indices, String).trim().split(",")) Std.parseInt(i)];
		else if (Std.isOfType(indices, Float))
			indices = [Std.int(indices)];
		else if (Std.isOfType(indices, Int))
			indices = [indices];

		obj.animation.addByIndices(name, prefix, indices, "", framerate, loop);
		if (obj.animation.curAnim == null)
		{
			if (obj is ExtendedSprite)
				cast (obj, ExtendedSprite).playAnim(name, true);
			else
				obj.animation.play(name, true);
		}
		return true;
	}

	// for functions taht get point from stuff (aka optimisation)
	static final _lePoint = FlxPoint.get();

	inline public static function getMousePoint(camera:String, y:Bool):Float
	{
		FlxG.mouse.getScreenPosition(cameraFromString(camera), _lePoint);
		return y ? _lePoint.y : _lePoint.x;
	}

	inline public static function getPoint(leVar:String, type:Int, y:Bool, ?camera:String):Float
	{
		final split:Array<String> = leVar.split(".");
		final obj:FlxSprite = (split.length > 1)
			? getVarInArray(getPropertyLoop(split), split[split.length-1])
			: getObjectDirectly(split[0]);

		if (obj == null)
			return 0;

		switch (type)
		{
			case 1:   obj.getGraphicMidpoint(_lePoint);
			case 2:   obj.getScreenPosition(_lePoint, cameraFromString(camera));
			default:  obj.getMidpoint(_lePoint);
		};
		return y ? _lePoint.y : _lePoint.x;
	}

	inline public static function keyJustPressed(key:String):Bool
	{
		return keyUtil(FlxG.keys.justPressed, key.toUpperCase().trim());
	}

	inline public static function keyPressed(key:String):Bool
	{
		return keyUtil(FlxG.keys.pressed, key.toUpperCase().trim());
	}

	inline public static function keyJustReleased(key:String):Bool
	{
		return keyUtil(FlxG.keys.justReleased, key.toUpperCase().trim());
	}

	inline public static function keyReleased(key:String):Bool
	{
		return keyUtil(FlxG.keys.released, key.toUpperCase().trim());
	}

	inline static function keyUtil(keyList:flixel.input.keyboard.FlxKeyList, key:String):Bool
	{
		return Reflect.getProperty(keyList, key) ?? false;
	}
	
	inline public static function loadFrames(image:String, spriteType:String):flixel.graphics.frames.FlxFramesCollection
	{
		return switch(spriteType.toLowerCase().trim())
		{
			case "texture" | "textureatlas" | "tex":				 AtlasFrameMaker.construct(image);
			case "texture_noaa" | "textureatlas_noaa" | "tex_noaa":	 AtlasFrameMaker.construct(image, true);
			case "packer" | "packeratlas" | "pac":					 Paths.getPackerAtlas(image);
			default:												 Paths.getSparrowAtlas(image);
		}
	}

	public static function resetTextTag(tag:String)
	{
		#if LUA_ALLOWED
		if (PlayState.instance.modchartTexts.exists(tag))
		{
			final target = PlayState.instance.modchartTexts.get(tag);
			target.kill();
			PlayState.instance.remove(target, true).destroy();
			PlayState.instance.modchartTexts.remove(tag);
		}
		#end
	}

	public static function resetSpriteTag(tag:String)
	{
		#if LUA_ALLOWED
		if (PlayState.instance.modchartSprites.exists(tag))
		{
			final target = PlayState.instance.modchartSprites.get(tag);
			target.kill();
			PlayState.instance.remove(target, true).destroy();
			PlayState.instance.modchartSprites.remove(tag);
		}
		#end
	}

	public static function cancelTween(tag:String)
	{
		#if LUA_ALLOWED
		if (PlayState.instance.modchartTweens.exists(tag))
		{
			final leTween = PlayState.instance.modchartTweens.get(tag);
			leTween.cancel();
			leTween.destroy();
			PlayState.instance.modchartTweens.remove(tag);
		}
		#end
	}

	inline public static function tweenPrepare(tag:String, vars:String)
	{
		cancelTween(tag);
		final variables = vars.split(".");
		return (variables.length > 1 ? getVarInArray(getPropertyLoop(variables), variables[variables.length-1]) : getObjectDirectly(variables[0]));
	}

	public static function cancelTimer(tag:String)
	{
		#if LUA_ALLOWED
		if (PlayState.instance.modchartTimers.exists(tag))
		{
			final theTimer = PlayState.instance.modchartTimers.get(tag);
			theTimer.cancel();
			theTimer.destroy();
			PlayState.instance.modchartTimers.remove(tag);
		}
		#end
	}

	// buncho string stuffs
	inline public static function getTweenTypeByString(type:String):FlxTweenType
	{
		return __tweenTypeMap.get(type.toLowerCase().trim()) ?? FlxTweenType.ONESHOT;
		/*return switch (type.toLowerCase().trim())
		{
			case "backward":		FlxTweenType.BACKWARD;
			case "looping"|"loop":	FlxTweenType.LOOPING;
			case "persist":			FlxTweenType.PERSIST;
			case "pingpong":		FlxTweenType.PINGPONG;
			default:				FlxTweenType.ONESHOT;
		}*/
	}

	inline public static function getTweenEaseByString(ease:String):EaseFunction
	{
		return __easeMap.get(ease.toLowerCase().trim()) ?? FlxEase.linear;
		/*return switch (ease.toLowerCase().trim())
		{
			case "backin":				FlxEase.backIn;
			case "backinout":			FlxEase.backInOut;
			case "backout":				FlxEase.backOut;
			case "bouncein":			FlxEase.bounceIn;
			case "bounceinout":			FlxEase.bounceInOut;
			case "bounceout":			FlxEase.bounceOut;
			case "circin":				FlxEase.circIn;
			case "circinout":			FlxEase.circInOut;
			case "circout":				FlxEase.circOut;
			case "cubein":				FlxEase.cubeIn;
			case "cubeinout":			FlxEase.cubeInOut;
			case "cubeout":				FlxEase.cubeOut;
			case "elasticin":			FlxEase.elasticIn;
			case "elasticinout":		FlxEase.elasticInOut;
			case "elasticout":			FlxEase.elasticOut;
			case "expoin":				FlxEase.expoIn;
			case "expoinout":			FlxEase.expoInOut;
			case "expoout":				FlxEase.expoOut;
			case "quadin":				FlxEase.quadIn;
			case "quadinout":			FlxEase.quadInOut;
			case "quadout":				FlxEase.quadOut;
			case "quartin":				FlxEase.quartIn;
			case "quartinout":			FlxEase.quartInOut;
			case "quartout":			FlxEase.quartOut;
			case "quintin":				FlxEase.quintIn;
			case "quintinout":			FlxEase.quintInOut;
			case "quintout":			FlxEase.quintOut;
			case "sinein":				FlxEase.sineIn;
			case "sineinout":			FlxEase.sineInOut;
			case "sineout":				FlxEase.sineOut;
			case "smoothstepin":		FlxEase.smoothStepIn;
			case "smoothstepinout":		FlxEase.smoothStepInOut;
			case "smoothstepout":		FlxEase.smoothStepInOut;
			case "smootherstepin":		FlxEase.smootherStepIn;
			case "smootherstepinout":	FlxEase.smootherStepInOut;
			case "smootherstepout":		FlxEase.smootherStepOut;
			default:					FlxEase.linear;
		}*/
	}

	inline public static function blendModeFromString(blend:String):BlendMode
	{
		return cast (blend.toLowerCase().trim() : BlendMode);
	}
	
	inline public static function typeToString(type:Int):String
	{
		#if LUA_ALLOWED
		return switch (type)
		{
			case Lua.LUA_TBOOLEAN:	 "boolean";
			case Lua.LUA_TNUMBER:	 "number";
			case Lua.LUA_TSTRING:	 "string";
			case Lua.LUA_TTABLE:	 "table";
			case Lua.LUA_TFUNCTION:	 "function";
			default:				 (type <= Lua.LUA_TNIL ? "nil" : "unknown");
		}
		#else
		trace("lua isn't allowed, returning \"null\"!");
		return null;
		#end
	}

	inline public static function cameraFromString(cam:String):FlxCamera
	{
		return (PlayState.instance == null)
			? FlxG.cameras.list[CoolUtil.boundInt(Std.parseInt(cam), 0, FlxG.cameras.list.length-1)]
			: switch(cam.toLowerCase().trim())
				{
					case "camhud" | "hud" | "1":	  PlayState.instance.camHUD;
					case "camother" | "other" | "2":  PlayState.instance.camOther;
					default:						  FlxG.camera;
				}
	}

	//clone functions
	inline public static function getBuildTarget():String
	{
		return	#if windows		"windows"
				#elseif linux	"linux"
				#elseif mac		"mac"
				#elseif html5	"browser"
				#elseif android	"android"
				#elseif switch	"switch"
				#else			"unknown" #end;
	}
}