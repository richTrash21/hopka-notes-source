package;

import flixel.input.keyboard.FlxKey;
import lime.app.Application;
import openfl.Lib;

import backend.StateTransition;
import debug.FPSCounter;

// crash handler stuff
#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import sys.FileSystem;
import haxe.CallStack;
#end

class Main
{
	public static final game =
	{
		width: 1280,					  	  // WINDOW width
		height: 720,					  	  // WINDOW height
		initialState: states.TitleState.new,  // initial game state
		zoom: -1.0,							  // game state bounds
		framerate: 60,						  // default framerate
		skipSplash: true,					  // if the default flixel splash screen should be skipped
		startFullscreen: false				  // if the game should start at fullscreen mode
	};

	public static var fpsVar(default, null):FPSCounter;
	public static var transition(default, null):StateTransition;

	public static var volumeDownKeys = [NUMPADMINUS, MINUS];
	public static var volumeUpKeys = [NUMPADPLUS, PLUS];
	public static var muteKeys = [ZERO];

	@:noCompletion static var _focusVolume = 1.0; // ignore
	@:noCompletion static var __warns = new Array<String>();
	@:noCompletion static var __log = "";

	// You can pretty much ignore everything from here on - your code should go in your states.

	static function main()
	{
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

		final g = new flixel.FlxGame(game.width, game.height, Init, game.framerate, game.framerate, game.skipSplash, game.startFullscreen);
		Lib.application.window.stage.addChild(g);
		transition = new StateTransition();
		g.addChildAt(transition, 0);

		#if !mobile
		g.addChild(fpsVar = new FPSCounter(10, 3));
		fpsVar.visible = ClientPrefs.data.showFPS;
		#end

		_focusVolume = FlxG.sound.volume;
		#if debug // это рофлс
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

		FlxG.signals.focusGained.add(volumeOnFocus);
		FlxG.signals.focusLost.add(volumeOnFocusLost);
		FlxG.signals.gameResized.add(shaderFix);
		Application.current.window.onClose.add(volumeOnFocus, true);
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

	// shader coords fix
	@:access(openfl.display.DisplayObject.__cleanup)
	static function shaderFix(_, _):Void
	{
		for (cam in FlxG.cameras.list)
			if (cam != null && cam.filters != null)
				cam.flashSprite.__cleanup();

		FlxG.game.__cleanup();
	}

	static function volumeOnFocus() // dont ask
	{
		if (ClientPrefs.data.lostFocusDeafen && !FlxG.sound.muted)
			FlxG.sound.volume = _focusVolume;
	}

	static function volumeOnFocusLost() // dont ask
	{
		if (ClientPrefs.data.lostFocusDeafen && !FlxG.sound.muted)
		{
			_focusVolume = Math.ffloor(FlxG.sound.volume * 10.0) * 0.1;
			FlxG.sound.volume = FlxG.sound.volume * 0.5; // Math.ffloor(FlxG.sound.volume * 5.0) * 0.1;
		}
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
	static function formatOutput(v:Dynamic, pos:haxe.PosInfos):String
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
}
