package backend;

#if hxdiscord_rpc
import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types;

class DiscordClient
{
	@:noCompletion inline static final _defaultID = "1141827456693711011";
	@:noCompletion static final presence = DiscordRichPresence.create();

	public static var clientID(default, set) = _defaultID;
	public static var isInitialized = false;

	// I HAVE TO ADD EVERY SINGLE FUCKING ICON INTO THIS BY MYSELF, FUCKING HELL
	inline static final DEFAULT_ICON = "icon";
	static final VALID_ICONS = [
		"blue", "clickbait", "false", "gothic", "hodgepodge", "lipped-letters", "red-cut", "poezda", // done
		"streamer-fright", "casement", "real-huggies", "birthday", // placeholders
	];

	public static var state(get, set):String;
	public static var details(get, set):String;
	public static var smallImageKey(get, set):String;
	public static var largeImageKey(get, set):String;
	public static var largeImageText(get, set):String;

	public static var startTimestamp(get, set):Int;
	public static var endTimestamp(get, set):Int;

	public static function check()
	{
		if (ClientPrefs.data.discordRPC)
			initialize();
		else if (isInitialized)
			shutdown();
	}
	
	public static function prepare()
	{
		if (!isInitialized && ClientPrefs.data.discordRPC)
			initialize();

		if (!lime.app.Application.current.window.onClose.has(onCloseWindow))
			lime.app.Application.current.window.onClose.add(onCloseWindow);
	}

	static function onCloseWindow()
	{
		if (isInitialized)
			shutdown();
	}

	public static function shutdown()
	{
		Discord.Shutdown();
		isInitialized = false;
	}
	
	static function onReady(request:cpp.RawConstPointer<DiscordUser>):Void
	{
		// final discriminator = cast (request[0].discriminator, String);
		var str = "Connected to User - " + cast (request[0].username, String); // New Discord IDs/Discriminator system
		// if (discriminator != "0")
		//	str += '#$discriminator'; // Old discriminators

		trace(str);
		changePresence();
	}

	inline static function onError(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		trace('Error [$errorCode]: ' + cast (message, String));
	}

	inline static function onDisconnected(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		trace('Disconnected [$errorCode]: ' + cast (message, String));
	}

	public static function initialize()
	{
		final discordHandlers		 = DiscordEventHandlers.create();
		discordHandlers.ready		 = cpp.Function.fromStaticFunction(onReady);
		discordHandlers.disconnected = cpp.Function.fromStaticFunction(onDisconnected);
		discordHandlers.errored		 = cpp.Function.fromStaticFunction(onError);
		Discord.Initialize(clientID, cpp.RawPointer.addressOf(discordHandlers), 1, null);

		if (!isInitialized)
			trace("Discord Client initialized");

		sys.thread.Thread.create(() ->
		{
			final localID = clientID;
			while (localID == clientID)
			{
				#if DISCORD_DISABLE_IO_THREAD
				Discord.UpdateConnection();
				#end
				Discord.RunCallbacks();

				// Wait a second until the next loop...
				Sys.sleep(1);
			}
		});
		isInitialized = true;
	}

	public static function changePresence(details = "In the Menus", ?state:String, ?smallImageKey:String, hasStartTimestamp = false, ?endTimestamp:Float, ?largeImageKey:String)
	{
		final startTimestamp:Null<Float> = hasStartTimestamp ? Date.now().getTime() : null;
		if (endTimestamp > 0)
			endTimestamp = startTimestamp + endTimestamp;

		presence.state			= state;
		presence.details		= details;
		presence.smallImageKey	= smallImageKey;
		presence.largeImageKey	= VALID_ICONS.contains(largeImageKey) ? largeImageKey : DEFAULT_ICON;
		presence.largeImageText	= null; // "Engine Version: " + states.MainMenuState.psychEngineVersion

		// Obtained times are in milliseconds so they are divided so Discord can use it
		presence.startTimestamp	= startTimestamp == null ? 0 : Std.int(startTimestamp * 0.001);
		presence.endTimestamp	= endTimestamp == null ? 0 : Std.int(endTimestamp * 0.001);
		updatePresence();
		// trace('Discord RPC Updated. Arguments: $details, $state, $smallImageKey, $hasStartTimestamp, $endTimestamp, $largeImageKey');
	}

	inline public static function updatePresence()
	{
		Discord.UpdatePresence(cpp.RawConstPointer.addressOf(presence));
	}
	
	inline public static function resetClientID()
	{
		clientID = _defaultID;
	}

	#if MODS_ALLOWED
	public static function loadModRPC()
	{
		final pack = Mods.getPack();
		if (pack?.discordRPC != null && pack.discordRPC != clientID)
		{
			clientID = pack.discordRPC;
			// trace('Changing clientID! $clientID, $_defaultID');
		}
	}
	#end

	#if LUA_ALLOWED
	public static function implement(funk:psychlua.FunkinLua)
	{
		funk.set("changeDiscordPresence", changePresence);
		funk.set("changeDiscordClientID", (?newID:String) -> clientID = newID ?? _defaultID);
	}
	#end

	@:noCompletion static function set_clientID(newID:String):String
	{
		if (clientID != newID && isInitialized)
		{
			clientID = newID;
			shutdown();
			initialize();
			updatePresence();
		}
		return newID;
	}

	@:noCompletion inline static function get_state():String
	{
		return presence.state;
	}

	@:noCompletion inline static function set_state(value:String):String
	{
		return presence.state = value;
	}

	@:noCompletion inline static function get_details():String
	{
		return presence.details;
	}

	@:noCompletion inline static function set_details(value:String):String
	{
		return presence.details = value;
	}

	@:noCompletion inline static function get_smallImageKey():String
	{
		return presence.smallImageKey;
	}

	@:noCompletion inline static function set_smallImageKey(value:String):String
	{
		return presence.smallImageKey = value;
	}

	@:noCompletion inline static function get_largeImageKey():String
	{
		return presence.largeImageKey;
	}
	
	@:noCompletion inline static function set_largeImageKey(value:String):String
	{
		return presence.largeImageKey = value;
	}

	@:noCompletion inline static function get_largeImageText():String
	{
		return presence.largeImageText;
	}

	@:noCompletion inline static function set_largeImageText(value:String):String
	{
		return presence.largeImageText = value;
	}

	@:noCompletion inline static function get_startTimestamp():Int
	{
		return presence.startTimestamp;
	}

	@:noCompletion inline static function set_startTimestamp(value:Int):Int
	{
		return presence.startTimestamp = value;
	}

	@:noCompletion inline static function get_endTimestamp():Int
	{
		return presence.endTimestamp;
	}

	@:noCompletion inline static function set_endTimestamp(value:Int):Int
	{
		return presence.endTimestamp = value;
	}
}
#end
