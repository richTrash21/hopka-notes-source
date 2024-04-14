package options;

import flixel.util.FlxDestroyUtil;
import objects.Note;
import objects.StrumNote;

class VisualsUISubState extends BaseOptionsMenu
{
	var noteOptionID = -1;
	var notes:FlxTypedSpriteGroup<StrumNote>; // for note skins
	var notesY = 90; // note option: 90, other: -200
	var changedMusic = false;

	public function new()
	{
		title = "Visuals and UI";
		rpcTitle = "Visuals & UI Settings Menu"; // for Discord Rich Presence
		var option:Option;

		// options
		final noteSkins = Mods.mergeAllTextsNamed("images/noteSkins/list.txt");
		if (noteSkins.length != 0)
		{
			notes = new FlxTypedSpriteGroup(370, -200);
			for (i in 0...Note.colArray.length)
			{
				final note = new StrumNote(560 / Note.colArray.length * i, 0, i, 0);
				note.centerOffsets();
				note.centerOrigin();
				notes.add(note).playAnim("static");
			}

			if (!noteSkins.contains(ClientPrefs.data.noteSkin))
				ClientPrefs.data.noteSkin = ClientPrefs.defaultData.noteSkin; // Reset to default if saved noteskin couldnt be found

			noteSkins.insert(0, ClientPrefs.defaultData.noteSkin); // Default skin always comes first
			option = new Option("Note Skins:",
				"Select your prefered Note skin.",
				"noteSkin",
				"string",
				noteSkins);
			option.change = () ->
			{
				var skin = Note.defaultNoteSkin;
				final customSkin = skin + Note.getNoteSkinPostfix();
				if (Paths.fileExists('images/$customSkin.png', IMAGE))
					skin = customSkin;

				notes.forEachAlive((note) ->
				{
					note.texture = skin; // Load texture and anims
					note.reloadNote();
					note.playAnim("static");
					note.centerOffsets();
					note.centerOrigin();
				});
			}
			addOption(option);
			noteOptionID = optionsArray.length - 1;
		}
		
		final noteSplashes = Mods.mergeAllTextsNamed("images/noteSplashes/list.txt");
		if (noteSplashes.length != 0)
		{
			if (!noteSplashes.contains(ClientPrefs.data.splashSkin))
				ClientPrefs.data.splashSkin = ClientPrefs.defaultData.splashSkin; //Reset to default if saved splashskin couldnt be found

			noteSplashes.insert(0, ClientPrefs.defaultData.splashSkin); //Default skin always comes first
			addOption(new Option("Note Splashes:",
				"Select your prefered Note Splash variation or turn it off.",
				"splashSkin",
				"string",
				noteSplashes
			));
		}

		option = new Option("Note Splash Opacity",
			"How much transparent should the Note Splashes be.",
			"splashAlpha",
			"percent");
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		option = new Option("Sustain Note Opacity",
			"How much transparent should the Sustain Notes be.",
			"susAlpha", //i want to kms
			"percent");
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);
		
		option = new Option("Health Bar Opacity",
			"How much transparent should the health bar and icons be.",
			"healthBarAlpha",
			"percent");
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		addOption(new Option("Hide HUD",
			"If checked, hides most HUD elements.",
			"hideHud",
			"bool"
		));
		
		addOption(new Option("Time Bar:",
			"What should the Time Bar display?",
			"timeBarType",
			"string",
			["Time Left", "Time Elapsed", "Song Name", "Disabled"]
		));

		addOption(new Option("Flashing Lights",
			"Uncheck this if you're sensitive to flashing lights!",
			"flashing",
			"bool"
		));

		addOption(new Option("Camera Zooms",
			"If unchecked, the camera won't zoom in on a beat hit.",
			"camZooms",
			"bool"
		));

		addOption(new Option("Score Text Zoom on Hit",
			"If unchecked, disables the Score text zooming\neverytime you hit a note.",
			"scoreZoom",
			"bool"
		));
		
		#if !mobile
		option = new Option("FPS Counter",
			"If unchecked, hides FPS Counter." #if !RELESE_BUILD_FR + "\nNOTE: Press F4 to reveal debug info! - rich :3c" #end,
			"showFPS",
			"bool");
		option.change = () -> Main.fpsVar.visible = ClientPrefs.data.showFPS;
		addOption(option);
		#end
		
		option = new Option("Pause Screen Song:",
			"What song do you prefer for the Pause Screen?",
			"pauseMusic",
			"string",
			["None", "Noodles", "Breakfast", "Tea Time"]);
		option.change = () ->
		{
			changedMusic = true;
			if (ClientPrefs.data.pauseMusic == "None")
				FlxG.sound.music.volume = 0;
			else
				FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)));
		};
		addOption(option);

		#if hxdiscord_rpc
		addOption(new Option("Discord Rich Presence",
			"Uncheck this to prevent accidental leaks, it will hide the Application from your \"Playing\" box on Discord.",
			"discordRPC",
			"bool"
		));
		#end

		addOption(new Option("Show Ratings and Combo",
			"If unchecked, Ratings and Combo won't popup. Good for those who don't want anything to obscure their vision.", // or for pussies
			"enableCombo", // sice showCombo was already taken lmao
			"bool"
		));

		addOption(new Option("Combo Stacking",
			"If unchecked, Ratings and Combo won't stack, saving on System Memory and making them easier to read.\nNOTE: Will have no effect if \"Show Ratings and Combo\" is unchecked.",
			"comboStacking",
			"bool"
		));

		super();
		add(notes);
	}

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		notesY = noteOptionID == curSelected ? 90 : -200;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (noteOptionID != -1 && notes.y != notesY)
			notes.y = CoolUtil.lerpElapsed(notes.y, notesY, 0.31, elapsed);
	}

	override function destroy()
	{
		notes = null;
		if (changedMusic && !OptionsState.onPlayState)
			FlxG.sound.playMusic(Paths.music("freakyMenu"), 1, true);
		super.destroy();
	}
}
