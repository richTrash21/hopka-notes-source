package psychlua;

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
	public static function getLuaTween(options:Dynamic):LuaTweenOptions
	{
		return cast {
			type: getTweenTypeByString(options.type),
			startDelay: options.startDelay,
			onUpdate: options.onUpdate,
			onStart: options.onStart,
			onComplete: options.onComplete,
			loopDelay: options.loopDelay,
			ease: getTweenEaseByString(options.ease)
		};
	}

	public static function setVarInArray(instance:Dynamic, variable:String, value:Dynamic, ?allowMaps:Bool = false, ?bypassAccessor:Bool = false):Any
	{
		if (value is String) value = boolCkeck(value);
		var splitProps:Array<String> = variable.split('[');
		if(splitProps.length > 1)
		{
			var target:Dynamic = null;
			if(PlayState.instance.variables.exists(splitProps[0]))
			{
				var retVal:Dynamic = PlayState.instance.variables.get(splitProps[0]);
				if(retVal != null) target = retVal;
			}
			else target = bypassAccessor ? Reflect.field(instance, splitProps[0]) : Reflect.getProperty(instance, splitProps[0]);

			for (i in 1...splitProps.length)
			{
				var j:Dynamic = splitProps[i].substr(0, splitProps[i].length - 1);
				if(i >= splitProps.length-1) target[j] = value; //Last array
				else target = target[j]; //Anything else
			}
			return target;
		}

		if(allowMaps && isMap(instance))
		{
			instance.set(variable, value);
			return value;
		}

		if(PlayState.instance.variables.exists(variable))
		{
			PlayState.instance.variables.set(variable, value);
			return value;
		}
		bypassAccessor ? Reflect.setField(instance, variable, value) : Reflect.setProperty(instance, variable, value);
		return value;
	}
	public static function getVarInArray(instance:Dynamic, variable:String, ?allowMaps:Bool = false, ?bypassAccessor:Bool = false):Any
	{
		var splitProps:Array<String> = variable.split('[');
		if(splitProps.length > 1)
		{
			var target:Dynamic = null;
			if(PlayState.instance.variables.exists(splitProps[0]))
			{
				var retVal:Dynamic = PlayState.instance.variables.get(splitProps[0]);
				if(retVal != null) target = retVal;
			}
			else target = bypassAccessor ? Reflect.field(instance, splitProps[0]) : Reflect.getProperty(instance, splitProps[0]);

			for (i in 1...splitProps.length)
			{
				var j:Dynamic = splitProps[i].substr(0, splitProps[i].length - 1);
				target = target[j];
			}
			return target;
		}
		
		if(allowMaps && isMap(instance)) return instance.get(variable);

		if(PlayState.instance.variables.exists(variable))
		{
			var retVal:Dynamic = PlayState.instance.variables.get(variable);
			if(retVal != null) return retVal;
		}
		return bypassAccessor ? Reflect.field(instance, variable) : Reflect.getProperty(instance, variable);
	}
	
	public static function isMap(variable:Dynamic):Bool
		return variable.exists != null && variable.keyValueIterator != null;

	public static function setGroupStuff(leArray:Dynamic, variable:String, value:Dynamic, ?allowMaps:Bool = false, ?bypassAccessor:Bool = false)
	{
		if (value is String) value = boolCkeck(value);
		var split:Array<String> = variable.split('.');
		if(split.length > 1)
		{
			var obj:Dynamic = Reflect.getProperty(leArray, split[0]);
			for (i in 1...split.length-1) obj = Reflect.getProperty(obj, split[i]);
			leArray = obj;
			variable = split[split.length-1];
		}
		if(allowMaps && isMap(leArray)) leArray.set(variable, value);
		else bypassAccessor ? Reflect.setField(leArray, variable, value) : Reflect.setProperty(leArray, variable, value);
		return value;
	}
	public static function getGroupStuff(leArray:Dynamic, variable:String, ?allowMaps:Bool = false, ?bypassAccessor:Bool = false)
	{
		var split:Array<String> = variable.split('.');
		if(split.length > 1)
		{
			var obj:Dynamic = Reflect.getProperty(leArray, split[0]);
			for (i in 1...split.length-1) obj = Reflect.getProperty(obj, split[i]);
			leArray = obj;
			variable = split[split.length-1];
		}
		if(allowMaps && isMap(leArray)) return leArray.get(variable);
		return bypassAccessor ? Reflect.field(leArray, variable) : Reflect.getProperty(leArray, variable);
	}

	public static function getPropertyLoop(split:Array<String>, ?checkForTextsToo:Bool = true, ?getProperty:Bool=true, ?allowMaps:Bool = false):Dynamic
	{
		var obj:Dynamic = getObjectDirectly(split[0], checkForTextsToo);
		for (i in 1...(getProperty ? split.length-1 : split.length)) obj = getVarInArray(obj, split[i], allowMaps);
		return obj;
	}

	inline public static function getObjectDirectly(objectName:String, ?checkForTextsToo:Bool = true, ?allowMaps:Bool = false):Dynamic
	{
		return switch(objectName)
			{
				case 'this' | 'instance' | 'game':	PlayState.instance;
				default:							PlayState.instance.getLuaObject(objectName, checkForTextsToo) ?? getVarInArray(getTargetInstance(), objectName, allowMaps);
			}
	}

	inline public static function getTextObject(name:String):FlxText
		return #if LUA_ALLOWED PlayState.instance.modchartTexts.exists(name) ? PlayState.instance.modchartTexts.get(name) : #end Reflect.getProperty(PlayState.instance, name);
	
	inline public static function isOfTypes(value:Any, types:Array<Dynamic>)
	{
		for (type in types) if(Std.isOfType(value, type)) return true;
		return false;
	}

	inline public static function boolCkeck(value:String):Null<Any> // should fix bool values
	{
		if (value == null) return value;
		value = value.toLowerCase();
		return (value == "true" || value == "false") ? value == "true" : value;
	}
	
	public static inline function getTargetInstance()
		return PlayState.instance.isDead ? substates.GameOverSubstate.instance : PlayState.instance;

	public static inline function getLowestCharacterGroup():FlxSpriteGroup
	{
		var group:FlxSpriteGroup = PlayState.instance.gfGroup;
		var pos:Int = PlayState.instance.members.indexOf(group);

		var newPos:Int = PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup);
		if(newPos < pos)
		{
			group = PlayState.instance.boyfriendGroup;
			pos = newPos;
		}
		
		newPos = PlayState.instance.members.indexOf(PlayState.instance.dadGroup);
		if(newPos < pos)
		{
			group = PlayState.instance.dadGroup;
			pos = newPos;
		}
		return group;
	}
	
	public static function addAnimByIndices(obj:String, name:String, prefix:String, indices:Any = null, framerate:Int = 24, loop:Bool = false)
	{
		final obj:Dynamic = getObjectDirectly(obj, false);
		if(obj != null && obj.animation != null)
		{
			if(indices == null) indices = [];
			if(Std.isOfType(indices, String))
			{
				var strIndices:Array<String> = cast (indices, String).trim().split(',');
				var myIndices:Array<Int> = [];
				for (i in 0...strIndices.length) myIndices.push(Std.parseInt(strIndices[i]));
				indices = myIndices;
			}
			else if (Std.isOfType(indices, Float))	indices = [cast (indices, Int)];
			else if (Std.isOfType(indices, Int))	indices = [indices];

			obj.animation.addByIndices(name, prefix, indices, '', framerate, loop);
			if(obj.animation.curAnim == null)
			{
				(obj.playAnim != null ? obj.playAnim(name, true) : obj.animation.play(name, true));
			}
			return true;
		}
		return false;
	}
	
	inline public static function loadFrames(image:String, spriteType:String)
	{
		return switch(spriteType.toLowerCase().trim())
			{
				case "texture" | "textureatlas" | "tex":				 AtlasFrameMaker.construct(image);
				case "texture_noaa" | "textureatlas_noaa" | "tex_noaa":	 AtlasFrameMaker.construct(image, null, true);
				case "packer" | "packeratlas" | "pac":					 Paths.getPackerAtlas(image);
				default:												 Paths.getSparrowAtlas(image);
			}
	}

	public static function resetTextTag(tag:String)
	{
		#if LUA_ALLOWED
		if(!PlayState.instance.modchartTexts.exists(tag)) return;

		final target:FlxText = PlayState.instance.modchartTexts.get(tag);
		target.kill();
		PlayState.instance.remove(target, true).destroy();
		PlayState.instance.modchartTexts.remove(tag);
		#end
	}

	public static function resetSpriteTag(tag:String)
	{
		#if LUA_ALLOWED
		if(!PlayState.instance.modchartSprites.exists(tag)) return;

		final target:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
		target.kill();
		PlayState.instance.remove(target, true).destroy();
		PlayState.instance.modchartSprites.remove(tag);
		#end
	}

	public static function cancelTween(tag:String)
	{
		#if LUA_ALLOWED
		if(PlayState.instance.modchartTweens.exists(tag))
		{
			final leTween:FlxTween = PlayState.instance.modchartTweens.get(tag);
			leTween.cancel();
			leTween.destroy();
			PlayState.instance.modchartTweens.remove(tag);
		}
		#end
	}

	inline public static function tweenPrepare(tag:String, vars:String)
	{
		cancelTween(tag);
		final variables:Array<String> = vars.split('.');
		return (variables.length > 1 ? getVarInArray(getPropertyLoop(variables), variables[variables.length-1]) : getObjectDirectly(variables[0]));
	}

	public static function cancelTimer(tag:String)
	{
		#if LUA_ALLOWED
		if(PlayState.instance.modchartTimers.exists(tag))
		{
			final theTimer:FlxTimer = PlayState.instance.modchartTimers.get(tag);
			theTimer.cancel();
			theTimer.destroy();
			PlayState.instance.modchartTimers.remove(tag);
		}
		#end
	}

	//buncho string stuffs
	inline public static function getTweenTypeByString(?type:String):FlxTweenType
	{
		return switch(type.toLowerCase().trim())
			{
				case 'backward':		FlxTweenType.BACKWARD;
				case 'looping'|'loop':	FlxTweenType.LOOPING;
				case 'persist':			FlxTweenType.PERSIST;
				case 'pingpong':		FlxTweenType.PINGPONG;
				default:				FlxTweenType.ONESHOT;
			}
	}

	inline public static function getTweenEaseByString(?ease:String):Float->Float
	{
		return switch(ease.toLowerCase().trim())
			{
				case 'backin':				FlxEase.backIn;
				case 'backinout':			FlxEase.backInOut;
				case 'backout':				FlxEase.backOut;
				case 'bouncein':			FlxEase.bounceIn;
				case 'bounceinout':			FlxEase.bounceInOut;
				case 'bounceout':			FlxEase.bounceOut;
				case 'circin':				FlxEase.circIn;
				case 'circinout':			FlxEase.circInOut;
				case 'circout':				FlxEase.circOut;
				case 'cubein':				FlxEase.cubeIn;
				case 'cubeinout':			FlxEase.cubeInOut;
				case 'cubeout':				FlxEase.cubeOut;
				case 'elasticin':			FlxEase.elasticIn;
				case 'elasticinout':		FlxEase.elasticInOut;
				case 'elasticout':			FlxEase.elasticOut;
				case 'expoin':				FlxEase.expoIn;
				case 'expoinout':			FlxEase.expoInOut;
				case 'expoout':				FlxEase.expoOut;
				case 'quadin':				FlxEase.quadIn;
				case 'quadinout':			FlxEase.quadInOut;
				case 'quadout':				FlxEase.quadOut;
				case 'quartin':				FlxEase.quartIn;
				case 'quartinout':			FlxEase.quartInOut;
				case 'quartout':			FlxEase.quartOut;
				case 'quintin':				FlxEase.quintIn;
				case 'quintinout':			FlxEase.quintInOut;
				case 'quintout':			FlxEase.quintOut;
				case 'sinein':				FlxEase.sineIn;
				case 'sineinout':			FlxEase.sineInOut;
				case 'sineout':				FlxEase.sineOut;
				case 'smoothstepin':		FlxEase.smoothStepIn;
				case 'smoothstepinout':		FlxEase.smoothStepInOut;
				case 'smoothstepout':		FlxEase.smoothStepInOut;
				case 'smootherstepin':		FlxEase.smootherStepIn;
				case 'smootherstepinout':	FlxEase.smootherStepInOut;
				case 'smootherstepout':		FlxEase.smootherStepOut;
				default:					FlxEase.linear;
			}
	}

	inline public static function blendModeFromString(blend:String):BlendMode
	{
		return switch(blend.toLowerCase().trim())
			{
				case 'add':			ADD;
				case 'alpha':		ALPHA;
				case 'darken':		DARKEN;
				case 'difference':	DIFFERENCE;
				case 'erase':		ERASE;
				case 'hardlight':	HARDLIGHT;
				case 'invert':		INVERT;
				case 'layer':		LAYER;
				case 'lighten':		LIGHTEN;
				case 'multiply':	MULTIPLY;
				case 'overlay':		OVERLAY;
				case 'screen':		SCREEN;
				case 'shader':		SHADER;
				case 'subtract':	SUBTRACT;
				default:			NORMAL;
			}
	}
	
	inline public static function typeToString(type:Int):String
	{
		#if LUA_ALLOWED
		return switch(type)
			{
				case Lua.LUA_TBOOLEAN:	 "boolean";
				case Lua.LUA_TNUMBER:	 "number";
				case Lua.LUA_TSTRING:	 "string";
				case Lua.LUA_TTABLE:	 "table";
				case Lua.LUA_TFUNCTION:	 "function";
				default:				 (type <= Lua.LUA_TNIL ? "nil" : "unknown");
			}
		#else
		trace('lua isn\'t allowed, returning "null"!');
		return null;
		#end
	}

	inline public static function cameraFromString(cam:String):FlxCamera
		return switch(cam.toLowerCase())
			{
				case 'camhud' | 'hud':		PlayState.instance.camHUD;
				case 'camother' | 'other':	PlayState.instance.camOther;
				default:					PlayState.instance.camGame;
			}
}