package psychlua;

import Type.ValueType;
import openfl.display.BlendMode;
import animateatlas.AtlasFrameMaker;
import substates.GameOverSubstate;

import llua.Lua;

typedef LuaTweenOptions = {
	type:FlxTweenType,
	startDelay:Float,
	onUpdate:Null<String>,
	onStart:Null<String>,
	onComplete:Null<String>,
	loopDelay:Float,
	ease:EaseFunction
}

class LuaUtils
{
	public static function getLuaTween(options:Dynamic)
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
		var end = split.length;
		if(getProperty) end = split.length-1;

		for (i in 1...end) obj = getVarInArray(obj, split[i], allowMaps);
		return obj;
	}

	public static function getObjectDirectly(objectName:String, ?checkForTextsToo:Bool = true, ?allowMaps:Bool = false):Dynamic
	{
		switch(objectName)
		{
			case 'this' | 'instance' | 'game':
				return PlayState.instance;
			
			default:
				var obj:Dynamic = PlayState.instance.getLuaObject(objectName, checkForTextsToo);
				if(obj == null) obj = getVarInArray(getTargetInstance(), objectName, allowMaps);
				return obj;
		}
	}

	inline public static function getTextObject(name:String):FlxText
		return #if LUA_ALLOWED PlayState.instance.modchartTexts.exists(name) ? PlayState.instance.modchartTexts.get(name) : #end Reflect.getProperty(PlayState.instance, name);
	
	public static function isOfTypes(value:Any, types:Array<Dynamic>)
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
		return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;

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
		var obj:Dynamic = LuaUtils.getObjectDirectly(obj, false);
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
				if(obj.playAnim != null) obj.playAnim(name, true);
				else obj.animation.play(name, true);
			}
			return true;
		}
		return false;
	}
	
	public static function loadFrames(spr:FlxSprite, image:String, spriteType:String)
	{
		switch(spriteType.toLowerCase().trim())
		{
			case "texture" | "textureatlas" | "tex":
				spr.frames = AtlasFrameMaker.construct(image);

			case "texture_noaa" | "textureatlas_noaa" | "tex_noaa":
				spr.frames = AtlasFrameMaker.construct(image, null, true);

			case "packer" | "packeratlas" | "pac":
				spr.frames = Paths.getPackerAtlas(image);

			default:
				spr.frames = Paths.getSparrowAtlas(image);
		}
	}

	public static function resetTextTag(tag:String)
	{
		#if LUA_ALLOWED
		if(!PlayState.instance.modchartTexts.exists(tag)) return;

		var target:FlxText = PlayState.instance.modchartTexts.get(tag);
		target.kill();
		PlayState.instance.remove(target, true);
		target.destroy();
		PlayState.instance.modchartTexts.remove(tag);
		#end
	}

	public static function resetSpriteTag(tag:String)
	{
		#if LUA_ALLOWED
		if(!PlayState.instance.modchartSprites.exists(tag)) return;

		var target:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
		target.kill();
		PlayState.instance.remove(target, true);
		target.destroy();
		PlayState.instance.modchartSprites.remove(tag);
		#end
	}

	public static function cancelTween(tag:String)
	{
		#if LUA_ALLOWED
		if(PlayState.instance.modchartTweens.exists(tag)) {
			PlayState.instance.modchartTweens.get(tag).cancel();
			PlayState.instance.modchartTweens.get(tag).destroy();
			PlayState.instance.modchartTweens.remove(tag);
		}
		#end
	}

	public static function tweenPrepare(tag:String, vars:String)
	{
		cancelTween(tag);
		var variables:Array<String> = vars.split('.');
		var sexyProp:Dynamic = LuaUtils.getObjectDirectly(variables[0]);
		if(variables.length > 1) sexyProp = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(variables), variables[variables.length-1]);
		return sexyProp;
	}

	public static function cancelTimer(tag:String)
	{
		#if LUA_ALLOWED
		if(PlayState.instance.modchartTimers.exists(tag)) {
			var theTimer:FlxTimer = PlayState.instance.modchartTimers.get(tag);
			theTimer.cancel();
			theTimer.destroy();
			PlayState.instance.modchartTimers.remove(tag);
		}
		#end
	}

	//buncho string stuffs
	public static function getTweenTypeByString(?type:String = ''):FlxTweenType
	{
		var _type:FlxTweenType = FlxTweenType.ONESHOT;
		switch(type.toLowerCase().trim())
		{
			case 'backward':		_type = FlxTweenType.BACKWARD;
			case 'looping'|'loop':	_type = FlxTweenType.LOOPING;
			case 'persist':			_type = FlxTweenType.PERSIST;
			case 'pingpong':		_type = FlxTweenType.PINGPONG;
		}
		return _type;
	}

	public static function getTweenEaseByString(?ease:String = ''):(f:Float)->Float
	{
		var _ease:(f:Float)->Float = FlxEase.linear;
		switch(ease.toLowerCase().trim())
		{
			case 'backin':				_ease = FlxEase.backIn;
			case 'backinout':			_ease = FlxEase.backInOut;
			case 'backout':				_ease = FlxEase.backOut;
			case 'bouncein':			_ease = FlxEase.bounceIn;
			case 'bounceinout':			_ease = FlxEase.bounceInOut;
			case 'bounceout':			_ease = FlxEase.bounceOut;
			case 'circin':				_ease = FlxEase.circIn;
			case 'circinout':			_ease = FlxEase.circInOut;
			case 'circout':				_ease = FlxEase.circOut;
			case 'cubein':				_ease = FlxEase.cubeIn;
			case 'cubeinout':			_ease = FlxEase.cubeInOut;
			case 'cubeout':				_ease = FlxEase.cubeOut;
			case 'elasticin':			_ease = FlxEase.elasticIn;
			case 'elasticinout':		_ease = FlxEase.elasticInOut;
			case 'elasticout':			_ease = FlxEase.elasticOut;
			case 'expoin':				_ease = FlxEase.expoIn;
			case 'expoinout':			_ease = FlxEase.expoInOut;
			case 'expoout':				_ease = FlxEase.expoOut;
			case 'quadin':				_ease = FlxEase.quadIn;
			case 'quadinout':			_ease = FlxEase.quadInOut;
			case 'quadout':				_ease = FlxEase.quadOut;
			case 'quartin':				_ease = FlxEase.quartIn;
			case 'quartinout':			_ease = FlxEase.quartInOut;
			case 'quartout':			_ease = FlxEase.quartOut;
			case 'quintin':				_ease = FlxEase.quintIn;
			case 'quintinout':			_ease = FlxEase.quintInOut;
			case 'quintout':			_ease = FlxEase.quintOut;
			case 'sinein':				_ease = FlxEase.sineIn;
			case 'sineinout':			_ease = FlxEase.sineInOut;
			case 'sineout':				_ease = FlxEase.sineOut;
			case 'smoothstepin':		_ease = FlxEase.smoothStepIn;
			case 'smoothstepinout':		_ease = FlxEase.smoothStepInOut;
			case 'smoothstepout':		_ease = FlxEase.smoothStepInOut;
			case 'smootherstepin':		_ease = FlxEase.smootherStepIn;
			case 'smootherstepinout':	_ease = FlxEase.smootherStepInOut;
			case 'smootherstepout':		_ease = FlxEase.smootherStepOut;
		}
		return _ease;
	}

	public static function blendModeFromString(blend:String):BlendMode
	{
		var _blend:BlendMode = NORMAL;
		switch(blend.toLowerCase().trim())
		{
			case 'add':			_blend = ADD;
			case 'alpha':		_blend = ALPHA;
			case 'darken':		_blend = DARKEN;
			case 'difference':	_blend = DIFFERENCE;
			case 'erase':		_blend = ERASE;
			case 'hardlight':	_blend = HARDLIGHT;
			case 'invert':		_blend = INVERT;
			case 'layer':		_blend = LAYER;
			case 'lighten':		_blend = LIGHTEN;
			case 'multiply':	_blend = MULTIPLY;
			case 'overlay':		_blend = OVERLAY;
			case 'screen':		_blend = SCREEN;
			case 'shader':		_blend = SHADER;
			case 'subtract':	_blend = SUBTRACT;
		}
		return _blend;
	}
	
	public static function typeToString(type:Int):String
	{
		#if LUA_ALLOWED
		var _type:String = "unknown";
		switch(type)
		{
			case Lua.LUA_TBOOLEAN:	_type = "boolean";
			case Lua.LUA_TNUMBER:	_type = "number";
			case Lua.LUA_TSTRING:	_type = "string";
			case Lua.LUA_TTABLE:	_type = "table";
			case Lua.LUA_TFUNCTION:	_type = "function";
		}
		if (type <= Lua.LUA_TNIL)	_type = "nil";
		#end
		return _type;
	}

	public static function cameraFromString(cam:String):FlxCamera
	{
		var _cam:FlxCamera = PlayState.instance.camGame;
		switch(cam.toLowerCase())
		{
			case 'camhud' | 'hud':		_cam = PlayState.instance.camHUD;
			case 'camother' | 'other':	_cam = PlayState.instance.camOther;
		}
		return _cam;
	}
}