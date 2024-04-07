package psychlua;

import flixel.FlxObject;

class CustomSubstate extends MusicBeatSubstate
{
	public static var name = "unnamed";
	public static var instance:CustomSubstate;

	public static function implement(funk:FunkinLua)
	{
		#if LUA_ALLOWED
		funk.set("openCustomSubstate", openCustomSubstate);
		funk.set("closeCustomSubstate", closeCustomSubstate);
		funk.set("insertToCustomSubstate", insertToCustomSubstate);
		#end
	}
	
	public static function openCustomSubstate(name:String, pauseGame = false)
	{
		if (pauseGame)
		{
			PlayState.instance.persistentUpdate = false;
			PlayState.instance.persistentDraw = true;
			PlayState.instance.paused = true;
			// FlxTween.globalManager.forEach((tween) -> tween.active = false); // so pause tweens wont stop
			// FlxTimer.globalManager.forEach((timer) -> timer.active = false);
			// FlxG.sound.pause();
		}
		PlayState.instance.openSubState(new CustomSubstate(name));
		PlayState.instance.setOnHScript("customSubstate", instance);
		PlayState.instance.setOnHScript("customSubstateName", name);
	}

	public static function closeCustomSubstate()
	{
		if (instance == null)
			return false;

		// PlayState.instance.closeSubState();
		instance.close();
		instance = null;
		return true;
	}

	public static function insertToCustomSubstate(tag:String, pos = -1)
	{
		if (instance != null)
		{
			var tagObject:FlxObject = cast PlayState.instance.variables.get(tag);
			#if LUA_ALLOWED
			if (tagObject == null)
				tagObject = cast PlayState.instance.modchartSprites.get(tag);
			#end

			if (tagObject != null)
			{
				if (pos < 0)
					instance.add(tagObject);
				else
					instance.insert(pos, tagObject);
				return true;
			}
		}
		return false;
	}

	override function create()
	{
		instance = this;
		PlayState.instance.callOnScripts("onCustomSubstateCreate", [name]);
		super.create();
		PlayState.instance.callOnScripts("onCustomSubstateCreatePost", [name]);
	}
	
	public function new(name:String)
	{
		super();
		CustomSubstate.name = name;
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}
	
	override function update(elapsed:Float)
	{
		PlayState.instance.callOnScripts("onCustomSubstateUpdate", [name, elapsed]);
		super.update(elapsed);
		PlayState.instance.callOnScripts("onCustomSubstateUpdatePost", [name, elapsed]);
	}

	override function destroy()
	{
		PlayState.instance.callOnScripts("onCustomSubstateDestroy", [name]);
		name = "unnamed";

		PlayState.instance.setOnHScript("customSubstate", null);
		PlayState.instance.setOnHScript("customSubstateName", name);
		super.destroy();
		instance = null;
	}
}
