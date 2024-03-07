package;

import debug.FPSCounter;

import openfl.Lib;
import openfl.display.Sprite;

import lime.app.Application;

import flixel.FlxGame;
import flixel.input.keyboard.FlxKey;

//crash handler stuff
#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import sys.FileSystem;
import haxe.CallStack;
#end

class Main extends Sprite
{
	public static final game =
	{
		width: 1280,					  // WINDOW width
		height: 720,					  // WINDOW height
		initialState: states.TitleState.new,  // initial game state
		zoom: -1.0,						  // game state bounds
		framerate: 60,					  // default framerate
		skipSplash: true,				  // if the default flixel splash screen should be skipped
		startFullscreen: false			  // if the game should start at fullscreen mode
	};

	public static var fpsVar(default, null):FPSCounter;
	@:noCompletion static var _focusVolume:Float = 1; // ignore

	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	static var __log = "";

	// You can pretty much ignore everything from here on - your code should go in your states.

	public function new()
	{
		// based log by richTrash21 yeah
		haxe.Log.trace = (v:Dynamic, ?pos:haxe.PosInfos) ->
		{
			// based on haxe.Log.formatOutput()
			inline function formatOutput(v:Dynamic, pos:haxe.PosInfos):String
			{
				final t = "<" + Date.now().toString().substr(11) + ">";
				var s = " > " + Std.string(v);
				if (pos == null)
					return t + s;
				var p = pos.fileName + ":" + pos.lineNumber;
				if (pos.methodName?.length > 0)
					p += " - " + (pos.className?.length > 0 ? pos.className + "." + pos.methodName : pos.methodName) + "()";
				if (pos.customParams != null)
					for (_v in pos.customParams)
						s += ", " + Std.string(_v);
				return t + " [" + p + "]" + s;
			}

			final str = formatOutput(v, pos);
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

		super();
		setupGame();

		Application.current.window.onFocusIn.add(volumeOnFocus);
		Application.current.window.onFocusOut.add(volumeOnFocusLost);
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
			_focusVolume = Math.floor(FlxG.sound.volume * 10) * 0.1;
			FlxG.sound.volume *= 0.5;
		}
	}

	private function setupGame():Void
	{
		final g = new FlxGame(game.width, game.height, Init, game.framerate, game.framerate, game.skipSplash, game.startFullscreen);
		addChild(g);

		#if !mobile
		g.addChild(fpsVar = new FPSCounter(10, 3));
		fpsVar.visible = ClientPrefs.data.showFPS;

		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = openfl.display.StageScaleMode.NO_SCALE;
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

		#if desktop
		DiscordClient.start();
		#end

		// shader coords fix
		FlxG.signals.gameResized.add((w, h) ->
		{
			for (cam in FlxG.cameras.list)
				if (cam != null && cam.filters != null)
					resetSpriteCache(cam.flashSprite);

			resetSpriteCache(FlxG.game);
		});
	}

	@:access(openfl.display.DisplayObject.__cleanup)
	inline static function resetSpriteCache(sprite:Sprite):Void
	{
		sprite.__cleanup();
	}

	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	// by sqirra-rng
	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
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

		final devMsg = " - " + #if RELESE_BUILD_FR "i messed up, whoops" #else "you done goofed" #end + " (richTrash21)";
		errMsg += "\nUncaught Error: " + e.error + '\n\ntl;dr$devMsg';
		// "\nPlease report this error to the GitHub page: https://github.com/ShadowMario/FNF-PsychEngine\n\n> Crash Handler written by: sqirra-rng";

		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");
		sys.io.File.saveContent(path, '$errMsg\n\nFull session log:\n$__log');

		final savedIn = "Crash dump saved in " + haxe.io.Path.normalize(path);
		Sys.println(errMsg);
		Sys.println(savedIn);

		Application.current.window.alert('$errMsg\n$savedIn', "Uncaught Error!");
		DiscordClient.shutdown();
		Sys.exit(1);
	}
	#end
}
