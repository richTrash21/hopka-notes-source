package;

import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;

import lime.app.Application;

//crash handler stuff
#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import sys.FileSystem;
import haxe.CallStack;
#end

class Main extends Sprite
{
	var game = {
		width: 1280, // WINDOW width
		height: 720, // WINDOW height
		initialState: states.TitleState, // initial game state
		zoom: -1.0, // game state bounds
		framerate: 60, // default framerate
		skipSplash: true, // if the default flixel splash screen should be skipped
		startFullscreen: false // if the game should start at fullscreen mode
	};

	public static var fpsVar:FPS;
	public static var fpsShadow:FPS;
	@:noCompletion private static var _focusVolume(default, null):Float = 1; // ignore

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		if (stage != null)
			init();
		else
			addEventListener(Event.ADDED_TO_STAGE, init);

		Application.current.window.onFocusIn.add(volumeOnFocus);
		Application.current.window.onFocusOut.add(volumeOnFocusLost);
	}

	private function volumeOnFocus() // dont ask
	{
		if (ClientPrefs.data.lostFocusDeafen) FlxG.sound.volume = Math.round(_focusVolume);
	}

	private static function volumeOnFocusLost() // dont ask
	{
		if (ClientPrefs.data.lostFocusDeafen)
		{
			_focusVolume = FlxG.sound.volume;
			FlxG.sound.volume *= 0.5;
		}
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
			removeEventListener(Event.ADDED_TO_STAGE, init);

		setupGame();
	}

	private function setupGame():Void
	{
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (game.zoom == -1.0)
		{
			game.zoom = Math.min(stageWidth / game.width, stageHeight / game.height);
			game.width = Math.ceil(stageWidth / game.zoom);
			game.height = Math.ceil(stageHeight / game.zoom);
		}
	
		#if LUA_ALLOWED
		Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call));
		#end

		Controls.instance = new Controls();
		ClientPrefs.loadDefaultKeys();
		addChild(new flixel.FlxGame(game.width, game.height, game.initialState, #if (flixel < "5.0.0") game.zoom, #end
			game.framerate, game.framerate, game.skipSplash, game.startFullscreen));

		#if !mobile
		fpsVar = new FPS(10, 3, 0xFFFFFF);
		fpsShadow = new FPS(11, 4);
		fpsShadow.shadow = true;
		addChild(fpsShadow);
		addChild(fpsVar);

		if(fpsVar != null)
		{
			fpsVar.visible = ClientPrefs.data.showFPS;
			fpsShadow.visible = ClientPrefs.data.showFPS;
		}

		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = openfl.display.StageScaleMode.NO_SCALE;
		#end

		_focusVolume = FlxG.sound.volume;
		#if debug
		FlxG.game.soundTray.volumeUpSound = 'assets/sounds/metal';
		FlxG.game.soundTray.volumeDownSound = 'assets/sounds/lego';
		#else
		FlxG.game.soundTray.volumeUpSound = 'assets/sounds/up_volume';
		FlxG.game.soundTray.volumeDownSound = 'assets/sounds/down_volume';
		#end

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end
		
		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end

		#if desktop
		DiscordClient.start();
		#end

		// shader coords fix
		FlxG.signals.gameResized.add(function (w, h)
		{
			if (FlxG.cameras != null)
				for (cam in FlxG.cameras.list)
					#if (flixel < "5.4.0")
					@:privateAccess
					if (cam != null && cam._filters != null)
					#else
					if (cam != null && cam.filters != null)
					#end
						resetSpriteCache(cam.flashSprite);

			if (FlxG.game != null)
				resetSpriteCache(FlxG.game);
		});
	}

	static function resetSpriteCache(sprite:Sprite):Void
	{
		@:privateAccess
		{
				sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}

	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	// by sqirra-rng
	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		path = "./crash/" + "PsychEngine_" + dateNow + ".txt";

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "
			\nUncaught Error: " + e.error + "\n\ntl;dr" + #if RELESE_BUILD_FR " - i messed up whoops (richTrash21)" #else " - you done goofed (richTrash21)" #end
			/*"\nPlease report this error to the GitHub page: https://github.com/ShadowMario/FNF-PsychEngine\n\n> Crash Handler written by: sqirra-rng"*/;

		if (!FileSystem.exists("./crash/")) FileSystem.createDirectory("./crash/");
		sys.io.File.saveContent(path, errMsg + "\n");

		Sys.println(errMsg);
		Sys.println("Crash dump saved in " + haxe.io.Path.normalize(path));

		Application.current.window.alert(errMsg, "Error!");
		DiscordClient.shutdown();
		Sys.exit(1);
	}
	#end
}
