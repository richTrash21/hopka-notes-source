package backend;

import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;

// Add a variable here and it will get automatically saved
@:publicFields @:structInit class SaveVariables
{
	@:allow(backend.ClientPrefs)
	private static final __fields = Type.getInstanceFields(SaveVariables);

	var downScroll		= false;
	var middleScroll	= false;
	var opponentStrums	= true;
	var camScript		= true;
	var camScriptNote	= true;
	var showFPS			= true;
	var flashing		= true;
	var autoPause		= true;
	var lostFocusDeafen	= false;
	var antialiasing	= true;
	var noteSkin		= "Default";
	var splashSkin		= "Default";
	var splashAlpha		= 0.6;
	var susAlpha		= 0.6;
	var lowQuality		= false;
	var shaders			= true;
	var cacheOnGPU		= #if switch true #else false #end; // From Stilic
	var framerate		= 60;
	var fixedTimestep	= false;
	var camZooms		= true;
	var hideHud			= false;
	var noteOffset		= 0;

	var ghostTapping	= true;
	var timeBarType		= "Time Left";
	var scoreZoom		= true;
	var noReset			= false;
	var healthBarAlpha	= 1.0;
	var hitsoundVolume	= 0.0;
	var pauseMusic		= "Noodles";
	var checkForUpdates	= true;
	var enableCombo		= true;
	var comboStacking	= true;

	var comboOffset		= [0, 0, 0, 0];
	var ratingOffset	= 0;
	var sickWindow		= 45;
	var goodWindow		= 90;
	var badWindow		= 135;
	var safeFrames		= 10.0;
	var discordRPC		= true;

	var arrowRGB:Array<Array<FlxColor>> = [
		[0xFFC24B99, 0xFFFFFFFF, 0xFF3C1F56],
		[0xFF00FFFF, 0xFFFFFFFF, 0xFF1542B7],
		[0xFF12FA05, 0xFFFFFFFF, 0xFF0A4447],
		[0xFFF9393F, 0xFFFFFFFF, 0xFF651038]
	];
	var arrowRGBPixel:Array<Array<FlxColor>> = [
		[0xFFE276FF, 0xFFFFF9FF, 0xFF60008D],
		[0xFF3DCAFF, 0xFFF4FFFF, 0xFF003060],
		[0xFF71E300, 0xFFF6FFE6, 0xFF003100],
		[0xFFFF884E, 0xFFFFFAF5, 0xFF6C0000]
	];

	var gameplaySettings:Map<String, Dynamic> = [
		"scrollspeed"	=> 1.0,
		"scrolltype"	=> "multiplicative", 
		// anyone reading this, amod is multiplicative speed mod, cmod is constant speed mod, and xmod is bpm based speed mod.
		// an amod example would be chartSpeed * multiplier
		// cmod would just be constantSpeed = chartSpeed
		// and xmod basically works by basing the speed on the bpm.
		// iirc (beatsPerSecond * (conductorToNoteDifference / 1000)) * noteSize (110 or something like that depending on it, prolly just use note.height)
		// bps is calculated by bpm / 60
		// oh yeah and you'd have to actually convert the difference to seconds which I already do, because this is based on beats and stuff. but it should work
		// just fine. but I wont implement it because I don't know how you handle sustains and other stuff like that.
		// oh yeah when you calculate the bps divide it by the songSpeed or rate because it wont scroll correctly when speeds exist.
		// -kade
		"songspeed"		=> 1.0,
		"healthgain"	=> 1.0,
		"healthloss"	=> 1.0,
		"instakill"		=> false,
		"practice"		=> false,
		"botplay"		=> false,
		"showcase"		=> false,
		"opponentplay"	=> false
	];
}

class ClientPrefs
{
	public static var data:SaveVariables = {};
	public static var defaultData:SaveVariables = {};

	inline public static final MIN_FPS = 60;
	inline public static final MAX_FPS = 360;

	// Every key has two binds, add your key bind down here and then add your control on options/ControlsSubState.hx and Controls.hx
	public static var defaultKeys:Map<String, Array<FlxKey>> = [
		"note_up"		=> [W, UP],
		"note_left"		=> [A, LEFT],
		"note_down"		=> [S, DOWN],
		"note_right"	=> [D, RIGHT],
		
		"ui_up"			=> [W, UP],
		"ui_left"		=> [A, LEFT],
		"ui_down"		=> [S, DOWN],
		"ui_right"		=> [D, RIGHT],
		
		"accept"		=> [SPACE, ENTER],
		"back"			=> [BACKSPACE, ESCAPE],
		"pause"			=> [ENTER, ESCAPE],
		"reset"			=> [R],
		
		"volume_mute"	=> [ZERO],
		"volume_up"		=> [NUMPADPLUS, PLUS],
		"volume_down"	=> [NUMPADMINUS, MINUS],
		
		"debug_1"		=> [SEVEN],
		"debug_2"		=> [EIGHT]
	];

	public static var defaultButtons:Map<String, Array<FlxGamepadInputID>> = [
		"note_up"		=> [DPAD_UP, Y],
		"note_left"		=> [DPAD_LEFT, X],
		"note_down"		=> [DPAD_DOWN, A],
		"note_right"	=> [DPAD_RIGHT, B],
		
		"ui_up"			=> [DPAD_UP, LEFT_STICK_DIGITAL_UP],
		"ui_left"		=> [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT],
		"ui_down"		=> [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN],
		"ui_right"		=> [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT],
		
		"accept"		=> [A, START],
		"back"			=> [B],
		"pause"			=> [START],
		"reset"			=> [BACK]
	];

	// Placing this in a separate save so that it can be manually deleted without removing your Score and stuff
	public static final saveControls = new FlxSave();
	public static var keyBinds:Map<String, Array<FlxKey>>;
	public static var gamepadBinds:Map<String, Array<FlxGamepadInputID>>;

	public static function resetKeys(?controller:Bool) // Null = both, False = Keyboard, True = Controller
	{
		if (controller == null || !controller)
			for (key in keyBinds.keys())
				if (defaultKeys.exists(key))
					keyBinds.set(key, defaultKeys.get(key).copy());

		if (controller == null || controller)
			for (button in gamepadBinds.keys())
				if (defaultButtons.exists(button))
					gamepadBinds.set(button, defaultButtons.get(button).copy());
	}

	public static function clearInvalidKeys(key:String)
	{
		var bind:Null<Array<Int>> = keyBinds.get(key);
		while (bind != null && bind.contains(FlxKey.NONE))
			bind.remove(FlxKey.NONE);

		bind = gamepadBinds.get(key);
		while (bind != null && bind.contains(FlxGamepadInputID.NONE))
			bind.remove(FlxGamepadInputID.NONE);
	}

	public static function loadDefaultKeys()
	{
		if (keyBinds == null)
			keyBinds = [for (k => v in defaultKeys) k => v.copy()];
		if (gamepadBinds == null)
			gamepadBinds = [for (k => v in defaultButtons) k => v.copy()];
	}

	public static function saveSettings()
	{
		for (key in SaveVariables.__fields)
			Reflect.setField(FlxG.save.data, key, Reflect.field(data, key));

		#if ACHIEVEMENTS_ALLOWED
		Achievements.save();
		#end
		FlxG.save.flush();

		saveControls.data.keyboard = [for (k => v in keyBinds) k => v.copy()];
		saveControls.data.gamepad = [for (k => v in gamepadBinds) k => v.copy()];
		saveControls.flush();
		FlxG.log.add("Settings saved!");
		// trace("Settings saved!");
	}

	public static function loadPrefs()
	{
		for (key in SaveVariables.__fields)
			if (key != "gameplaySettings" && Reflect.hasField(FlxG.save.data, key))
				Reflect.setField(data, key, Reflect.field(FlxG.save.data, key));

		if (FlxG.save.data.gameplaySettings != null)
		{
			final savedMap:Map<String, Dynamic> = FlxG.save.data.gameplaySettings;
			for (name => value in savedMap)
				data.gameplaySettings.set(name, value);
		}

		#if hxdiscord_rpc
		DiscordClient.check();
		#end

		// controls on a separate save file
		saveControls.bind("controls_v3", CoolUtil.getSavePath());
		if (!saveControls.isEmpty())
		{
			inline function loadKeys<K, V>(saveTo:Map<K, V>, saveFrom:Map<K, V>):Map<K, V>
			{
				if (saveFrom == null)
					return null;

				// if (saveTo == null)
				//	return [for (control => keys in saveFrom) control => keys];

				for (control => keys in saveFrom)
					if (saveTo.exists(control))
						saveTo.set(control, keys);

				return saveTo;
			}

			keyBinds = loadKeys(keyBinds, saveControls.data.keyboard);
			gamepadBinds = loadKeys(gamepadBinds, saveControls.data.gamepad);
		}
		reloadVolumeKeys();
	}

	inline public static function getGameplaySetting(name:String, ?defaultValue:Dynamic, ?customDefaultValue = false):Dynamic
	{
		return (data.gameplaySettings.exists(name) ? data.gameplaySettings.get(name) : (customDefaultValue ? defaultValue : defaultData.gameplaySettings.get(name)));
	}

	public static function reloadVolumeKeys()
	{
		Main.muteKeys		= keyBinds.get("volume_mute").copy();
		Main.volumeDownKeys = keyBinds.get("volume_down").copy();
		Main.volumeUpKeys	= keyBinds.get("volume_up").copy();
		toggleVolumeKeys(true);
	}

	public static function toggleVolumeKeys(turnOn:Bool)
	{
		if (turnOn)
		{
			FlxG.sound.volumeDownKeys = Main.volumeDownKeys;
			FlxG.sound.volumeUpKeys   = Main.volumeUpKeys;
			FlxG.sound.muteKeys       = Main.muteKeys;
		}
		else
		{
			FlxG.sound.volumeDownKeys = null;
			FlxG.sound.volumeUpKeys   = null;
			FlxG.sound.muteKeys       = null;
		}
	}
}
