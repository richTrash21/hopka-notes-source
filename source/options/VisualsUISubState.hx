package options;

import objects.Note;
import objects.StrumNote;

class VisualsUISubState extends BaseOptionsMenu
{
	var noteOptionID:Int = -1;
	var notes:FlxTypedGroup<StrumNote>;
	var notesTween:Array<FlxTween> = [];

	var changedMusic:Bool = false;
	public function new()
	{
		title = 'Visuals and UI';
		rpcTitle = 'Visuals & UI Settings Menu'; //for Discord Rich Presence

		// for note skins
		notes = new FlxTypedGroup<StrumNote>();
		for (i in 0...Note.colArray.length)
		{
			var note:StrumNote = new StrumNote(370 + (560 / Note.colArray.length) * i, -200, i, 0);
			note.centerOffsets();
			note.centerOrigin();
			note.playAnim('static');
			notes.add(note);
		}

		// options

		final noteSkins:Array<String> = Mods.mergeAllTextsNamed('images/noteSkins/list.txt', 'shared');
		if (noteSkins.length > 0)
		{
			if (!noteSkins.contains(ClientPrefs.data.noteSkin))
				ClientPrefs.data.noteSkin = ClientPrefs.defaultData.noteSkin; //Reset to default if saved noteskin couldnt be found

			noteSkins.insert(0, ClientPrefs.defaultData.noteSkin); //Default skin always comes first
			final option:Option = new Option('Note Skins:',
				"Select your prefered Note skin.",
				'noteSkin',
				'string',
				noteSkins);
			option.change = function()
				notes.forEachAlive(function(note:StrumNote) {
					var skin:String = Note.defaultNoteSkin;
					final customSkin:String = skin + Note.getNoteSkinPostfix();
					if (Paths.fileExists('images/$customSkin.png', IMAGE)) skin = customSkin;
			
					note.texture = skin; //Load texture and anims
					note.reloadNote();
					note.playAnim('static');
					note.centerOffsets();
					note.centerOrigin();
				});
			addOption(option);
		
			noteOptionID = optionsArray.length - 1;
		}
		
		final noteSplashes:Array<String> = Mods.mergeAllTextsNamed('images/noteSplashes/list.txt', 'shared');
		if (noteSplashes.length > 0)
		{
			if (!noteSplashes.contains(ClientPrefs.data.splashSkin))
				ClientPrefs.data.splashSkin = ClientPrefs.defaultData.splashSkin; //Reset to default if saved splashskin couldnt be found

			noteSplashes.insert(0, ClientPrefs.defaultData.splashSkin); //Default skin always comes first
			addOption(new Option('Note Splashes:',
				"Select your prefered Note Splash variation or turn it off.",
				'splashSkin',
				'string',
				noteSplashes
			));
		}

		final option:Option = new Option('Note Splash Opacity',
			'How much transparent should the Note Splashes be.',
			'splashAlpha',
			'percent');
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		final option:Option = new Option('Sustain Note Opacity',
			'How much transparent should the Sustain Notes be.',
			'susAlpha', //i want to kms
			'percent');
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);
		
		final option:Option = new Option('Health Bar Opacity',
			'How much transparent should the health bar and icons be.',
			'healthBarAlpha',
			'percent');
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		addOption(new Option('Hide HUD',
			'If checked, hides most HUD elements.',
			'hideHud',
			'bool'
		));
		
		addOption(new Option('Time Bar:',
			"What should the Time Bar display?",
			'timeBarType',
			'string',
			['Time Left', 'Time Elapsed', 'Song Name', 'Disabled']
		));

		addOption(new Option('Flashing Lights',
			"Uncheck this if you're sensitive to flashing lights!",
			'flashing',
			'bool'
		));

		addOption(new Option('Camera Zooms',
			"If unchecked, the camera won't zoom in on a beat hit.",
			'camZooms',
			'bool'
		));

		addOption(new Option('Score Text Zoom on Hit',
			"If unchecked, disables the Score text zooming\neverytime you hit a note.",
			'scoreZoom',
			'bool'
		));
		
		#if !mobile
		final option:Option = new Option('FPS Counter',
			'If unchecked, hides FPS Counter.',
			'showFPS',
			'bool');
		option.change = function() Main.fpsVar.visible = Main.fpsShadow.visible = ClientPrefs.data.showFPS;
		addOption(option);
		#end
		
		final option:Option = new Option('Pause Screen Song:',
			"What song do you prefer for the Pause Screen?",
			'pauseMusic',
			'string',
			['None', 'Noodles', 'Breakfast', 'Tea Time']);
		option.change = function() {
			(ClientPrefs.data.pauseMusic == 'None')
				? FlxG.sound.music.volume = 0
				: FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)));
	
			changedMusic = true;
		};
		addOption(option);
		
		#if CHECK_FOR_UPDATES
		addOption(new Option('Check for Updates',
			'On Release builds, turn this on to check for updates when you start the game.',
			'checkForUpdates',
			'bool'
		));
		#end

		#if desktop
		addOption(new Option('Discord Rich Presence',
			"Uncheck this to prevent accidental leaks, it will hide the Application from your \"Playing\" box on Discord.",
			'discordRPC',
			'bool'
		));
		#end

		addOption(new Option('Show Ratings and Combo',
			"If unchecked, Ratings and Combo won't popup. Good for those who don't want anything to obscure their vision.", // or for pussies
			'enableCombo', // sice showCombo was already taken lmao
			'bool'
		));

		addOption(new Option('Combo Stacking',
			"If unchecked, Ratings and Combo won't stack, saving on System Memory and making them easier to read.\nNOTE: Will have no effect if 'Show Ratings and Combo' is unchecked.",
			'comboStacking',
			'bool'
		));

		super();
		add(notes);
	}

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		
		if (noteOptionID < 0) return;

		for (i in 0...Note.colArray.length)
		{
			final note:StrumNote = notes.members[i];
			if (notesTween[i] != null) notesTween[i].cancel();
			notesTween[i] = FlxTween.tween(note, {y: curSelected == noteOptionID ? 90 : -200}, Math.abs(note.y / 290) / 3, {ease: FlxEase.quadInOut});
		}
	}

	override function destroy()
	{
		if (changedMusic && !OptionsState.onPlayState) FlxG.sound.playMusic(Paths.music('freakyMenu'), 1, true);
		super.destroy();
	}
}
