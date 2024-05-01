package;

import flixel.input.keyboard.FlxKey;
import lime.app.Application;
import openfl.Lib;

import backend.StateTransition;
import backend.Subtitles;
import debug.DebugOverlay;

// crash handler stuff
#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import sys.FileSystem;
#end

class Main extends flixel.FlxGame
{
	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	// by sqirra-rng
	#if CRASH_HANDLER
	static function onCrash(e:UncaughtErrorEvent):Void
	{
		function stackToString(stackItem:StackItem):String
		{
			return switch (stackItem)
			{
				case FilePos(s, file, line, column):
					var str = '$file at ';
					if (s != null)
						str += stackToString(s) + " (";
					str += 'line $line';
					if (s != null)
						str += ")";
					return str;
				case CFunction:			"a C function";
				case Module(m):			'module $m';
				case Method(_, meth):	'method $meth'; // is this breaking bad?
				case LocalFunction(n):	'local function #$n';
				default:				"<unknown>";
			}
		}

		final path = "./crash/CrashLog_" + Date.now().toString().replace(" ", "_").replace(":", "'") + ".txt";
		var errMsg = "";

		for (stackItem in CallStack.exceptionStack(true))
			errMsg += stackToString(stackItem) + "\n";

		final devMsg = #if RELESE_BUILD_FR "i messed up, whoops" #else "you done goofed" #end + " (richTrash21)";
		errMsg += "\nUncaught Error: " + e.error + /*" [Code: " + e.errorID + "]" +*/ '\n\ntl;dr - $devMsg';

		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");
		sys.io.File.saveContent(path, '$errMsg\n\nFull session log:\n' + GameLog.__log);

		final savedIn = "Crash dump saved in " + haxe.io.Path.normalize(path);
		Sys.println(errMsg);
		Sys.println(savedIn);

		Application.current.window.alert('$errMsg\n$savedIn', "Critical Error!");
		#if hxdiscord_rpc
		DiscordClient.shutdown();
		#end
		Sys.exit(1);
	}
	#end

	public static final initialState:flixel.util.typeLimit.NextState = states.TitleState.new;
	public static var transition(default, null):StateTransition;
	public static var fpsVar(default, null):DebugOverlay;

	public static var volumeDownKeys:Array<FlxKey>;
	public static var volumeUpKeys:Array<FlxKey>;
	public static var muteKeys:Array<FlxKey>;

	@:access(flixel.FlxG.cameras)
	@:access(flixel.system.frontEnds.CameraFrontEnd)
	public function new()
	{
		#if FLX_DEBUG
		flixel.system.debug.log.LogStyle.WARNING.errorSound = GameLog.WARN_SOUND;
		flixel.system.debug.log.LogStyle.ERROR.errorSound = GameLog.ERROR_SOUND;
		#end
		// cool ass log by me yeah
		haxe.Log.trace = debug.GameLog.trace;
		@:privateAccess FlxG.log._standardTraceFunction = haxe.Log.trace;

		#if (VIDEOS_ALLOWED && hxvlc)
		hxvlc.util.Handle.initAsync((s) -> s ? GameLog.notice("LibVLC initialized successfully!") : GameLog.error("Error on initializing LibVLC!"));
		#end
		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end

		// destroy original frontend
		FlxG.cameras.list = null;
		FlxG.cameras.defaults = null;
		FlxG.cameras._cameraRect = null;
		FlxG.cameras.cameraAdded.destroy();
		FlxG.cameras.cameraRemoved.destroy();
		FlxG.cameras.cameraResized.destroy();
		FlxG.cameras.cameraAdded = null;
		FlxG.cameras.cameraRemoved = null;
		FlxG.cameras.cameraResized = null;

		// add custom
		FlxG.cameras = new backend.flixel.CustomCameraFrontEnd();

		// sexy subtitle markups
		for (name => color in FlxColor.colorLookup)
		{
			if (color == 0)
				continue;

			name = name.toLowerCase();
			Subtitles._markup.push(new FlxTextFormatMarkerPair(new FlxTextFormat(color), '<$name>'));
			Subtitles._markup.push(new FlxTextFormatMarkerPair(new FlxTextFormat(null, null, null, color), '<border-$name>'));
		}

		for (f in Type.getClassFields(FlxEase))
			if (f.toUpperCase() != f) // a function field name
				psychlua.LuaUtils.__easeMap.set(f.toLowerCase(), Reflect.field(FlxEase, f));

		// shader coords fix
		FlxG.signals.gameResized.add(shaderFix);

		// reset local cache on restart
		FlxG.signals.preGameReset.add(() ->
		{
			Paths.clearStoredMemory();
			Paths.clearUnusedMemory();
		});

		// sync save data on restart
		FlxG.signals.postGameReset.add(() ->
		{
			#if (!html5 && !switch)
			FlxG.autoPause = ClientPrefs.data.autoPause;
			#end
			FlxG.fixedTimestep = ClientPrefs.data.fixedTimestep;
		});

		// propper game initialization
		FlxG.signals.preGameStart.addOnce(() ->
		{	
			FlxG.keys.preventDefaultKeys = [TAB];
			Controls.instance = new Controls();

			#if LUA_ALLOWED
			llua.Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call));
			Mods.pushGlobalMods();
			#end
			Mods.loadTopMod();
			#if ACHIEVEMENTS_ALLOWED
			Achievements.load();
			#end
			backend.Highscore.load();

			if (FlxG.save.data.weekCompleted != null)
				states.StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;

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
			FlxG.console.registerFunction("switchState", (n:String, ?p:Array<Dynamic>) ->
			{
				if (p == null)
					p = [];

				final f = Type.resolveClass(n);
				var c = f;
				while (c != null)
				{
					if (flixel.util.FlxStringUtil.sameClassName(c, flixel.FlxState))
					{
						MusicBeatState.switchState(() -> Type.createInstance(f, p));
						FlxG.log.add('Switching state (class: $f | parameters: $p)');
						return;
					}
					c = Type.getSuperClass(c);
				}
				FlxG.log.warn('"$n" is not an FlxState class!');
			});
			#end
			FlxG.signals.preStateCreate.add((state) ->
			{
				LoadingState.preloadState(state);
				#if MODS_ALLOWED
				Mods.updatedOnState = false;
				#end
			});
			FlxG.plugins.addPlugin(substates.PauseSubState.tweenManager);

			#if !html5
			FlxG.mouse.useSystemCursor = true;
			#end

			#if hxdiscord_rpc
			DiscordClient.prepare();
			#end

			StateTransition.skipNextTransOut = true;
		});

		// bound local save so flixels default save won't initialize
		FlxG.save.bind("funkin", CoolUtil.getSavePath());
		if (FlxG.save.data.debugInfo == null)
			FlxG.save.data.debugInfo = false;

		// goes unused from now on
		if (!FlxG.save.data.opponentStrums)
			FlxG.save.data.opponentStrums = true;
		if (FlxG.save.data.hideHud)
			FlxG.save.data.hideHud = false;
		if (FlxG.save.data.healthBarAlpha != null)
			FlxG.save.data.healthBarAlpha = 1.0;

		var framerate:Int;
		#if (html5 || switch)
		framerate = 60;
		#else
		framerate = (FlxG.save.data.framerate == null) ? Application.current.window.displayMode.refreshRate : FlxG.save.data.framerate;
		framerate = CoolUtil.boundInt(framerate, ClientPrefs.MIN_FPS, ClientPrefs.MAX_FPS);
		#end

		super(Init.new, framerate, framerate, true, FlxG.save.data.fullscreen);
		_customSoundTray = flixel.CustomSoundTray;
		focusLostFramerate = 60;

		ClientPrefs.loadDefaultKeys();
		ClientPrefs.loadPrefs();
	}

	override function create(_)
	{
		if (stage == null)
			return;

		fpsVar = new DebugOverlay();
		fpsVar.visible = ClientPrefs.data.showFPS;
		addChild(transition = new StateTransition());
		super.create(_);
		#if !mobile
		addChild(fpsVar);
		#end

		Paths.dumpExclusions.push(FlxG.bitmap.findKeyForBitmap(FlxG.bitmap.whitePixel.parent.bitmap));
	}

	override function onFocus(_)
	{
		if (!FlxG.autoPause && ClientPrefs.data.lostFocusDeafen && !FlxG.sound.muted)
			FlxG.sound.volume *= 2;

		super.onFocus(_);
	}

	override function onFocusLost(event:openfl.events.Event)
	{
		if (!FlxG.autoPause && ClientPrefs.data.lostFocusDeafen && !FlxG.sound.muted)
			FlxG.sound.volume *= 0.5;

		super.onFocusLost(event);
	}

	@:access(openfl.display.DisplayObject.__cleanup)
	@:noCompletion function shaderFix(_, _):Void
	{
		for (cam in FlxG.cameras.list)
			if (cam != null && cam.filters != null)
				cam.flashSprite.__cleanup();

		this.__cleanup();
	}
}
