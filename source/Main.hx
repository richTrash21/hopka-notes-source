package;

import lime.app.Application;
import openfl.Lib;

import flixel.addons.transition.FlxTransitionableState;
import flixel.input.keyboard.FlxKey;

import backend.StateTransition;
import backend.Subtitles;
import debug.FPSCounter;

// crash handler stuff
#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import sys.FileSystem;
import haxe.CallStack;
#end

class Main extends flixel.FlxGame
{
	public static final game:GameProperties =
	{
		width: 1280,					  	  // WINDOW width
		height: 720,					  	  // WINDOW height
		initialState: states.TitleState.new,  // initial game state
		// zoom: -1.0,							  // game state bounds
		framerate: 60,						  // default framerate
		skipSplash: true,					  // if the default flixel splash screen should be skipped
		startFullscreen: false				  // if the game should start at fullscreen mode
	};

	public static var fpsVar(get, never):FPSCounter;
	public static var transition(get, never):StateTransition;

	public static var volumeDownKeys:Array<FlxKey>;
	public static var volumeUpKeys:Array<FlxKey>;
	public static var muteKeys:Array<FlxKey>;

	@:noCompletion static var __warns = new Array<String>();
	@:noCompletion static var __log = "";
	@:noCompletion static var __main:Main;

	@:noCompletion var __transition:StateTransition;
	@:noCompletion var __fps:FPSCounter;

	@:noCompletion var __focusVolume = 1.0; // ignore
	// @:noCompletion var __totalTime = 0;

	public function new()
	{
		__main = this;
		// cool ass log by me yeah
		haxe.Log.trace = (v:Dynamic, ?pos:haxe.PosInfos) ->
		{
			final str = Main.formatOutput(v, pos);
			__log += '$str\n';
			#if js
			if (js.Syntax.typeof(untyped console) != "undefined" && (untyped console).log != null)
				(untyped console).log(str);
			#elseif lua
			untyped __define_feature__("use._hx_print", _hx_print(str));
			#elseif sys
			Sys.println(str);
			#else
			throw new haxe.exceptions.NotImplementedException()
			#end
		}

		// sexy subtitle markups
		for (name => color in FlxColor.colorLookup)
		{
			if (color == 0)
				continue;

			name = name.toLowerCase();
			Subtitles._markup.push(new FlxTextFormatMarkerPair(new FlxTextFormat(color), '<$name>'));
			Subtitles._markup.push(new FlxTextFormatMarkerPair(new FlxTextFormat(null, null, null, color), '<border-$name>'));
		}

		// var field:Dynamic;
		for (f in Type.getClassFields(FlxEase))
			if (f.toUpperCase() != f) // Type.typeof(field = Reflect.field(FlxEase, f)) == TFunction
				psychlua.LuaUtils.__easeMap.set(f.toLowerCase(), Reflect.field(FlxEase, f)); // cast field

		FlxG.save.bind("funkin", CoolUtil.getSavePath());
		super(game.width, game.height, Init, game.framerate, game.framerate, game.skipSplash, game.startFullscreen);
		Subtitles.__posY = FlxG.height * 0.75;

		// reset cache on restart
		FlxG.signals.preGameReset.add(() -> { Paths.clearStoredMemory(); Paths.clearUnusedMemory(); });
		// sync save data on restart
		FlxG.signals.postGameReset.add(() -> { FlxG.autoPause = ClientPrefs.data.autoPause; FlxG.fixedTimestep = ClientPrefs.data.fixedTimestep; });

		ClientPrefs.loadDefaultKeys();
		ClientPrefs.loadPrefs();
	}

	override function create(_)
	{
		if (stage == null)
			return;

		addChild(__transition = new StateTransition());

		super.create(_);

		// __totalTime = getTimer();
		// getTimer = () -> __totalTime; // hope it will not completely break the game :clueless:

		#if !mobile
		addChild(__fps = new FPSCounter(10, 3)).visible = ClientPrefs.data.showFPS;
		#end

		FlxTransitionableState.skipNextTransOut = /*FlxTransitionableState.skipNextTransIn =*/ true;

		#if LUA_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		Controls.instance = new Controls();
		// ClientPrefs.loadDefaultKeys();

		#if LUA_ALLOWED
		llua.Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call));
		#end
		#if ACHIEVEMENTS_ALLOWED
		Achievements.load();
		#end
		backend.Highscore.load();

		if (FlxG.save.data.weekCompleted != null)
			states.StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;

		__focusVolume = FlxG.sound.volume;
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
		FlxG.console.registerFunction("switchState", (n:String, ?p:Array<Dynamic>) -> MusicBeatState.switchState(Type.createInstance(Type.resolveClass(n), p ?? [])));

		// это рофлс
		FlxG.game.soundTray.volumeUpSound = "assets/sounds/metal";
		FlxG.game.soundTray.volumeDownSound = "assets/sounds/lego";
		#else
		FlxG.game.soundTray.volumeUpSound = "assets/sounds/up_volume";
		FlxG.game.soundTray.volumeDownSound = "assets/sounds/down_volume";
		#end

		#if !html5
		FlxG.mouse.useSystemCursor = true;
		#end
		
		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end

		#if hxdiscord_rpc
		DiscordClient.prepare();
		#end

		FlxG.signals.gameResized.add(shaderFix);
		// Application.current.window.onClose.add(() -> FlxG.sound.volume = __focusVolume, true);

		// im sorry but some mods are annoying with this
		FlxG.signals.preStateSwitch.add(() -> FlxG.cameras.bgColor = FlxColor.BLACK);
	}

	override function onFocus(_)
	{
		if (!FlxG.autoPause && ClientPrefs.data.lostFocusDeafen && !FlxG.sound.muted)
			FlxG.sound.volume = __focusVolume;

		super.onFocus(_);
	}

	override function onFocusLost(event:openfl.events.Event)
	{
		if (!FlxG.autoPause && ClientPrefs.data.lostFocusDeafen && !FlxG.sound.muted)
		{
			__focusVolume = Math.ffloor(FlxG.sound.volume * 10.0) * 0.1;
			FlxG.sound.volume = FlxG.sound.volume * 0.5; // Math.ffloor(FlxG.sound.volume * 5.0) * 0.1;
		}
		super.onFocusLost(event);
	}

	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	// by sqirra-rng
	#if CRASH_HANDLER
	static function onCrash(e:UncaughtErrorEvent):Void
	{
		final path = "./crash/CrashLog_" + Date.now().toString().replace(" ", "_").replace(":", "'") + ".txt";
		var errMsg = "";

		for (stackItem in CallStack.exceptionStack(true))
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += '$file (line $line)\n';
				default:
					Sys.println(stackItem);
			}

		final devMsg = #if RELESE_BUILD_FR "i messed up, whoops" #else "you done goofed" #end + " (richTrash21)";
		errMsg += "\nUncaught Error: " + e.error + '\n\ntl;dr - $devMsg';
		// "\nPlease report this error to the GitHub page: https://github.com/ShadowMario/FNF-PsychEngine\n\n> Crash Handler written by: sqirra-rng";

		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");
		sys.io.File.saveContent(path, '$errMsg\n\nFull session log:\n$__log');

		final savedIn = "Crash dump saved in " + haxe.io.Path.normalize(path);
		Sys.println(errMsg);
		Sys.println(savedIn);

		Application.current.window.alert('$errMsg\n$savedIn', "Uncaught Error!");
		#if hxdiscord_rpc
		DiscordClient.shutdown();
		#end
		Sys.exit(1);
	}
	#end

	/*@:noCompletion override function __enterFrame(deltaTime:Int)
	{
		__totalTime += deltaTime;
		super.__enterFrame(deltaTime);
	}*/

	// shader coords fix
	@:access(openfl.display.DisplayObject.__cleanup)
	@:noCompletion function shaderFix(_, _):Void
	{
		for (cam in FlxG.cameras.list)
			if (cam != null && cam.filters != null)
				cam.flashSprite.__cleanup();

		this.__cleanup();
	}

	#if FLX_DEBUG inline #end public static function warn(data:Dynamic #if !FLX_DEBUG , ?pos:haxe.PosInfos #end)
	{
		#if FLX_DEBUG
		FlxG.log.warn(data);
		#else
		final s = Std.string(data);
		if (!__warns.contains(s))
		{
			__warns.push(s);
			haxe.Log.trace('[WARN] $s', pos);
		}
		#end
	}

	// based on haxe.Log.formatOutput()
	@:noCompletion static function formatOutput(v:Dynamic, pos:haxe.PosInfos):String
	{
		final t = "<" + Date.now().toString().substr(11) + ">";
		var s = Std.string(v);
		if (pos == null)
			return '$t > $s';

		var p = pos.fileName + ":" + pos.lineNumber;
		if (pos.methodName != null && pos.methodName.length != 0)
		{
			p += " - ";
			if (pos.className != null && pos.className.length != 0)
				p += pos.className + ".";
			p += pos.methodName + "()";
		}

		if (pos.customParams != null)
			for (_v in pos.customParams)
				s += ", " + Std.string(_v);

		return '$t [$p] > $s';
	}

	@:noCompletion inline static function get_fpsVar():FPSCounter
	{
		return __main.__fps;
	}

	@:noCompletion inline static function get_transition():StateTransition
	{
		return __main.__transition;
	}
}

@:noCompletion @:publicFields @:structInit private class GameProperties
{
	var width:Int;
	var height:Int;
	var initialState:flixel.util.typeLimit.NextState;
	// var zoom:Float;
	var framerate:Int;
	var skipSplash:Bool;
	var startFullscreen:Bool;
}
