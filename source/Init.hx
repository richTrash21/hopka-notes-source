package;

import flixel.addons.transition.FlxTransitionableState;

import states.FlashingState;
import psychlua.LuaUtils;
import backend.Subtitles;

// THIS IS FOR INITIALIZING STUFF BECAUSE FLIXEL HATES INITIALIZING STUFF IN MAIN
// GO TO MAIN FOR GLOBAL PROJECT/OPENFL STUFF
// CODE BY Rudyrue (https://github.com/ShadowMario/FNF-PsychEngine/pull/13695)
class Init extends flixel.FlxState
{
	override function create():Void
	{
		super.create();

		// sexy subtitle markups
		for (name => color in FlxColor.colorLookup)
		{
			name = name.toLowerCase();
			Subtitles._markup.push(new FlxTextFormatMarkerPair(new FlxTextFormat(color), '<$name>'));
			Subtitles._markup.push(new FlxTextFormatMarkerPair(new FlxTextFormat(null, null, null, color), '<border-$name>'));
		}
		Subtitles.__posY = FlxG.height * 0.75;

		// don't need these
		final __exclude = ["PI2", "EL", "B1", "B2", "B3", "B4", "B5", "B6", "ELASTIC_AMPLITUDE", "ELASTIC_PERIOD"];
		for (f in Type.getClassFields(FlxEase))
			if (!__exclude.contains(f))
				LuaUtils.__easeMap.set(f.toLowerCase(), Reflect.getProperty(FlxEase, f));

		FlxTransitionableState.skipNextTransOut = true;

		#if LUA_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		FlxG.save.bind("funkin", CoolUtil.getSavePath());
		ClientPrefs.loadPrefs();

		FlxG.fixedTimestep = ClientPrefs.data.fixedTimestep;
		FlxG.game.focusLostFramerate = 60;
		FlxG.keys.preventDefaultKeys = [TAB];

		FlxG.updateFramerate = FlxG.drawFramerate = ClientPrefs.data.framerate;

		#if LUA_ALLOWED llua.Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call)); #end
		if (Controls.instance == null)
			new Controls();
		ClientPrefs.loadDefaultKeys();
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end
		backend.Highscore.load();

		if (FlxG.save.data.weekCompleted != null)
			states.StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;

		if (FlxG.save.data != null && FlxG.save.data.fullscreen)
			FlxG.fullscreen = FlxG.save.data.fullscreen;

		#if debug
		FlxG.console.registerClass(Main);
		FlxG.console.registerClass(Paths);
		FlxG.console.registerClass(PlayState);
		FlxG.console.registerClass(ClientPrefs);
		#if ACHIEVEMENTS_ALLOWED
		FlxG.console.registerClass(Achievements);
		#end
		FlxG.console.registerClass(MusicBeatState);
		FlxG.console.registerObject("controls", Controls.instance);
		FlxG.console.registerFunction("switchState", (name:String) -> MusicBeatState.switchState(Type.createInstance(Type.resolveClass(name), [])));
		#end

		var switchTo:flixel.util.typeLimit.NextState = FlxG.save.data.isDoised ? states.DoiseRoomLMAO.new : Main.game.initialState;
		if (FlxG.save.data.flashing == null && !FlashingState.leftState)
		{
			FlxTransitionableState.skipNextTransIn = true;
			switchTo = FlashingState.new;
		}
		FlxG.switchState(switchTo);
	}
}