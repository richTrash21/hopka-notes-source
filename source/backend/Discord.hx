package backend;

import discord_rpc.DiscordRpc;

class DiscordClient
{
	public static var isInitialized:Bool = false;
	private static var _defaultID:String = "1141827456693711011";
	public static var clientID(default, set):String = _defaultID;

	// I HAVE TO ADD EVERY SINGLE FUCKING ICON INTO THIS BY MYSELF, FUCKING HELL
	static final VALID_ICONS = ["blue", "clickbait", "false", "gothic", "hodgepodge", "lipped-letters", "red-cut"];
	inline static final DEFAULT_ICON = "icon";

	private static var _options:DiscordPresenceOptions = {
		details: "In the Menus",
		state: null,
		largeImageKey: DEFAULT_ICON,
		largeImageText: "HopKa Notes",
		smallImageKey : null,
		startTimestamp : null,
		endTimestamp : null
	};

	public function new()
	{
		trace("Discord Client starting...");
		try // i need to test smth
		{
			DiscordRpc.start({
				clientID: clientID,
				onReady: onReady,
				onError: onError,
				onDisconnected: onDisconnected
			});
			trace("Discord Client started.");

			final localID = clientID;
			while (localID == clientID)
			{
				DiscordRpc.process();
				Sys.sleep(2);
				// trace('Discord Client Update $localID');
			}
		}
		catch(e)
			throw "DISCORD RPC ERROR!! - " + e.message;
		// DiscordRpc.shutdown();
	}

	public static function check()
	{
		if (!ClientPrefs.data.discordRPC)
		{
			if (isInitialized)
				shutdown();
			isInitialized = false;
		}
		else
			start();
	}
	
	public static function start()
	{
		if (!isInitialized && ClientPrefs.data.discordRPC)
		{
			initialize();
			lime.app.Application.current.window.onClose.add(shutdown);
		}
	}

	inline public static function shutdown()
	{
		DiscordRpc.shutdown();
	}

	inline function onReady()
	{
		DiscordRpc.presence(_options);
	}

	private static function set_clientID(newID:String)
	{
		final change = (clientID != newID);
		clientID = newID;
		if (change && isInitialized)
		{
			shutdown();
			isInitialized = false;
			start();
			DiscordRpc.process();
		}
		return newID;
	}

	inline function onError(_code:Int, _message:String)
	{
		trace('Error! $_code : $_message');
	}

	inline function onDisconnected(_code:Int, _message:String)
	{
		trace('Disconnected! $_code : $_message');
	}

	public static function initialize()
	{
		final DiscordDaemon = sys.thread.Thread.create(DiscordClient.new);
		trace("Discord Client initialized");
		isInitialized = true;
	}

	public static function changePresence(details:String, ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float, ?largeImageKey:String)
	{
		final startTimestamp:Null<Float> = hasStartTimestamp ? Date.now().getTime() : null;
		if (endTimestamp > 0)
			endTimestamp = startTimestamp + endTimestamp;

		_options.details		= details;
		_options.state			= state;
		_options.largeImageKey	= VALID_ICONS.contains(largeImageKey) ? largeImageKey : DEFAULT_ICON;
		// _options.largeImageText	= "Engine Version: " + states.MainMenuState.psychEngineVersion;
		_options.smallImageKey	= smallImageKey;

		// Obtained times are in milliseconds so they are divided so Discord can use it
		_options.startTimestamp	= startTimestamp == null ? null : Std.int(startTimestamp * 0.001);
		_options.endTimestamp	= endTimestamp == null ? null : Std.int(endTimestamp * 0.001);
		DiscordRpc.presence(_options);

		// trace('Discord RPC Updated. Arguments: $details, $state, $smallImageKey, $hasStartTimestamp, $endTimestamp');
	}
	
	public static function resetClientID()
	{
		clientID = _defaultID;
	}

	#if MODS_ALLOWED
	public static function loadModRPC()
	{
		final pack:Dynamic = Mods.getPack();
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
}
