package psychlua;

import substates.GameOverSubstate;

/**
	Functions that use a high amount of Reflections, which are somewhat CPU intensive.
	These functions are held together by duct tape.
**/
class ReflectionFunctions
{
	public static function implement(funk:FunkinLua)
	{
		var lua:State = funk.lua;

		addCallback(lua, "getProperty", function(variable:String, ?allowMaps:Bool = false, ?bypassAccessor:Bool = false) {
			var split:Array<String> = variable.split('.');
			if(split.length > 1)
				return LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split, true, true, allowMaps), split[split.length-1], allowMaps, bypassAccessor);
			return LuaUtils.getVarInArray(LuaUtils.getTargetInstance(), variable, allowMaps, bypassAccessor);
		});
		addCallback(lua, "setProperty", function(variable:String, value:Dynamic, allowMaps:Bool = false, ?bypassAccessor:Bool = false) {
			var split:Array<String> = variable.split('.');
			if(split.length > 1)
				return LuaUtils.setVarInArray(LuaUtils.getPropertyLoop(split, true, true, allowMaps), split[split.length-1], value, allowMaps, bypassAccessor);
			
			return LuaUtils.setVarInArray(LuaUtils.getTargetInstance(), variable, value, allowMaps, bypassAccessor);
		});
		addCallback(lua, "getPropertyFromClass", function(classVar:String, variable:String, ?allowMaps:Bool = false, ?bypassAccessor:Bool = false) {
			var myClass:Dynamic = Type.resolveClass(classVar);
			if(myClass == null)
			{
				FunkinLua.luaTrace('getPropertyFromClass: Class $classVar not found', false, false, FlxColor.RED);
				return null;
			}

			var split:Array<String> = variable.split('.');
			if(split.length > 1) {
				var obj:Dynamic = LuaUtils.getVarInArray(myClass, split[0], allowMaps);
				for (i in 1...split.length-1)
					obj = LuaUtils.getVarInArray(obj, split[i], allowMaps);

				return LuaUtils.getVarInArray(obj, split[split.length-1], allowMaps, bypassAccessor);
			}
			return LuaUtils.getVarInArray(myClass, variable, allowMaps, bypassAccessor);
		});
		addCallback(lua, "setPropertyFromClass", function(classVar:String, variable:String, value:Dynamic, ?allowMaps:Bool = false, ?bypassAccessor:Bool = false) {
			var myClass:Dynamic = Type.resolveClass(classVar);
			if(myClass == null)
			{
				FunkinLua.luaTrace('getPropertyFromClass: Class $classVar not found', false, false, FlxColor.RED);
				return null;
			}

			var split:Array<String> = variable.split('.');
			if(split.length > 1) {
				var obj:Dynamic = LuaUtils.getVarInArray(myClass, split[0], allowMaps);
				for (i in 1...split.length-1)
					obj = LuaUtils.getVarInArray(obj, split[i], allowMaps);

				LuaUtils.setVarInArray(obj, split[split.length-1], value, allowMaps, bypassAccessor);
				return value;
			}
			LuaUtils.setVarInArray(myClass, variable, value, allowMaps, bypassAccessor);
			return value;
		});
		addCallback(lua, "getPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic, ?allowMaps:Bool = false, ?bypassAccessor:Bool = false) {
			var split:Array<String> = obj.split('.');
			var realObject:Dynamic = null;
			if(split.length > 1)
				realObject = LuaUtils.getPropertyLoop(split, true, false, allowMaps);
			else
				realObject = Reflect.getProperty(LuaUtils.getTargetInstance(), obj);

			if(realObject is FlxTypedGroup || realObject is FlxTypedSpriteGroup)
			{
				var result:Dynamic = LuaUtils.getGroupStuff(realObject.members[index], variable, allowMaps, bypassAccessor);
				return result;
			}

			var leArray:Dynamic = realObject[index];
			if(leArray != null)
			{
				var result:Dynamic = null;
				if(Type.typeof(variable) == TInt)
					result = leArray[variable];
				else
					result = LuaUtils.getGroupStuff(leArray, variable, allowMaps, bypassAccessor);
				return result;
			}
			FunkinLua.luaTrace("getPropertyFromGroup: Object #" + index + " from group: " + obj + " doesn't exist!", false, false, FlxColor.RED);
			return null;
		});
		addCallback(lua, "setPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic, value:Dynamic, ?allowMaps:Bool = false, ?bypassAccessor:Bool = false) {
			var split:Array<String> = obj.split('.');
			var realObject:Dynamic = null;
			if(split.length > 1)
				realObject = LuaUtils.getPropertyLoop(split, true, false, allowMaps);
			else
				realObject = Reflect.getProperty(LuaUtils.getTargetInstance(), obj);

			if(realObject is FlxTypedGroup || realObject is FlxTypedSpriteGroup)
			{
				LuaUtils.setGroupStuff(realObject.members[index], variable, value, allowMaps, bypassAccessor);
				return value;
			}

			var leArray:Dynamic = realObject[index];
			if(leArray != null) {
				if(Type.typeof(variable) == TInt) {
					leArray[variable] = value;
					return value;
				}
				LuaUtils.setGroupStuff(leArray, variable, value, allowMaps, bypassAccessor);
			}
			return value;
		});
		addCallback(lua, "removeFromGroup", function(obj:String, index:Int, dontDestroy:Bool = false) {
			var groupOrArray:Dynamic = Reflect.getProperty(LuaUtils.getTargetInstance(), obj);
			if(groupOrArray is FlxTypedGroup || groupOrArray is FlxTypedSpriteGroup)
			{
				var sex = groupOrArray.members[index];
				if(!dontDestroy) sex.kill();
				groupOrArray.remove(sex, true);
				if(!dontDestroy) sex.destroy();
				return;
			}
			groupOrArray.remove(groupOrArray[index]);
		});
		
		addCallback(lua, "callMethod", function(funcToRun:String, ?args:Array<Dynamic> = null)
			return callMethodFromObject(PlayState.instance, funcToRun, args)
		);
		addCallback(lua, "callMethodFromClass", function(className:String, funcToRun:String, ?args:Array<Dynamic> = null)
			return callMethodFromObject(Type.resolveClass(className), funcToRun, args)
		);

		addCallback(lua, "createInstance", function(variableToSave:String, className:String, ?args:Array<Dynamic> = null) {
			variableToSave = variableToSave.trim().replace('.', '');
			if(!PlayState.instance.variables.exists(variableToSave))
			{
				if(args == null) args = [];
				var myType:Dynamic = Type.resolveClass(className);
		
				if(myType == null)
				{
					FunkinLua.luaTrace('createInstance: Variable $variableToSave is already being used and cannot be replaced!', false, false, FlxColor.RED);
					return false;
				}

				var obj:Dynamic = Type.createInstance(myType, args);
				if(obj != null)
					PlayState.instance.variables.set(variableToSave, obj);
				else
					FunkinLua.luaTrace('createInstance: Failed to create $variableToSave, arguments are possibly wrong.', false, false, FlxColor.RED);

				return (obj != null);
			}
			else FunkinLua.luaTrace('createInstance: Variable $variableToSave is already being used and cannot be replaced!', false, false, FlxColor.RED);
			return false;
		});
		addCallback(lua, "addInstance", function(objectName:String, ?inFront:Bool = false) {
			if(PlayState.instance.variables.exists(objectName))
			{
				var obj:Dynamic = PlayState.instance.variables.get(objectName);
				if (inFront)
					LuaUtils.getTargetInstance().add(obj);
				else
				{
					if(!PlayState.instance.isDead)
						PlayState.instance.insert(PlayState.instance.members.indexOf(LuaUtils.getLowestCharacterGroup()), obj);
					else
						GameOverSubstate.instance.insert(GameOverSubstate.instance.members.indexOf(GameOverSubstate.instance.boyfriend), obj);
				}
			}
			else FunkinLua.luaTrace('addInstance: Can\'t add what doesn\'t exist~ ($objectName)', false, false, FlxColor.RED);
		});
	}

	inline static function addCallback(l:State, name:String, func:Dynamic) Lua_helper.add_callback(l, name, func);

	static function callMethodFromObject(classObj:Dynamic, funcStr:String, args:Array<Dynamic> = null)
	{
		if(args == null) args = [];

		var split:Array<String> = funcStr.split('.');
		var funcToRun:haxe.Constraints.Function = null;
		var obj:Dynamic = classObj;
		if(obj == null) return null;

		for (i in 0...split.length)
			obj = LuaUtils.getVarInArray(obj, split[i].trim());

		funcToRun = cast obj;
		return funcToRun != null ? Reflect.callMethod(obj, funcToRun, args) : null;
	}
}