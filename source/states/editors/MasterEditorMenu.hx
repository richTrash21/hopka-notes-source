package states.editors;

import backend.WeekData;

import objects.Character;

import states.MainMenuState;
import states.FreeplayState;

class MasterEditorMenu extends MusicBeatState
{
	#if !RELESE_BUILD_FR
	var options:Array<String> = [
		'Chart Editor',
		'Character Editor',
		'Week Editor',
		'Menu Character Editor',
		'Dialogue Editor',
		'Dialogue Portrait Editor',
		'Note Splash Debug',
		'Mods Menu' //do not ask
	];
	private var grpTexts:FlxTypedGroup<Alphabet>;
	private var directories:Array<String> = [null];

	private var curSelected:Int = 0;
	private var curDirectory:Int = 0;
	private var directoryTxt:FlxText;

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;
		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Editors Main Menu", null);
		#end

		var bg:FlxSprite = new FlxSprite(0, 0, Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF353535;
		add(bg);

		grpTexts = new FlxTypedGroup<Alphabet>();
		add(grpTexts);

		for (i in 0...options.length)
		{
			var leText:Alphabet = new Alphabet(90, 320, options[i], true);
			leText.isMenuItem = true;
			leText.targetY = i;
			grpTexts.add(leText);
			leText.snapToPosition();
		}
		
		#if MODS_ALLOWED
		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 42).makeGraphic(FlxG.width, 42, 0x99000000);
		add(textBG);

		directoryTxt = new FlxText(textBG.x, textBG.y + 4, FlxG.width, '', 32);
		directoryTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		directoryTxt.scrollFactor.set();
		add(directoryTxt);
		
		for (folder in Mods.getModDirectories()) directories.push(folder);

		var found:Int = directories.indexOf(Mods.currentModDirectory);
		if(found > -1) curDirectory = found;
		changeDirectory();
		#end
		changeSelection();

		//FlxG.mouse.visible = false;
		super.create();
	}

	override function update(elapsed:Float)
	{
		if (controls.UI_UP_P)	changeSelection(-1);
		if (controls.UI_DOWN_P)	changeSelection(1);
		#if MODS_ALLOWED
		if(controls.UI_LEFT_P)	changeDirectory(-1);
		if(controls.UI_RIGHT_P)	changeDirectory(1);
		#end

		if (controls.BACK) MusicBeatState.switchState(new MainMenuState());

		if (controls.ACCEPT)
		{
			switch(options[curSelected]) {
				case 'Chart Editor'://felt it would be cool maybe
					LoadingState.loadAndSwitchState(new ChartingState(), false);
				case 'Character Editor':
					LoadingState.loadAndSwitchState(new CharacterEditorState(Character.DEFAULT_CHARACTER, false));
				case 'Week Editor':
					MusicBeatState.switchState(new WeekEditorState());
				case 'Menu Character Editor':
					MusicBeatState.switchState(new MenuCharacterEditorState());
				case 'Dialogue Editor':
					LoadingState.loadAndSwitchState(new DialogueEditorState(), false);
				case 'Dialogue Portrait Editor':
					LoadingState.loadAndSwitchState(new DialogueCharacterEditorState(), false);
				case 'Note Splash Debug':
					LoadingState.loadAndSwitchState(new NoteSplashDebugState());
				case 'Mods Menu':
					MusicBeatState.switchState(new ModsMenuState());
			}
			if(options[curSelected] != 'Mods Menu') FlxG.sound.music.volume = 0;
			#if PRELOAD_ALL
			FreeplayState.stopVocals();
			#end
		}
		super.update(elapsed);
	}

	function changeSelection(change:Int = 0)
	{
		if(change != 0) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected = FlxMath.wrap(curSelected + change, 0, options.length-1);

		var bullShit:Int = 0;
		for (item in grpTexts.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;
			item.alpha = item.targetY == 0 ? 1 : 0.6;
		}
	}

	#if MODS_ALLOWED
	function changeDirectory(change:Int = 0)
	{
		if(change != 0) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curDirectory = FlxMath.wrap(curDirectory + change, 0, directories.length-1);
	
		WeekData.setDirectoryFromWeek();
		if(directories[curDirectory] == null || directories[curDirectory].length < 1)
			directoryTxt.text = '< No Mod Directory Loaded >';
		else
		{
			Mods.currentModDirectory = directories[curDirectory];
			directoryTxt.text = '< Loaded Mod Directory: ${Mods.currentModDirectory} >';
		}
		directoryTxt.text = directoryTxt.text.toUpperCase();
	}
	#end
	#end
}