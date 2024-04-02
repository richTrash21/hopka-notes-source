package psychlua;

#if LUA_ALLOWED

import llua.Lua;
import llua.Convert;

@:allow(Main)
class CallbackHandler
{
	inline /*public*/ static function call(l:llua.State, fname:String):Int
	{
		try
		{
			var cbf:Dynamic = Lua_helper.callbacks.get(fname);

			// Local functions have the lowest priority
			// This is to prevent a "for" loop being called in every single operation,
			// so that it only loops on reserved/special functions
			if (cbf == null) 
				for (script in PlayState.instance.luaArray)
					if (script != null && script.lua == l)
					{
						cbf = script.callbacks.get(fname);
						break;
					}
			
			if (cbf == null)
				return 0;

			/* return the number of results */
			final ret:Dynamic = Reflect.callMethod(null, cbf, [for (i in 0...Lua.gettop(l)) Convert.fromLua(l, i + 1)]);
			if (ret == null)
				return 0;

			Convert.toLua(l, ret);
			return 1;
		}
		catch (e)
		{
			if (Lua_helper.sendErrorsToLua)
			{
				llua.LuaL.error(l, 'CALLBACK ERROR! $e');
				return 0;
			}
			trace(e);
			throw(e);
		}
	}
}
#end